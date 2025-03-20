---
title: 4 - Configuring Org and Catalog Entries
type: docs
prev: 03-configuring-github-authentication
next: 05-creating-a-custom-backstage-action
---

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

