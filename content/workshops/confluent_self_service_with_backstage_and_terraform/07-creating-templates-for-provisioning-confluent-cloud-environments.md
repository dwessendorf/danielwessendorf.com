---
title: "Step 07: Creating templates for provisioning Confluent Cloud environments"
type: docs
sidebar:
  open: true
prev: 06-building-a-custom-plugin-for-secret-handling
next: 08-creating-templates-for-provisioning-confluent-cloud-clusters
---
Now, let's create templates for provisioning Confluent Cloud resources. We'll start with an environment template. We also use our custom action 
in the template to get the Confluent Cloud credentials and the github username from the environment variables.

### 6.1 Create the Environment Template definition file

Create a directory for the environment template `confluent-self-service-templates/environment-template/` and within that directory create a file called `template.yaml`:

```bash
mkdir -p confluent-self-service-templates/environment-template/
touch confluent-self-service-templates/environment-template/template.yaml
```
Add following content to the `template.yaml` file:

```yaml {filename="confluent-self-service-templates/environment-template/template.yaml"}
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
    # Define form fields that will be shown to users
    - title: Confluent Cloud Configuration
      required:
        - environment_name
      properties:
        environment_name:
          title: Environment Name
          type: string
          description: Name of the Confluent Cloud environment.
  steps:
    # Use our custom action to get environment variables securely
    - id: get-environmentvariables
      name: Get Environment Variables
      action: confluent:environmentvariables:get

    # Fetch template content for the new repository
    - id: fetch-repository
      name: Fetch Repository
      action: fetch:template
      input:
        url: ./content
        copyWithoutTemplating:
          - terraform-deploy.yml
        values:
          environment_name: ${{ parameters.environment_name }}
          githubUsername: ${{ steps['get-environmentvariables'].output.githubUsername }}

    # Create a new GitHub repository with the template content
    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: "Terraform for Confluent Cloud Environment"
        repoUrl: "github.com?owner=${{ steps['get-environmentvariables'].output.githubUsername }}&repo=cc-env-${{ parameters.environment_name }}"
        defaultBranch: main
        repoVisibility: public
        requireCodeOwnerReviews: false
        bypassPullRequestAllowances: 
          teams: [guests]
        requiredApprovingReviewCount: 0
        secrets:
          # Pass Confluent credentials to the GitHub repository as secrets
          CONFLUENT_CLOUD_API_KEY: ${{ steps['get-environmentvariables'].output.apiKey }}
          CONFLUENT_CLOUD_API_SECRET: ${{ steps['get-environmentvariables'].output.apiSecret }}

    # Register the new repository in the Backstage catalog
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



### 6.2 Create the terraform configuration file for the Environment Template

The above template will create a new Github repository and the necessary Infrastructure-as-Code (IaC)-files to provision a Confluent Cloud environment.
The github repository will also contain an github actions workflow to provision the environment and a documentation page that will be created during the github actions workflow run. These files are provided as content templates that will be used to create the actual files in the github repository.

Create a directory for the environment template content under `confluent-self-service-templates/environment-template/content/`.
Within that directory create a Terraform configuration file called `main.tf`:

```bash 
mkdir -p confluent-self-service-templates/environment-template/content
touch confluent-self-service-templates/environment-template/content/main.tf
```

Add following content to the `main.tf` file:

```hcl {filename="confluent-self-service-templates/environment-template/content/main.tf"}
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

# Environment name is passed from the Backstage template
variable "environment_name" {
  type    = string
  default = "${{ values.environment_name }}"
}

# Create the Confluent Cloud environment
resource "confluent_environment" "this" {
  display_name = var.environment_name
}

# Define outputs to be used in documentation
output "environment_id" {
  value = confluent_environment.this.id
  description = "The ID of the created Confluent Cloud environment"
}

output "environment_name" {
  value = confluent_environment.this.display_name
  description = "The name of the created Confluent Cloud environment"
}
```

Create a catalog info file named `catalog-info.yaml` in the content directory :

```bash
touch confluent-self-service-templates/environment-template/content/catalog-info.yaml
```

The catalog info file is used to register the environment in the Backstage catalog. It contains the necessary annotations
and metadata to define the entity in the catalog.

Add following content to the `catalog-info.yaml` file:

```yaml {filename="confluent-self-service-templates/environment-template/content/catalog-info.yaml"}
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.environment_name | dump }}
  links:
    - url: https://confluent.cloud
      title: Confluent Cloud Console
      icon: dashboard
  annotations:
    github.com/project-slug: ${{ values.githubUsername }}/cc-env-${{ values.environment_name }}
    backstage.io/techdocs-ref: dir:.
