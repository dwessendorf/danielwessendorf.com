---
title: "Step 04: Configuring GitHub authentication and GitHub Actions"
type: docs
sidebar:
  open: true
prev: 03-setting-up-a-github-personal-access-toke
next: 05-creating-initial-backstage-configuration-files
---

Next, let's set up GitHub authentication to provide a secure, identity-based access system and leverage the great integration of Backstage with GitHub like the GitHub Actions plugin.

### 4.1 Create a GitHub OAuth App

1. Go to your GitHub account settings
2. Navigate to "Developer settings" → "OAuth Apps" → "New OAuth App"
3. Fill in the following details:
   - Application name: "Confluent Backstage"
   - Homepage URL: "http://localhost:3000"
   - Authorization callback URL: "http://localhost:7007/api/auth/github/handler/frame"
4. Register the application and note the Client ID and Client Secret

![](/images/blog/github-1.png)

### 4.2 Configure Backstage for GitHub Auth

Update your `app-config.yaml` file to include the GitHub authentication provider and GitHub Actions configuration.
Replace the existing auth section with the following:

```yaml {filename="app-config.yaml"}
# GitHub authentication configuration
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

# GitHub integration for repository operations and GitHub Actions
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

# GitHub Actions configuration
github:
  actions:
    allowedDomains: ['github.com']
```

Create or modify the `.env` file in the root of your project to store the GitHub OAuth credentials:

```
AUTH_GITHUB_CLIENT_ID=your_client_id
AUTH_GITHUB_CLIENT_SECRET=your_client_secret
```

You can also set these as environment variables directly:

```bash
export AUTH_GITHUB_CLIENT_ID=your_client_id
export AUTH_GITHUB_CLIENT_SECRET=your_client_secret
```

### 4.3 Update Your App Configuration

Modify your `packages/app/src/App.tsx` file to add the sign-in page component :

```typescript {filename="packages/app/src/App.tsx", hl_lines=[4,29,30,31,32,33,34, 35,36,37,38] }
// Other imports...
import { catalogEntityCreatePermission } from '@backstage/plugin-catalog-common/alpha';

import { githubAuthApiRef } from '@backstage/core-plugin-api';

const app = createApp({
  apis,
  bindRoutes({ bind }) {
    // Bind routes for Backstage plugins
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
      viewTechDoc: techdocsPlugin.routes.docRoot,
      createFromTemplate: scaffolderPlugin.routes.selectedTemplate,
    });
    bind(apiDocsPlugin.externalRoutes, {
      registerApi: catalogImportPlugin.routes.importPage,
    });
    bind(scaffolderPlugin.externalRoutes, {
      registerComponent: catalogImportPlugin.routes.importPage,
      viewTechDoc: techdocsPlugin.routes.docRoot,
    });
    bind(orgPlugin.externalRoutes, {
      catalogIndex: catalogPlugin.routes.catalogIndex,
    });
  },
  components: {
    // Configure GitHub authentication sign-in page
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
  },
});


```

Modify your `/packages/app/src/components/catalog/EntityPage.tsx` file and add the content elements for the cicd tab. We also add an configuration flag for to enable it in the default entity page:

```typescript {filename="/packages/app/src/components/catalog/EntityPage.tsx", hl_lines=[8,9,10,11,24,25,26,27,73,74,75]}
// Other imports
import {
  EntityKubernetesContent,
  isKubernetesAvailable,
} from '@backstage/plugin-kubernetes';

// Import GitHub Actions components
import { 
  EntityGithubActionsContent,
  isGithubActionsAvailable,
} from '@backstage-community/plugin-github-actions';

const techdocsContent = (
  <EntityTechdocsContent>
    <TechDocsAddons>
      <ReportIssue />
    </TechDocsAddons>
  </EntityTechdocsContent>
);

const cicdContent = (
  // This is an example of how you can implement your company's logic in entity page.
  // You can for example enforce that all components of type 'service' should use GitHubActions
  <EntitySwitch>
    <EntitySwitch.Case if={isGithubActionsAvailable}>
      <EntityGithubActionsContent />
    </EntitySwitch.Case>

    <EntitySwitch.Case>
      <EmptyState
        title="No CI/CD available for this entity"
        missing="info"
        description="You need to add an annotation to your component if you want to enable CI/CD for it. You can read more about annotations in Backstage by clicking the button below."
        action={
          <Button
            variant="contained"
            color="primary"
            href="https://backstage.io/docs/features/software-catalog/well-known-annotations"
          >
            Read more
          </Button>
        }
      />
    </EntitySwitch.Case>
  </EntitySwitch>
);

const entityWarningContent = (
  <>
    <EntitySwitch>

// More Lines ....

    <EntityLayout.Route path="/docs" title="Docs">
      {techdocsContent}
    </EntityLayout.Route>
  </EntityLayout>
);

/**
 * NOTE: This page is designed to work on small screens such as mobile devices.
 * This is based on Material UI Grid. If breakpoints are used, each grid item must set the `xs` prop to a column size or to `true`,
 * since this does not default. If no breakpoints are used, the items will equitably share the available space.
 * https://material-ui.com/components/grid/#basic-grid.
 */

const defaultEntityPage = (
  <EntityLayout>
    <EntityLayout.Route path="/" title="Overview">
      {overviewContent}
    </EntityLayout.Route>

    <EntityLayout.Route path="/ci-cd" title="CI/CD">
      {cicdContent}
    </EntityLayout.Route>

    <EntityLayout.Route path="/docs" title="Docs">
      {techdocsContent}
    </EntityLayout.Route>
  </EntityLayout>
);

const componentPage = (

// More lines following

```


Install the required packages for the frontend:

```bash
yarn --cwd packages/app add @backstage/core-components @backstage-community/plugin-github-actions
```

Update your backend code in `packages/backend/src/index.ts` to include the auth plugin:

```typescript {filename="packages/backend/src/index.ts", hl_lines=[5]}
// auth plugin
backend.add(import('@backstage/plugin-auth-backend'));
// See https://backstage.io/docs/backend-system/building-backends/migrating#the-auth-plugin
//backend.add(import('@backstage/plugin-auth-backend-module-guest-provider'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));
// See https://backstage.io/docs/auth/guest/provider
```

Install the backend plugins:

```bash
# Install auth plugins
yarn --cwd packages/backend add @backstage/plugin-auth-backend @backstage/plugin-auth-backend-module-github-provider
```

Now, when you navigate to the entity page for a repository managed by Backstage, you'll see an "CICD" tab that shows the GitHub Actions workflows for that repository.

{{< callout type="info" >}}
  This integration is particularly valuable for our use case as it allows users to monitor the status of their Terraform deployments directly in Backstage. They can track when an environment or cluster is being provisioned and see any errors that might occur during the process without needing to navigate to GitHub.
{{< /callout >}}