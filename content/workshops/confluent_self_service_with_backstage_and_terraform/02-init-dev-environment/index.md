---
title: 02 - Initialize Development Envionment
type: docs
prev: workshops/01-introduction
---
## Prerequisites

- Node.js 16 or later
- Yarn
- Docker (for TechDocs)
- Git
- A GitHub account
- A Confluent Cloud account with API keys

## Step 1: Setting Up a New Backstage Project

Let's start by creating a new Backstage project:

```bash
# Install the Backstage CLI
npm install -g @backstage/cli

# Create a new Backstage app
npx @backstage/create-app

# Follow the prompts to set up your app
# For this tutorial, we'll name it "confluent-backstage"
```

After the installation completes, navigate to your new project:

```bash
cd confluent-backstage
```

Start the app in development mode to make sure everything is working:

```bash
yarn dev
```

This will launch your Backstage app at http://localhost:3000. You should see the default Backstage welcome page.
