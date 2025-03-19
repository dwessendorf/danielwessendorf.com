---
title: "Building a Self-Service Confluent Developer Platform with Backstage and Confluent Cloud"
date: 2025-03-16
draft: false
summary: "In this blog post you will learn how to create a Self Service Portal for Confluent Clusters using Backstage and Terraform"
tags: ["SelfService"]
---

## Introduction


In this comprehensive guide, I'll walk you through the process of building a self-service developer platform using Spotify's Backstage as the foundation and Confluent Cloud as a key service offering. This step-by-step tutorial will take you from a basic Backstage installation to a full-featured platform that enables developers to provision their own Confluent Cloud environments and clusters via a streamlined, GitOps-driven workflow.

Following diagram visualizes the flow of the application.

```mermaid
flowchart TD
    User["👩‍💻 Developer"] -->|Uses templates| Backstage["🚪 Backstage"]
    
    Backstage -->|Creates| GitHub["📂 GitHub Repo"]
    GitHub -->|Triggers| Actions["⚙️ GitHub Actions"]
    Actions -->|Runs| Terraform["🏗️ Terraform"]
    Terraform -->|Provisions| Confluent["☁️ Confluent Cloud"]
    
    Confluent -->|Returns API keys| Terraform
    Terraform -->|Stores results| GitHub
    GitHub -->|Registers| Backstage
    Backstage -->|Shows resources| User
    
    classDef blue fill:#2374ab,stroke:#2374ab,color:white
    classDef green fill:#99c24d,stroke:#99c24d,color:white
    
    class Backstage,GitHub,Actions,Terraform,Confluent blue
    class User green
```


## What We'll Cover

1. Setting up a new Backstage project
2. Configuring GitHub authentication
3. Setting up the organizational structure
4. Creating a software catalog
5. Building a custom plugin for Confluent Cloud integration
6. Creating templates for Confluent Cloud provisioning
7. Implementing Infrastructure as Code with Terraform
8. Automating deployment with GitHub Actions

## Prerequisites

- Node.js 16 or later
- Yarn
- Docker (for TechDocs)
- Git
- A GitHub account
- A Confluent Cloud account with API keys

## Step 1: Setting Up a New Backstage Project

Let's start by creating a new Backstage project:

```bash
# Install the Backstage CLI
npm install -g @backstage/cli

# Create a new Backstage app
npx @backstage/create-app

# Follow the prompts to set up your app
# For this tutorial, we'll name it "confluent-backstage"
```

After the installation completes, navigate to your new project:

```bash
cd confluent-backstage
```

Start the app in development mode to make sure everything is working:

```bash
yarn dev
```

This will launch your Backstage app at http://localhost:3000. You should see the default Backstage welcome page.

## Step 2: Configuring GitHub Authentication

Next, let's set up GitHub authentication to provide a secure, identity-based access system.

### 2.1 Create a GitHub OAuth App

1. Go to your GitHub account settings
2. Navigate to "Developer settings" → "OAuth Apps" → "New OAuth App"
3. Fill in the following details:
   - Application name: "Confluent Backstage"
   - Homepage URL: "http://localhost:3000"
   - Authorization callback URL: "http://localhost:7007/api/auth/github/handler/frame"
4. Register the application and note the Client ID and Client Secret

### 2.2 Configure Backstage for GitHub Auth

Update your `app-config.yaml` file to include the GitHub authentication provider:

```yaml
auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

Create a `.env` file in the root of your project to store the GitHub OAuth credentials:

```
AUTH_GITHUB_CLIENT_ID=your_client_id
AUTH_GITHUB_CLIENT_SECRET=your_client_secret
```

### 2.3 Update Your App Configuration

Modify your `packages/app/src/App.tsx` file to add the sign-in page component:

```typescript
import { githubAuthApiRef } from '@backstage/core-plugin-api';
import { SignInPage } from '@backstage/core-components';

