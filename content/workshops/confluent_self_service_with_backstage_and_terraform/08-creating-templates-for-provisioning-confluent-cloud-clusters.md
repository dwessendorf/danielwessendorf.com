---
title: "Step 08: Creating templates for provisioning Confluent Cloud clusters"
type: docs
sidebar:
  open: true
prev: 07-creating-templates-for-provisioning-confluent-cloud-environments
next: 09-update-app-configuration

---
Next, let's create a similar template for provisioning Confluent Cloud clusters within our environments.

### 7.1 Create the Cluster Template definition file

Create a directory for the cluster template `confluent-self-service-templates/cluster-template/` and a template definition file `template.yaml` within that directory:

```bash
mkdir -p confluent-self-service-templates/cluster-template/
touch confluent-self-service-templates/cluster-template/template.yaml
```

Add following content to the `template.yaml` file:

```yaml {filename="confluent-self-service-templates/cluster-template/template.yaml"}
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
    # Define form fields for cluster configuration
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
          # EntityPicker allows selecting from existing environments in the catalog
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
    # Get Environment Variables securely
    - id: get-environmentvariables
      name: Get Environment Variables
      action: confluent:environmentvariables:get

    # Fetch template content for the new repository
    - id: fetch-template
      name: Fetch Repository
      action: fetch:template
      input:
        url: ./content
        values:
          cluster_name: ${{ parameters.cluster_name }}
          environment_name: ${{ (parameters.environment_name | parseEntityRef).name }}
          cloud_provider: ${{ parameters.cloud_provider }}
          region: ${{ parameters.region }}
          availability: ${{ parameters.availability }}
          githubUsername: ${{ steps['get-environmentvariables'].output.githubUsername }}

    # Create GitHub repository with the template content
    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: "Terraform for Confluent Cloud Cluster"
        repoUrl: "github.com?owner=${{ steps['get-environmentvariables'].output.githubUsername }}&repo=cc-cluster-${{ parameters.cluster_name }}"
        defaultBranch: main
        repoVisibility: public
        requireCodeOwnerReviews: false
        bypassPullRequestAllowances: 
          teams: [guests]
        requiredApprovingReviewCount: 0
        secrets:
          # Pass Confluent credentials to GitHub repository as secrets
          CONFLUENT_CLOUD_API_KEY: ${{ steps['get-environmentvariables'].output.apiKey }}
          CONFLUENT_CLOUD_API_SECRET: ${{ steps['get-environmentvariables'].output.apiSecret }}

    # Register the new repository in Backstage catalog
    - id: register
      name: Register in Backstage
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'
        
  # Define links that will be shown after template execution
  output:
    links:
      - title: Repository
        url: ${{ steps['publish'].output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
```

{{< callout type="info" >}}
The `EntityPicker` field is a backstage standard component that allows to select an entity from the catalog.
It allows the user to select an existing environment from the Backstage catalog.
{{< /callout >}}

### 7.2 Create the Terraform configuration file for the Cluster Template

Create a content directory for the cluster template in `confluent-self-service-templates/cluster-template/content/` and a Terraform configuration file `main.tf`:

```bash
mkdir -p confluent-self-service-templates/cluster-template/content/
touch confluent-self-service-templates/cluster-template/content/main.tf
```

Add following content to the `main.tf` file:

```hcl {filename="confluent-self-service-templates/cluster-template/content/main.tf"}
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 0.2.0"
    }
  }
}

# Confluent provider will use API credentials from environment variables
provider "confluent" {
  # The provider will automatically use CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET
  # environment variables without explicit configuration
}

# Variables passed from the Backstage template
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

# Look up existing environment by name
data "confluent_environment" "this" {
  display_name = var.environment_name
}

# Create Kafka cluster in the existing environment
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

# Define outputs to be used in documentation
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

{{< callout type="info" >}}
Terraform enables us to lookup an environment by name. This is a great way to ensure that the cluster is 
created in the correct environment and mitigates the fact that we only have the name as attribute in the 
backstage catalog. It is also a good for handling drift, if the environment id of the environment changes.
{{< /callout >}}

Create a catalog info file in `confluent-self-service-templates/cluster-template/content/catalog-info.yaml`:

```bash
touch confluent-self-service-templates/cluster-template/content/catalog-info.yaml
```

Add following content to the `catalog-info.yaml` file:

```yaml {filename="confluent-self-service-templates/cluster-template/content/catalog-info.yaml"}
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.cluster_name | dump }}
  links:
    - url: https://confluent.cloud
      title: Confluent Cloud Console
      icon: dashboard
  annotations:
    github.com/project-slug: ${{ values.githubUsername }}/cc-cluster-${{ values.cluster_name }}
    backstage.io/techdocs-ref: dir:.
spec:
  type: confluent-cluster
  owner: group:guests
  lifecycle: experimental
  system: confluent-cloud
  dependsOn: 
    - component:${{ values.environment_name }}
```


{{< callout type="info" >}}
The `dependsOn` annotation is used to build the backstage internal dependency graph.
{{< /callout >}}

### 7.3 Create GitHub Actions Workflow for the Cluster Template


Create a folder for the GitHub Actions workflow `confluent-self-service-templates/cluster-template/content/.github/workflows/`.
Add a workflow configuration file named `terraform-deploy.yml` to that folder:

```bash
mkdir -p confluent-self-service-templates/cluster-template/content/.github/workflows
touch confluent-self-service-templates/cluster-template/content/.github/workflows/terraform-deploy.yml
```

Add following content to the `terraform-deploy.yml` file:

```yaml {filename="confluent-self-service-templates/cluster-template/content/.github/workflows/terraform-deploy.yml"}
name: "Terraform Deploy"

