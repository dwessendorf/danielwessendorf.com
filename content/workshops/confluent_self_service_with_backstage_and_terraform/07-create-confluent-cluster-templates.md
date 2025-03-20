---
title: 7 - Create Conflunt Cluster Template
type: docs
prev: 06-create-confluent-environment-templates
next: 08-create-confluent-cluster-templates
---

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

