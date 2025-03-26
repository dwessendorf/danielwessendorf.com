---
title: "Step 10: Start Your Backstage App"
type: docs
sidebar:
  open: true
prev: 09-update-app-configuration
next: _index
---
Now we can start the Backstage app with our custom templates:

```bash
yarn dev
```

## The User Journey

Let's walk through the user journey:

1. A user logs into Backstage using their GitHub credentials.
![](/images/blog/backstage-user-journey-1.png)

2. The user navigates to the "Create" page and selects the "Deploy Confluent Cloud Environment" template.
![](/images/blog/backstage-user-journey-2.png)


3. The user fills in the form with his/her desired environment name.
![](/images/blog/backstage-user-journey-3.png)


4. The system creates a new GitHub repository with Terraform code.
![](/images/blog/backstage-user-journey-4.png)


5. The new environment is registered in the Backstage catalog.
![](/images/blog/backstage-user-journey-5.png)

6. GitHub Actions runs the Terraform code to provision the Confluent Cloud environment. The user can see the progress in the CI/CD tab of the backstage app.
![](/images/blog/backstage-user-journey-6.png)

7. The user can also see the environment details in the documentation page of the backstage app.
![](/images/blog/backstage-user-journey-7.png)

8. The user can then use the "Deploy Confluent Cloud Cluster" template to create a cluster in the environment. The EntityPicker-component allows the user to select the environment we just created.
![](/images/blog/backstage-user-journey-8.png)

9.The cluster is registered in the Backstage catalog with a dependency on the environment.
![](/images/blog/backstage-user-journey-9.png)

10. GitHub Actions runs the Terraform code to provision the Confluent Cloud cluster. The user can see the progress in the CI/CD tab of the backstage app.
![](/images/blog/backstage-user-journey-10.png)

11. The user follows the instructions in the Operations Guide section of the documentation page to learn how to access the cluster in the Confluent Cloud Console.
![](/images/blog/backstage-user-journey-11.png)

12. The user logs in to Confluent Cloud and can see the cluster details of the newly created cluster in the console.
![](/images/blog/backstage-user-journey-12.png)


## Conclusion

We've built a powerful self-service platform that enables developers to provision their own Confluent Cloud environments and clusters with just a few clicks. This approach:

- Reduces the operational burden on platform teams
- Ensures consistency through Infrastructure as Code
- Provides a great developer experience
- Maintains visibility and governance through the Backstage catalog

By combining Backstage, GitHub, Terraform, and Confluent Cloud, we've created a solution that demonstrates the power of modern developer platforms.

## Next Steps

Future enhancements could include:
- Adding templates for Schema Registry, Kafka topics, Confluent Connect and Flink components
- Implementing access control and permissions
- Adding cost tracking and quota management
- Integrating with monitoring systems for observability

Happy coding!