// In the App component:
components: {
  SignInPage: props => (
    <SignInPage
      {...props}
      auto
      provider={{
        id: 'github-auth-provider',
        title: 'GitHub',
        message: 'Sign in using GitHub',
        apiRef: githubAuthApiRef,
      }}
    />
  ),
}
```

Install the required packages:

```bash
yarn add --cwd packages/app @backstage/core-components
```

Update your backend code in `packages/backend/src/index.ts` to include the auth plugin:

```typescript
// auth plugin
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));
```

Install the backend auth plugins:

```bash
yarn add --cwd packages/backend @backstage/plugin-auth-backend @backstage/plugin-auth-backend-module-github-provider
```

## Step 3: Setting Up the Organizational Structure

Now, let's define our organization's structure. Create a directory for our templates and organization data:

```bash
mkdir -p confluent-self-service-templates
```

Create an `org.yaml` file in this directory:

```yaml
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: user1
  annotations:
    github.com/login: YOUR_GITHUB_USERNAME
spec:
  profile:
    displayName: "Your Name"
    email: "your.email@example.com"
  memberOf: [guests]

---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: guests
spec:
  type: team
  children: []
```

Make sure to replace `YOUR_GITHUB_USERNAME`, `Your Name`, and `your.email@example.com` with your actual GitHub username and contact details.

## Step 4: Creating a Software Catalog

Create an `entities.yaml` file in the `confluent-self-service-templates` directory:

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: confluent-cloud
spec:
  owner: guests
```

Update the `app-config.yaml` file to include the catalog locations:

```yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location]
  locations:
    # Local organizational data
    - type: file
      target: ../../confluent-self-service-templates/org.yaml
      rules:
        - allow: [User, Group]
        
    # Local entities
    - type: file
      target: ../../confluent-self-service-templates/entities.yaml
```

## Step 5: Building a Custom Plugin for Confluent Cloud Integration

Now, let's create a custom action that will retrieve Confluent Cloud credentials from environment variables.

### 5.1 Create the Custom Action

Create a new directory for our custom scaffolder actions:

```bash
mkdir -p packages/backend/src/plugins/scaffolder/actions
```

Create a new file `packages/backend/src/plugins/scaffolder/actions/getConfluentCredentials.ts`:

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-backend';

export const createGetConfluentCredentialsAction = () => {
  return createTemplateAction({
    id: 'confluent:credentials:get',
    description: 'Retrieves Confluent API credentials from environment variables',
    
    schema: {
      input: {
        type: 'object',
        properties: {},
        required: [],
      },
      output: {
        type: 'object',
        properties: {
          apiKey: {
            type: 'string',
            title: 'Confluent API Key',
            description: 'The Confluent API Key retrieved from environment variables',
          },
          apiSecret: {
            type: 'string',
            title: 'Confluent API Secret',
            description: 'The Confluent API Secret retrieved from environment variables',
          },
        },
      },
    },
    
    async handler(ctx) {
      const apiKey = process.env.CONFLUENT_CLOUD_API_KEY;
      const apiSecret = process.env.CONFLUENT_CLOUD_API_SECRET;
      
      if (!apiKey || !apiSecret) {
        throw new Error(
          'Confluent API credentials not found in environment variables. ' +
          'Please set CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET.'
        );
      }
      
      ctx.logger.info('Successfully retrieved Confluent API credentials from environment variables');
      
      ctx.output('apiKey', apiKey);
      ctx.output('apiSecret', apiSecret);
    },
  });
};
```

Create an `index.ts` file in the same directory to export the action:

```typescript
export { createGetConfluentCredentialsAction } from './getConfluentCredentials';
```

### 5.2 Register the Custom Action

Modify the `packages/backend/src/plugins/scaffolder.ts` file to include our custom action:

```typescript
import { CatalogClient } from '@backstage/catalog-client';
import { createRouter } from '@backstage/plugin-scaffolder-backend';
import { Router } from 'express';
import type { PluginEnvironment } from '../types';
import { ScmIntegrations } from '@backstage/integration';
import { createBuiltinActions } from '@backstage/plugin-scaffolder-backend';
import { createGetConfluentCredentialsAction } from './scaffolder/actions';