spec:
  type: confluent-environment
  owner: group:guests
  lifecycle: experimental
  system: confluent-cloud
```



{{< callout type="info" >}}
The `github.com/project-slug` annotation is used to link the environment to the GitHub repository. This also enables backstage
to show the result of the github actions workflow in the CICD-tab of the environment entity.
The `backstage.io/techdocs-ref` annotation is used to specify the directory containing the documentation for the environment.
{{< /callout >}}


### 6.3 Create GitHub Actions Workflow for the Environment Template

Create a folder for the GitHub Actions workflow `confluent-self-service-templates/environment-template/content/.github/workflows/`.
Add a workflow configuration file named `terraform-deploy.yml` to that folder:

```bash
mkdir -p confluent-self-service-templates/environment-template/content/.github/workflows
touch confluent-self-service-templates/environment-template/content/.github/workflows/terraform-deploy.yml
```

Add following content to the `terraform-deploy.yml` file:

```yaml {filename="confluent-self-service-templates/environment-template/content/.github/workflows/terraform-deploy.yml"}
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
          ENV_ID=$(${TERRAFORM_BIN} output -raw environment_id)
          ENV_NAME=$(${TERRAFORM_BIN} output -raw environment_name)
          
          echo "Environment ID: $ENV_ID"
          echo "Environment Name: $ENV_NAME"
          
          # Create the files with the correct content
          mkdir -p docs
          
          cat > docs/environment-details.md << EOL
          # Environment Details
          
          ## Environment Information
          
          - **Name**: ${ENV_NAME}
          - **Environment ID**: ${ENV_ID}
          
          The Environment ID was automatically populated after the Terraform deployment completed successfully.
          
          ## Access
          
          Access to this environment is controlled via Confluent Cloud. Please contact the administrators to request access.
          EOL
          
          cat > docs/operations.md << EOL
          # Operations Guide
          
          ## Accessing the Environment
          
          To access this environment in the Confluent Cloud Console:
          
          1. Log in to [Confluent Cloud](https://confluent.cloud/)
          2. Navigate to Environments
          3. Select "${ENV_NAME}" from the list
          
          ## Using the CLI
          
          You can use the Confluent CLI to interact with this environment:
          
          \`\`\`bash
          # Set up authentication
          confluent login
          
          # List available environments
          confluent environment list
          
          # Select this environment
          confluent environment use ${ENV_ID}
          \`\`\`
          
          You can use the environment ID listed above.
          EOL
        # Push documentation to the repository
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
github actions. We use them as a workaround to avoid the substitution by the backstage templating engine 
as we want to use the secrets from the repository in the github actions workflow.
{{< /callout >}}


### 6.4 Create Documentation Setup for the Environment Template

When the user initiates the github repo, some information like the environment id is not yet present and cannot be registered in the catalog.
To get full transparency, we need to create a documentation page that will be dynamically created in the github actions workflow and stored
in the repository once the environment is created.

We will use the backstage techdocs feature to create this documentation page. 

Create a folder for the documentation under `confluent-self-service-templates/environment-template/content/docs` and a `mkdocs.yml` file in that folder:

```bash
mkdir -p confluent-self-service-templates/environment-template/content/docs
touch confluent-self-service-templates/environment-template/content/docs/mkdocs.yml
```

Add following content to the `mkdocs.yml` file:

```yaml {filename="confluent-self-service-templates/environment-template/content/docs/mkdocs.yml"}
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

Create an initial documentation file in `index.md` in the docs directory:

```bash
touch confluent-self-service-templates/environment-template/content/docs/index.md
```

```markdown {filename="confluent-self-service-templates/environment-template/content/docs/index.md"}
# Confluent Cloud Environment: ${{ values.environment_name }}

This documentation provides details about the Confluent Cloud environment and how to manage it.

## Overview

This environment was provisioned using Terraform and is managed as Infrastructure as Code.

## Quick Links

- [Environment Details](environment-details.md)
- [Operations Guide](operations.md)
```