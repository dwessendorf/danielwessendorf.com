---
title: 03 - configuring github authentication
type: docs
prev: workshops/01-introduction
---
Configuring GitHub Authentication

Next, let's set up GitHub authentication to provide a secure, identity-based access system.

### 2.1 Create a GitHub OAuth App

1. Go to your GitHub account settings
2. Navigate to "Developer settings" → "OAuth Apps" → "New OAuth App"
3. Fill in the following details:
   - Application name: "Confluent Backstage"
   - Homepage URL: "http://localhost:3000"
   - Authorization callback URL: "http://localhost:7007/api/auth/github/handler/frame"
4. Register the application and note the Client ID and Client Secret

### 2.2 Configure Backstage for GitHub Auth

Update your `app-config.yaml` file to include the GitHub authentication provider:

```yaml
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
```

Create a `.env` file in the root of your project to store the GitHub OAuth credentials:

```
AUTH_GITHUB_CLIENT_ID=your_client_id
AUTH_GITHUB_CLIENT_SECRET=your_client_secret
```

### 2.3 Update Your App Configuration

Modify your `packages/app/src/App.tsx` file to add the sign-in page component:

```typescript
import { githubAuthApiRef } from '@backstage/core-plugin-api';
import { SignInPage } from '@backstage/core-components';

// In the App component:
components: {
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
}
```

Install the required packages:

```bash
yarn add --cwd packages/app @backstage/core-components
```

Update your backend code in `packages/backend/src/index.ts` to include the auth plugin:

```typescript
// auth plugin
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));
```

Install the backend auth plugins:

```bash
yarn add --cwd packages/backend @backstage/plugin-auth-backend @backstage/plugin-auth-backend-module-github-provider
```