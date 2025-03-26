---
title: "Step 03: Setting up a GitHub Personal Access Token"
type: docs
sidebar:
  open: true
prev: 02-setting-up-a-new-backstage-project
next: 04-configuring-github-authentication
---

Before we proceed to GitHub authentication, you'll need to create a personal access token that allows Backstage to interact with GitHub's API. This is necessary for repository creation and other GitHub operations.

1. Go to your GitHub account settings
2. Navigate to "Developer settings" → "Personal access tokens" → "Fine-grained tokens" → "Generate new token"
3. Give your token a descriptive name like "Backstage Integration"
4. Set an expiration date (I recommend at least 90 days)
5. For repository access, select "All repositories" or specifically select the repositories you'll be using
6. Under "Repository permissions", grant the following permissions:
   - Administration: Read and write
   - Secrets: Read and write
   - Contents: Read and write
   - Pull requests: Read and write
   - Workflows: Read and write
   - Metadata: Read-only
7. Generate the token and copy it immediately (you won't be able to see it again)

Now, set this token, your github username, display name and your (with github associated) email-address as environment variables:

```bash
export GITHUB_TOKEN="your_personal_access_token"
export GITHUB_USERNAME="your-github-username"
export USER_DISPLAY_NAME="your-display-name"
export USER_EMAIL="your-email-address"
```


If you want to make this persistent, you can also add it to your `.env` file:

```bash
# GitHub configuration
echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> .env
echo "GITHUB_USERNAME=$GITHUB_USERNAME" >> .env
echo "USER_DISPLAY_NAME=$USER_DISPLAY_NAME" >> .env
echo "USER_EMAIL=$USER_EMAIL" >> .env
```
These variables will be used in various configuration files and templates to avoid hardcoding personal information.

Also check the `app-config.yaml` file that backstage is using the github token environment variable for its GitHub integration (Should be there by default):

```yaml {filename="app-config.yaml"}
integrations:
  github:
    - host: github.com
      # This is a Personal Access Token or PAT from GitHub. You can find out how to generate this token, and more information
      # about setting up the GitHub integration here: https://backstage.io/docs/integrations/github/locations#configuration
      token: ${GITHUB_TOKEN}
```

Start the app in development mode to make sure the initial setup of backstage is working properly:

```bash
yarn dev
```

This will launch your Backstage app at http://localhost:3000. 
Sign in as guest for now. You should see the default Backstage welcome page.

![](/images/blog/backstage-screen-1.png)

{{< callout type="warning" >}}
  Make sure that your browser can access localhost:3000 and localhost:7007. Both ports are needed for the app to work.
  If needed they can be changed in the `app-config.yaml` file.
{{< /callout >}}
