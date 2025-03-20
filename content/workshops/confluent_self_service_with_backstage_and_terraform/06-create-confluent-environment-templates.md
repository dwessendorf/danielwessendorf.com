---
title: 6 - Create Confluent Environment Templates
type: docs
prev: 05-creating-a-custom-backstage-action
next: 07-create-confluent-cluster-templates
---

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

