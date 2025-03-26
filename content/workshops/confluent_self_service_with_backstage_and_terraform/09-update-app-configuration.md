---
title: "Step 09: Update App Configuration"
type: docs
sidebar:
  open: true
prev: 08-creating-templates-for-provisioning-confluent-cloud-clusters
next: 10-start-your-backstage-app
---

Finally, update the `app-config.yaml` file to include our templates:

```yaml {filename="app-config.yaml"}  
catalog:
  # ... existing config ...
  locations:
    # ... existing locations ...
    
    # Register environment template in the catalog
    - type: file
      target: ../../confluent-self-service-templates/environment-template/template.yaml
      rules:
        - allow: [Template]

    # Register cluster template in the catalog
    - type: file
      target: ../../confluent-self-service-templates/cluster-template/template.yaml
      rules:
        - allow: [Template]
```