export default async function createPlugin(
  env: PluginEnvironment,
): Promise<Router> {
  const catalogClient = new CatalogClient({
    discoveryApi: env.discovery,
  });

  const integrations = ScmIntegrations.fromConfig(env.config);

  const builtInActions = createBuiltinActions({
    catalogClient,
    integrations,
    config: env.config,
    reader: env.reader,
  });

  const actions = [
    ...builtInActions,
    createGetConfluentCredentialsAction(),
  ];

  return await createRouter({
    actions,
    catalogClient,
    logger: env.logger,
    config: env.config,
    database: env.database,
    reader: env.reader,
  });
}
```

### 5.3 Add Confluent Cloud Configuration

Update your `app-config.yaml` to include Confluent Cloud API credentials:

```yaml
# Add Confluent Cloud integration configuration
confluent:
  apiKey: ${CONFLUENT_CLOUD_API_KEY}
  apiSecret: ${CONFLUENT_CLOUD_API_SECRET}
```

Update your `.env` file to include the Confluent Cloud API credentials:

```
CONFLUENT_CLOUD_API_KEY=your_confluent_api_key
CONFLUENT_CLOUD_API_SECRET=your_confluent_api_secret
```

## Step 6: Creating Templates for Confluent Cloud Provisioning

Now, let's create templates for provisioning Confluent Cloud resources. We'll start with an environment template.

### 6.1 Create the Environment Template

Create a directory for the environment template:

```bash
mkdir -p confluent-self-service-templates/environment-template/content
mkdir -p confluent-self-service-templates/environment-template/content/.github/workflows
mkdir -p confluent-self-service-templates/environment-template/content/docs
```

Create a template definition in `confluent-self-service-templates/environment-template/template.yaml`:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: confluent-cloud-environment  
  title: Deploy Confluent Cloud Environment
  description: A Backstage template to create a Confluent Cloud environment using Terraform.
spec:
  owner: group:guests
  type: service

  parameters:
    - title: Confluent Cloud Configuration
      required:
        - environment_name
      properties:
        environment_name:
          title: Environment Name
          type: string
          description: Name of the Confluent Cloud environment.
  steps:
    # Get Confluent credentials from environment variables
    - id: get-credentials
      name: Get Confluent Credentials
      action: confluent:credentials:get

    - id: fetch-repository
      name: Fetch Repository
      action: fetch:template
      input:
        url: ./content
        copyWithoutTemplating:
          - terraform-deploy.yml
        values:
          environment_name: ${{ parameters.environment_name }}

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: "Terraform for Confluent Cloud Environment"
        repoUrl: "github.com?owner=YOUR_GITHUB_USERNAME&repo=cc-env-${{ parameters.environment_name }}"
        defaultBranch: main
        repoVisibility: public
        requireCodeOwnerReviews: false
        bypassPullRequestAllowances: 
          teams: [guests]
        requiredApprovingReviewCount: 0
        secrets:
          # Use the credentials from our custom action
          CONFLUENT_CLOUD_API_KEY: ${{ steps['get-credentials'].output.apiKey }}
          CONFLUENT_CLOUD_API_SECRET: ${{ steps['get-credentials'].output.apiSecret }}

    - id: register
      name: Register in Backstage
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'
        
  output:
    links:
      - title: Repository
        url: ${{ steps['publish'].output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 6.2 Create the Environment Template Content

Create a Terraform configuration in `confluent-self-service-templates/environment-template/content/main.tf`:

```hcl
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 0.2.0"
    }
  }
}

provider "confluent" {
  # The provider will automatically use CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET
  # environment variables without explicit configuration
}

variable "environment_name" {
  type    = string
  default = "${{ values.environment_name }}"
}

resource "confluent_environment" "this" {
  display_name = var.environment_name
}

# Add outputs to be used in documentation
output "environment_id" {
  value = confluent_environment.this.id
  description = "The ID of the created Confluent Cloud environment"
}

output "environment_name" {
  value = confluent_environment.this.display_name
  description = "The name of the created Confluent Cloud environment"
}
```

Create a catalog info file in `confluent-self-service-templates/environment-template/content/catalog-info.yaml`:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.environment_name | dump }}
  links:
    - url: https://confluent.cloud
      title: Confluent Cloud Console
      icon: dashboard
  annotations:
    github.com/project-slug: YOUR_GITHUB_USERNAME/cc-env-${{ values.environment_name }}
    backstage.io/techdocs-ref: dir:.
spec:
  type: confluent-environment
  owner: group:guests
  lifecycle: experimental
  system: confluent-cloud
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 6.3 Create GitHub Actions Workflow

Create a GitHub Actions workflow in `confluent-self-service-templates/environment-template/content/.github/workflows/terraform-deploy.yml`:

```yaml
name: "Terraform Deploy"

