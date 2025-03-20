---
title: 8 - Run and Test the Solution
type: docs
prev: 07-create-confluent-cluster-templates

---
## Step 9: Start Your Backstage App

Now we can start the Backstage app with our custom templates:

```bash
yarn dev
```

## The User Journey

Let's walk through the user journey:

1. A developer logs into Backstage using their GitHub credentials
2. They navigate to the "Create" page and select the "Deploy Confluent Cloud Environment" template
3. They fill in the form with their desired environment name
4. The system creates a new GitHub repository with Terraform code
5. GitHub Actions runs the Terraform code to provision the Confluent Cloud environment
6. The new environment is registered in the Backstage catalog
7. The developer can then use the "Deploy Confluent Cloud Cluster" template to create a cluster in the environment
8. They select their environment from the dropdown and configure the cluster
9. A new GitHub repository is created for the cluster
10. GitHub Actions provisions the cluster in Confluent Cloud
11. The cluster is registered in the Backstage catalog with a dependency on the environment

## Conclusion

We've built a powerful self-service platform that enables developers to provision their own Confluent Cloud environments and clusters with just a few clicks. This approach:

- Reduces the operational burden on platform teams
- Ensures consistency through Infrastructure as Code
- Provides a great developer experience
- Maintains visibility and governance through the Backstage catalog

By combining Backstage, GitHub, Terraform, and Confluent Cloud, we've created a solution that demonstrates the power of modern developer platforms.

## Next Steps

Future enhancements could include:
- Adding templates for Kafka topics and schemas
- Implementing access control and permissions
- Adding cost tracking and quota management
- Integrating with monitoring systems for observability

Happy coding!