on:
  workflow_dispatch:  # Allow manual triggering
  push:               # Run on each code push

permissions:
  contents: write     # Needed to write documentation back to the repo

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      # The additional raw and endraw escape tags are needed as backstage uses the same replacement mechanism than
      # github actions. We use them as a workaround to avoid the substitution by the backstage
      # templating engine as we want to use the secrets from the repository in the github actions workflow.
      CONFLUENT_CLOUD_API_KEY: {% raw %}${{ secrets.CONFLUENT_CLOUD_API_KEY }}{% endraw %}
      CONFLUENT_CLOUD_API_SECRET: {% raw %}${{ secrets.CONFLUENT_CLOUD_API_SECRET }}{% endraw %}
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.0.0

      # Initialize Terraform with required providers
      - name: Initialize Terraform
        working-directory: .
        run: terraform init

      # Validate Terraform configuration
      - name: Validate Terraform
        working-directory: .
        run: terraform validate

      # Create execution plan
      - name: Plan Terraform
        working-directory: .
        run: terraform plan -out=tfplan

      # Apply the Terraform plan to create resources
      - name: Apply Terraform
        working-directory: .
        run: terraform apply -auto-approve tfplan
        
      # Extract outputs and create documentation
      - name: Extract Terraform Outputs and Create Documentation
        run: |
          # Use the correct terraform binary path
          TERRAFORM_BIN="${TERRAFORM_CLI_PATH}/terraform-bin"
          
          # Properly capture terraform outputs
          CLUSTER_ID=$(${TERRAFORM_BIN} output -raw cluster_id)
          CLUSTER_NAME=$(${TERRAFORM_BIN} output -raw cluster_name)
          BOOTSTRAP_ENDPOINT=$(${TERRAFORM_BIN} output -raw bootstrap_endpoint)
          ENV_ID=$(${TERRAFORM_BIN} output -raw environment_id)
          ENV_NAME=$(${TERRAFORM_BIN} output -raw environment_name)
          
          echo "Cluster ID: $CLUSTER_ID"
          echo "Cluster Name: $CLUSTER_NAME"
          echo "Environment ID: $ENV_ID"
          echo "Environment Name: $ENV_NAME"
          
          # Create the files with the correct content
          mkdir -p docs
          
          cat > docs/cluster-details.md << EOL
          # Cluster Details
          
          ## Cluster Information
          
          - **Name**: ${CLUSTER_NAME}
          - **Cluster ID**: ${CLUSTER_ID}
          - **Bootstrap Endpoint**: ${BOOTSTRAP_ENDPOINT}
          - **Parent Environment**: ${ENV_NAME}
          - **Environment ID**: ${ENV_ID}
          
          The Cluster ID and Bootstrap Endpoint were automatically populated after the Terraform deployment completed successfully.
          
          ## Access
          
          Access to this cluster is controlled via Confluent Cloud. Please contact the administrators to request access.
          EOL
          
          cat > docs/operations.md << EOL
          # Operations Guide
          
          ## Accessing the Cluster
          
          To access this cluster in the Confluent Cloud Console:
          
          1. Log in to [Confluent Cloud](https://confluent.cloud/)
          2. Navigate to Environments
          3. Select "${ENV_NAME}" from the list
          4. Click on the cluster "${CLUSTER_NAME}"
          
          ## Using the CLI
          
          You can use the Confluent CLI to interact with this cluster:
          
          \`\`\`bash
          # Set up authentication
          confluent login
          
          # List available environments
          confluent environment list
          
          # Select the environment
          confluent environment use ${ENV_ID}
          
          # List clusters in the environment
          confluent kafka cluster list
          
          # Select this cluster
          confluent kafka cluster use ${CLUSTER_ID}
          \`\`\`
          
          You can use the cluster ID listed above.
          EOL

      # Push changes to the repository
      - name: Push changes
        uses: EndBug/add-and-commit@v9
        with:
          message: 'Add automated changes'
          add: 'docs/.'
          push: true
          default_author: github_actions
```

{{< callout type="info" >}}
The additional raw and endraw escape tags are needed as backstage uses the same replacement mechanism than
github actions. We use them as a workaround to avoid the substitution by the backstage
{{< /callout >}}

### 7.4 Create Documentation Setup for the Cluster Template

Create a folder for the documentation `confluent-self-service-templates/cluster-template/content/docs/` and a `mkdocs.yml` file:

```bash
mkdir -p confluent-self-service-templates/cluster-template/content/docs
touch confluent-self-service-templates/cluster-template/content/docs/mkdocs.yml
```

Add following content to the `mkdocs.yml` file:

```yaml {filename="confluent-self-service-templates/cluster-template/content/docs/mkdocs.yml"}
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

Create an initial documentation file `index.md` in the docs directory:

```bash
touch confluent-self-service-templates/cluster-template/content/docs/index.md
```

Add following content to the `index.md` file:

```markdown {filename="confluent-self-service-templates/cluster-template/content/docs/index.md"}
# Confluent Cloud Cluster: ${{ values.cluster_name }}

This documentation provides details about the Confluent Cloud cluster and how to manage it.

## Overview

This cluster was provisioned using Terraform and is managed as Infrastructure as Code.

## Quick Links

- [Cluster Details](cluster-details.md)
- [Operations Guide](operations.md) 
```