on:
  workflow_dispatch:
  push:

permissions:
  contents: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      CONFLUENT_CLOUD_API_KEY: ${{ secrets.CONFLUENT_CLOUD_API_KEY }}
      CONFLUENT_CLOUD_API_SECRET: ${{ secrets.CONFLUENT_CLOUD_API_SECRET }}
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.0.0

      - name: Initialize Terraform
        working-directory: .
        run: terraform init

      - name: Validate Terraform
        working-directory: .
        run: terraform validate

      - name: Plan Terraform
        working-directory: .
        run: terraform plan -out=tfplan

      - name: Apply Terraform
        working-directory: .
        run: terraform apply -auto-approve tfplan
        
      - name: Extract Terraform Outputs and Create Documentation
        run: |
          # Properly capture terraform outputs
          ENV_ID=$(terraform output -raw environment_id)
          ENV_NAME=$(terraform output -raw environment_name)
          
          # Create documentation files
          mkdir -p docs
          
          cat > docs/environment-details.md << EOL
          # Environment Details
          
          ## Environment Information
          
          - **Name**: ${ENV_NAME}
          - **Environment ID**: ${ENV_ID}
          EOL
          
          # Commit and push documentation
          git config --global user.name "GitHub Actions"
          git config --global user.email "actions@github.com"
          git add docs/
          git commit -m "Update environment documentation [skip ci]"
          git push
```

### 6.4 Create Documentation Setup

Create a `mkdocs.yml` file in `confluent-self-service-templates/environment-template/content/`:

```yaml
site_name: 'Confluent Cloud Environment'
site_description: 'Documentation for Confluent Cloud Environment'

nav:
  - Home: index.md
  - Environment Details: environment-details.md

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - pymdownx.highlight
  - pymdownx.superfences
```

Create an initial documentation file in `confluent-self-service-templates/environment-template/content/docs/index.md`:

```markdown
# Confluent Cloud Environment

This is the documentation for your Confluent Cloud environment.

## Overview

This environment was created using Backstage and Terraform. The environment is managed through Infrastructure as Code, ensuring consistency and repeatability.

## Details

See the [Environment Details](./environment-details.md) page for specific information about this environment.
```

## Step 7: Creating a Cluster Template

Next, let's create a template for provisioning Confluent Cloud clusters within our environments.

### 7.1 Create the Cluster Template

Create a directory for the cluster template:

```bash
mkdir -p confluent-self-service-templates/cluster-template/content
mkdir -p confluent-self-service-templates/cluster-template/content/.github/workflows
mkdir -p confluent-self-service-templates/cluster-template/content/docs
```

Create a template definition in `confluent-self-service-templates/cluster-template/template.yaml`:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: confluent-cloud-cluster
  title: Deploy Confluent Cloud Cluster
  description: A Backstage template to create a Confluent Cloud cluster using Terraform.
spec:
  owner: group:guests
  type: service

  parameters:
    - title: Confluent Cloud Configuration
      required:
        - cluster_name
        - environment_name
      properties:
        cluster_name:
          title: Cluster Name
          type: string
          description: Name of the Confluent Cloud cluster.
        environment_name:
          title: Environment Name
          type: string
          description: Select the environment where this cluster should be deployed.
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Component
              spec.type: confluent-environment
            defaultKind: Component
            showCatalogInfo: true
        cloud_provider:
          title: Cloud Provider
          type: string
          description: Cloud provider for the cluster (e.g., aws, gcp, azure).
          default: GCP
        region:
          title: Region
          type: string
          description: Region where the cluster will be deployed.
          default: europe-west3
        availability:
          title: Availability
          type: string
          description: Availability type (single-zone or multi-zone).
          default: SINGLE_ZONE

  steps:
    - id: get-credentials
      name: Get Confluent Credentials
      action: confluent:credentials:get
            
    - id: parse-environment-name
      name: Parse Environment Name
      action: debug:log
      input:
        message: "Parsing environment reference: ${{ parameters.environment_name }}"
        
    - id: extract-environment-name
      name: Extract Environment Name
      action: debug:log
      input:
        message: |
          ${{ (parameters.environment_name | parseEntityRef).name }}

    - id: fetch-template
      name: Fetch Repository
      action: fetch:template
      input:
        url: ./content
        copyWithoutTemplating:
          - terraform-deploy.yml
        values:
          cluster_name: ${{ parameters.cluster_name }}
          environment_name: ${{ (parameters.environment_name | parseEntityRef).name }}
          cloud_provider: ${{ parameters.cloud_provider }}
          region: ${{ parameters.region }}
          availability: ${{ parameters.availability }}

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: "Terraform for Confluent Cloud Cluster"
        repoUrl: "github.com?owner=YOUR_GITHUB_USERNAME&repo=cc-cluster-${{ parameters.cluster_name }}"
        defaultBranch: main
        repoVisibility: public
        requireCodeOwnerReviews: false
        bypassPullRequestAllowances: 
          teams: [guests]
        requiredApprovingReviewCount: 0
        secrets:
          CONFLUENT_CLOUD_API_KEY: ${{ steps['get-credentials'].output.apiKey }}
          CONFLUENT_CLOUD_API_SECRET: ${{ steps['get-credentials'].output.apiSecret }}

    - id: register
      name: Register in Backstage
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'
        
  output:
    links:
      - title: Repository
        url: ${{ steps['publish'].output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 7.2 Create the Cluster Template Content

Create a Terraform configuration in `confluent-self-service-templates/cluster-template/content/main.tf`:

```hcl
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 0.2.0"
    }
  }
}

