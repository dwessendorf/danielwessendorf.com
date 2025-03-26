---
title: "Step 02: Setting up a new Backstage project"
type: docs
sidebar:
  open: true
prev: 01-introduction
next: 03-setting-up-a-github-personal-access-toke
---
## Prerequisites

- Node.js 16 or later
- Yarn
- Docker (for TechDocs)
- Git
- A GitHub account
- A Confluent Cloud account with API keys

{{< callout type="info" >}}
  For detailed instructions on how to install the prerequisites, please refer to the [Backstage documentation](https://backstage.io/docs/getting-started/#prerequisites). 
  
  If the code provided in this blog post is not working with the latest version of Backstage, you could try to use the specific versions that were used to develop this blog post (Node.js 20.18.3, Yarn 4.4.1, Backstage 1.37.0).
{{< /callout >}}

## Setting Up a New Backstage Project

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