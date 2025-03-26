---
title: "Step 06: Building a custom plugin for secret handling"
type: docs
sidebar:
  open: true
prev: 05-creating-initial-backstage-configuration-files
next: 07-creating-templates-for-provisioning-confluent-cloud-environments
---
### 5.1 Understanding the Need for a Custom Action

Backstage's scaffolder is designed with security in mind, and for good reason. By default, scaffolder actions cannot access environment variables from the host system - this is a deliberate security measure to prevent templates from accessing sensitive credentials.

However, for our Confluent Cloud integration, we need a way to securely provide API credentials to our templates without hardcoding them. We have two options:

1. **Retrieve the credentials from environment variables** (the approach we'll use) - We create a custom action that will safely retrieve the Confluent Cloud credentials from environment variables on the Backstage server and pass them to the templates.

2. **Use a secret manager** - Alternatively, we could create a similar custom action that integrates with a secret manager like HashiCorp Vault or AWS Secrets Manager. (More suitable for production environments)

For this tutorial, we'll implement the first option. Besides the credentials, we also will retrieve the github username from the environment variables to create the github repository.

### 5.2 Create the Custom Action

The Backstage Scaffolder plugin comes with a set of default actions that can be used to create and manage templates. If you want to extend the default actions, you can create a new action by following these steps:

```bash
# Create a new scaffolder backend module
yarn backstage-cli new
# When prompted, choose scaffolder-backend-module 
# Write getenvironmentvariables as the module id
```

### 5.3 Cleaning Up Example Files

The backstage cli creates a new scaffolder backend module with example files that explain how to create a new action. We can remove them:

```bash
# Remove example template 
rm -rf plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/example.test.ts 
rm -rf plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/example.ts
```

### 5.4 Creating Custom Action Files and register the action

We will create a new action file in the `plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/` directory called `getEnvironmentVariables.ts`.

```bash
# Create new action files
mkdir -p plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/
touch plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/getEnvironmentVariables.ts
```

Add following content to the `getEnvironmentVariables.ts` file:

```typescript {filename="plugins/scaffolder-backend-module-getenvironmentvariables/src/actions/getEnvironmentVariables.ts"}
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

export const createGetEnvironmentVariablesAction = () => {
  return createTemplateAction({
    id: 'confluent:environmentvariables:get',
    description: 'Retrieves Confluent API credentials and github username from environment variables',
    
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
            description: 'The Confluent API Key retrieved from an environment variable',
          },
          apiSecret: {
            type: 'string',
            title: 'Confluent API Secret',
            description: 'The Confluent API Secret retrieved from an environment variable',
          },
          githubUsername: {
            type: 'string',
            title: 'GitHub Username',
            description: 'The GitHub username retrieved from an environment variable',
          },
        },
      },
    },
    
    async handler(ctx) {
      const apiKey = process.env.CONFLUENT_CLOUD_API_KEY;
      const apiSecret = process.env.CONFLUENT_CLOUD_API_SECRET;
      const githubUsername = process.env.GITHUB_USERNAME;
      
      if (!apiKey || !apiSecret) {
        throw new Error(
          'Confluent API credentials not found in environment variables. ' +
          'Please set CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET.'
        );
      }
      
      if (!githubUsername) {
        throw new Error(
          'GitHub username not found in environment variables. ' +
          'Please set GITHUB_USERNAME.'
        );
      }
      
      ctx.logger.info('Successfully retrieved credentials from environment variables');
      
      ctx.output('apiKey', apiKey);
      ctx.output('apiSecret', apiSecret);
      ctx.output('githubUsername', githubUsername);
    },
  });
};
```
Modify the `plugins/scaffolder-backend-module-getenvironmentvariables/src/module.ts` file to use the new action:

Replace the existing code with the following:

```typescript {filename="plugins/scaffolder-backend-module-getenvironmentvariables/src/module.ts"}
import { createBackendModule } from "@backstage/backend-plugin-api";
import { scaffolderActionsExtensionPoint  } from '@backstage/plugin-scaffolder-node/alpha';
import { createGetEnvironmentVariablesAction } from "./actions/getEnvironmentVariables";

/**
 * A backend module that registers the action into the scaffolder
 */
export const scaffolderModule = createBackendModule({
  moduleId: 'environment-variables-action',
  pluginId: 'scaffolder',
  register({ registerInit }) {
    registerInit({
      deps: {
        scaffolderActions: scaffolderActionsExtensionPoint
      },
      async init({ scaffolderActions}) {
        scaffolderActions.addActions(createGetEnvironmentVariablesAction());
      }
    });
  },
})
```


### 5.5 Add Confluent Cloud Credentials

To interact with Confluent Cloud, you'll need to generate API keys through the Confluent Cloud console. Here's how:

1. Log into the [Confluent Cloud Console](https://confluent.cloud/)
2. Click on the hamburger icon in the top-right corner and select  "Cloud API keys" in the "Administration" section
3. Click the "+Add API key" button in the top-right corner
4. Select "My account" for this tutorial and "Next". (In production, you may want to create a service account for your CI/CD pipeline.)
5. Add a Name and Description for the API key and click "Create API key"
6. Save the API key and secret immediately or download the file to store it safely (you won't be able to see the secret again)

![](/images/blog/confluent-api-keys.png)

Once you have your API credentials, update your `.env` file to include them:

```
CONFLUENT_CLOUD_API_KEY=your_confluent_api_key
CONFLUENT_CLOUD_API_SECRET=your_confluent_api_secret
```

Alternatively, you can set these as environment variables directly:

```bash
export CONFLUENT_CLOUD_API_KEY=your_confluent_api_key
export CONFLUENT_CLOUD_API_SECRET=your_confluent_api_secret
```