provider "confluent" {
  # The provider will automatically use CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET
  # environment variables without explicit configuration
}

variable "cluster_name" {
  type    = string
  default = "${{ values.cluster_name }}"
}

variable "environment_name" {
  type    = string
  default = "${{ values.environment_name }}"
}

variable "cloud_provider" {
  type    = string
  default = "${{ values.cloud_provider }}"
}

variable "region" {
  type    = string
  default = "${{ values.region }}"
}

variable "availability" {
  type    = string
  default = "${{ values.availability }}"
}

# Get the environment ID from the environment name
data "confluent_environment" "this" {
  display_name = var.environment_name
}

resource "confluent_kafka_cluster" "this" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud_provider
  region       = var.region
  basic  {}

  environment {
    id = data.confluent_environment.this.id
  }
}

# Add outputs to be used in documentation
output "cluster_id" {
  value = confluent_kafka_cluster.this.id
  description = "The ID of the created Confluent Cloud cluster"
}

output "cluster_name" {
  value = confluent_kafka_cluster.this.display_name
  description = "The name of the created Confluent Cloud cluster"
}

output "bootstrap_endpoint" {
  value = confluent_kafka_cluster.this.bootstrap_endpoint
  description = "The bootstrap endpoint for the cluster"
  sensitive = true
}

output "environment_id" {
  value = data.confluent_environment.this.id
  description = "The ID of the parent environment"
}

output "environment_name" {
  value = data.confluent_environment.this.display_name
  description = "The name of the parent environment"
}
```

Create a catalog info file in `confluent-self-service-templates/cluster-template/content/catalog-info.yaml`:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.cluster_name | dump }}
  links:
    - url: https://confluent.cloud
      title: Confluent Cloud Console
      icon: dashboard
  annotations:
    github.com/project-slug: YOUR_GITHUB_USERNAME/cc-cluster-${{ values.cluster_name }}
    backstage.io/techdocs-ref: dir:.
spec:
  type: confluent-cluster
  owner: group:guests
  lifecycle: experimental
  system: confluent-cloud
  dependsOn: 
    - component:${{ values.environment_name }}
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 7.3 Create GitHub Actions Workflow for Clusters

Create a GitHub Actions workflow in `confluent-self-service-templates/cluster-template/content/.github/workflows/terraform-deploy.yml`, similar to the environment workflow but with adjusted documentation output:

```yaml
name: "Terraform Deploy"

on:
  workflow_dispatch:
  push:

