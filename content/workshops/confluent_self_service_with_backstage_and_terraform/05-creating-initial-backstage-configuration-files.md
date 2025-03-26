---
title: "Step 05: Creating initial backstage configuration files"
type: docs
sidebar:
  open: true
prev: 04-configuring-github-authentication
next: 06-building-a-custom-plugin-for-secret-handling
---
### 5.1 Create the organization file and add your user

Now, let's define our organization's structure. Create a directory for our templates and organization data and an `org.yaml` file:

```bash
mkdir -p confluent-self-service-templates
touch confluent-self-service-templates/org.yaml   
```

Create the `org.yaml` file with environment variables using this script:

```bash
cat > confluent-self-service-templates/org.yaml << EOL
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: ${GITHUB_USERNAME}
  annotations:
    github.com/login: ${GITHUB_USERNAME}
spec:
  profile:
    displayName: "${USER_DISPLAY_NAME}"
    email: "${USER_EMAIL}"
  memberOf: [guests]


---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: guests
spec:
  type: team
  children: []
EOL
```

This script will create the `org.yaml` file with the environment variables properly substituted. Make sure you have set the environment variables before running this script:
- `GITHUB_USERNAME`
- `USER_DISPLAY_NAME`
- `USER_EMAIL`

{{< callout type="info" >}}
The script uses a heredoc (`<< EOL`) to create the file, which allows us to use environment variables directly in the content. The variables will be expanded when the script runs.
{{< /callout >}}

### Step 5.2 : Creating first static software catalog entry for Confluent Cloud

Create an `entities.yaml` file in the `confluent-self-service-templates` directory:

```bash
touch confluent-self-service-templates/entities.yaml   
```

Add following content to the `entities.yaml` file:

```yaml {filename="confluent-self-service-templates/entities.yaml"}
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: confluent-cloud
spec:
  owner: guests
```

This entry will be used as the root entity for our Confluent Cloud resources in backstage entities graph.

Update the `app-config.yaml` file to include the catalog locations:

First, remove the default example catalog locations that come with a fresh Backstage installation:

```yaml {filename="app-config.yaml"}
locations:
  # Local example data, file locations are relative to the backend process, typically `packages/backend`
  - type: file
    target: ../../examples/entities.yaml

  # Local example template
  - type: file
    target: ../../examples/template/template.yaml
    rules:
      - allow: [Template]

  # Local example organizational data
  - type: file
    target: ../../examples/org.yaml
    rules:
      - allow: [User, Group]
```

Then, add our custom catalog locations:

```yaml {filename="app-config.yaml"}
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