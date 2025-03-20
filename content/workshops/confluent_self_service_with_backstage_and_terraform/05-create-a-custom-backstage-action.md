---
title: 5 - Create a custom backstage action
type: docs
prev: 04-configure-org-and-catalog-entries
next: 06-create-confluent-environment-templates
---

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