permissions:
  contents: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      CONFLUENT_CLOUD_API_KEY: ${{ secrets.CONFLUENT_CLOUD_API_KEY }}
      CONFLUENT_CLOUD_API_SECRET: ${{ secrets.CONFLUENT_CLOUD_API_SECRET }}
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.0.0

      - name: Initialize Terraform
        working-directory: .
        run: terraform init

      - name: Validate Terraform
        working-directory: .
        run: terraform validate

      - name: Plan Terraform
        working-directory: .
        run: terraform plan -out=tfplan

      - name: Apply Terraform
        working-directory: .
        run: terraform apply -auto-approve tfplan
        
      - name: Extract Terraform Outputs and Create Documentation
        run: |
          # Properly capture terraform outputs
          CLUSTER_ID=$(terraform output -raw cluster_id)
          CLUSTER_NAME=$(terraform output -raw cluster_name)
          ENV_ID=$(terraform output -raw environment_id)
          ENV_NAME=$(terraform output -raw environment_name)
          
          # Create documentation files
          mkdir -p docs
          
          cat > docs/cluster-details.md << EOL
          # Cluster Details
          
          ## Cluster Information
          
          - **Name**: ${CLUSTER_NAME}
          - **Cluster ID**: ${CLUSTER_ID}
          - **Environment**: ${ENV_NAME}
          - **Environment ID**: ${ENV_ID}
          EOL
          
          # Commit and push documentation
          git config --global user.name "GitHub Actions"
          git config --global user.email "actions@github.com"
          git add docs/
          git commit -m "Update cluster documentation [skip ci]"
          git push
```

### 7.4 Create Documentation Setup for Clusters

Create a `mkdocs.yml` file in `confluent-self-service-templates/cluster-template/content/`:

```yaml
site_name: 'Confluent Cloud Cluster'
site_description: 'Documentation for Confluent Cloud Cluster'

nav:
  - Home: index.md
  - Cluster Details: cluster-details.md

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - pymdownx.highlight
  - pymdownx.superfences
```

Create an initial documentation file in `confluent-self-service-templates/cluster-template/content/docs/index.md`:

```markdown
# Confluent Cloud Cluster

This is the documentation for your Confluent Cloud cluster.

## Overview

This cluster was created using Backstage and Terraform. The cluster is managed through Infrastructure as Code, ensuring consistency and repeatability.

## Details

See the [Cluster Details](./cluster-details.md) page for specific information about this cluster.
```

## Step 8: Update App Configuration

Finally, update the `app-config.yaml` file to include our templates:

```yaml
catalog:
  # ... existing config ...
  locations:
    # ... existing locations ...
    
    # Local example template
    - type: file
      target: ../../confluent-self-service-templates/environment-template/template.yaml
      rules:
        - allow: [Template]

    # Add the new cluster template
    - type: file
      target: ../../confluent-self-service-templates/cluster-template/template.yaml
      rules:
        - allow: [Template]
```

## Step 9: Start Your Backstage App

Now we can start the Backstage app with our custom templates:

```bash
yarn dev
```

## The User Journey

Let's walk through the user journey:

1. A developer logs into Backstage using their GitHub credentials
2. They navigate to the "Create" page and select the "Deploy Confluent Cloud Environment" template
3. They fill in the form with their desired environment name
4. The system creates a new GitHub repository with Terraform code
5. GitHub Actions runs the Terraform code to provision the Confluent Cloud environment
6. The new environment is registered in the Backstage catalog
7. The developer can then use the "Deploy Confluent Cloud Cluster" template to create a cluster in the environment
8. They select their environment from the dropdown and configure the cluster
9. A new GitHub repository is created for the cluster
10. GitHub Actions provisions the cluster in Confluent Cloud
11. The cluster is registered in the Backstage catalog with a dependency on the environment

## Conclusion

We've built a powerful self-service platform that enables developers to provision their own Confluent Cloud environments and clusters with just a few clicks. This approach:

- Reduces the operational burden on platform teams
- Ensures consistency through Infrastructure as Code
- Provides a great developer experience
- Maintains visibility and governance through the Backstage catalog

By combining Backstage, GitHub, Terraform, and Confluent Cloud, we've created a solution that demonstrates the power of modern developer platforms.

## Next Steps

Future enhancements could include:
- Adding templates for Kafka topics and schemas
- Implementing access control and permissions
- Adding cost tracking and quota management
- Integrating with monitoring systems for observability

Happy coding!
