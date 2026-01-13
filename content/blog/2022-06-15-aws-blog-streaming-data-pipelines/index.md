---
title: "Build streaming data pipelines with Amazon MSK Serverless and IAM authentication"
date: 2023-09-06
draft: false
summary: "Learn how to build a serverless Apache Kafka producer using AWS Lambda and API Gateway to push real-time streaming data to Amazon MSK, with Java implementation examples and CDK deployment."
tags: ["AWS Serverless MSK"]
---


*This post is by Marvin Gersho, Daniel Wessendorf, Philipp Klose, and Nathan Lichtenstein for the AWS Bigdata Compute Blog.*

*Original URL:* https://aws.amazon.com/blogs/big-data/build-streaming-data-pipelines-with-amazon-msk-serverless-and-iam-authentication/


Currently, MSK Serverless only directly supports IAM for authentication using Java. This example shows how to use this mechanism. Additionally, it provides a pattern creating a proxy that can easily be integrated into solutions built in languages other than Java.

The rising trend in today's tech landscape is the use of streaming data and event-oriented structures. They are being applied in numerous ways, including monitoring website traffic, tracking industrial Internet of Things (IoT) devices, analyzing video game player behavior, and managing data for cutting-edge analytics systems.

Apache Kafka, a top-tier open-source tool, is making waves in this domain. It's widely adopted by numerous users for building fast and efficient data pipelines, analyzing streaming data, merging data from different sources, and supporting essential applications.

Amazon's serverless Apache Kafka offering, Amazon Managed Streaming for Apache Kafka (Amazon MSK) Serverless, is attracting a lot of interest. It's appreciated for its user-friendly approach, ability to scale automatically, and cost-saving benefits over other Kafka solutions. However, a hurdle encountered by many users is the requirement of MSK Serverless to use AWS Identity and Access Management (IAM) access control. At the time of writing, the Amazon MSK library for IAM is exclusive to Kafka libraries in Java, creating a challenge for users of other programming languages. In this post, we aim to address this issue and present how you can use Amazon API Gateway and AWS Lambda to navigate around this obstacle.

## SASL/SCRAM authentication vs. IAM authentication

Compared to the traditional authentication methods like Salted Challenge Response Authentication Mechanism (SCRAM), the IAM extension into Apache Kafka through MSK Serverless provides a lot of benefits. Before we delve into those, it's important to understand what SASL/SCRAM authentication is. Essentially, it's a traditional method used to confirm a user's identity before giving them access to a system. This process requires users or clients to provide a user name and password, which the system then cross-checks against stored credentials (for example, via AWS Secrets Manager) to decide whether or not access should be granted.

Compared to this approach, IAM simplifies permission management across AWS environments, enables the creation and strict enforcement of detailed permissions and policies, and uses temporary credentials rather than the typical user name and password authentication. Another benefit of using IAM is that you can use IAM for both authentication and authorization. If you use SASL/SCRAM, you have to additionally manage ACLs via a separate mechanism. In IAM, you can use the IAM policy attached to the IAM principal to define the fine-grained access control for that IAM principal. All of these improvements make the IAM integration a more efficient and secure solution for most use cases.

However, for applications not built in Java, utilizing MSK Serverless becomes tricky. The standard SASL/SCRAM authentication isn't available, and non-Java Kafka libraries don't have a way to use IAM access control. This calls for an alternative approach to connect to MSK Serverless clusters.

But there's an alternative pattern. Without having to rewrite your existing application in Java, you can employ API Gateway and Lambda as a proxy in front of a cluster. They can handle API requests and relay them to Kafka topics instantly. API Gateway takes in producer requests and channels them to a Lambda function, written in Java using the Amazon MSK IAM library. It then communicates with the MSK Serverless Kafka topic using IAM access control. After the cluster receives the message, it can be further processed within the MSK Serverless setup.

You can also utilize Lambda on the consumer side of MSK Serverless topics, bypassing the Java requirement on the consumer side. You can do this by setting Amazon MSK as an event source for a Lambda function. When the Lambda function is triggered, the data sent to the function includes an array of records from the Kafka topic—no need for direct contact with Amazon MSK.

## Solution overview

This example walks you through how to build a serverless real-time stream producer application using API Gateway and Lambda.

For testing, this post includes a sample AWS Cloud Development Kit (AWS CDK) application. This creates a demo environment, including an MSK Serverless cluster, three Lambda functions, and an API Gateway that consumes the messages from the Kafka topic.

The following diagram shows the architecture of the resulting application including its data flows.


![](/images/blog/aws_kafka_blog2_architecture.png)

The data flow contains the following steps:

1.  The infrastructure is defined in an AWS CDK application. By running this application, a set of AWS CloudFormation templates is created. AWS CloudFormation creates all infrastructure components, including a Lambda function that runs during the deployment process to create a topic in the MSK Serverless cluster and to retrieve the authentication endpoint needed for the producer Lambda function. On destruction of the CloudFormation stack, the same Lambda function gets triggered again to delete the topic from the cluster.
2.  An external application calls an API Gateway endpoint.
3.  API Gateway forwards the request to a Lambda function.
4.  The Lambda function acts as a Kafka producer and pushes the message to a Kafka topic using IAM authentication.
5.  The Lambda event source mapping mechanism triggers the Lambda consumer function and forwards the message to it.
6.  The Lambda consumer function logs the data to Amazon CloudWatch.

Note that we don't need to worry about Availability Zones. MSK Serverless automatically replicates the data across multiple Availability Zones to ensure high availability of the data.

The demo additionally shows how to use Lambda Powertools for Java to streamline logging and tracing and the IAM authenticator for the simple authentication process outlined in the introduction.

## Prerequisites

The example has the following prerequisites:

* An AWS account.
* The following software installed on your development machine, or use an AWS Cloud9 environment:
    * Java Development Kit 17 or higher (e.g., Amazon Corretto 17, OpenJDK 17)
    * Python version 3.11 or higher
    * Apache Maven version 3.8.4 or higher
    * Docker version 24.0.2 or higher
    * Node.js v18.0.0
    * AWS CLI 2.12.1 or higher
    * AWS CDK 2.89.0 or higher
* Appropriate AWS credentials for interacting with resources in your AWS account.

## Deploy the solution

Complete the following steps to deploy the solution:

1.  Clone the project GitHub repository and change the directory to subfolder `serverless-kafka-iac`:

    ```bash
    git clone [https://github.com/aws-samples/apigateway-lambda-msk-serverless-integration](https://github.com/aws-samples/apigateway-lambda-msk-serverless-integration)
    cd apigateway-lambda-msk-serverless-integration/serverless-kafka-iac
    ```

2.  Configure environment variables:

    ```bash
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
    export CDK_DEFAULT_REGION=$(aws configure get region)
    ```

3.  Prepare the virtual Python environment:

    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip3 install -r requirements.txt
    ```

4.  Bootstrap your account for AWS CDK usage:

    ```bash
    cdk bootstrap aws://$CDK_DEFAULT_ACCOUNT/$CDK_DEFAULT_REGION
    ```

5.  Run `cdk synth` to build the code and test the requirements (ensure docker daemon is running on your machine):

    ```bash
    cdk synth
    ```

6.  Run `cdk deploy` to deploy the code to your AWS account:

    ```bash
    cdk deploy --all
    ```

## Test the solution

To test the solution, we generate messages for the Kafka topics by sending calls through the API Gateway from our development machine or AWS Cloud9 environment. We then go to the CloudWatch console to observe incoming messages in the log files of the Lambda consumer function.

1.  Open a terminal on your development machine to test the API with the Python script provided under `/serverless_kafka_iac/test_api.py`:

    ```bash
    python3 test-api.py
    ```
![](/images/blog/aws_kafka_blog2_deploy.png)

2.  On the Lambda console, open the Lambda function named `ServerlessKafkaConsumer`.
![](/images/blog/aws_kafka_blog2_lambda_functions.png)
3.  On the Monitor tab, choose View CloudWatch logs to access the logs of the Lambda function.
![](/images/blog/aws_kafka_blog2_ServerlessKafkaProducer.png)
4.  Choose the latest log stream to access the log files of the last run.
![](/images/blog/aws_kafka_blog2_logstream.png)
5.  You can review the log entry of the received Kafka messages in the log of the Lambda function.
![](/images/blog/aws_kafka_blog2_logentry.png)

## Trace a request

All components integrate with AWS X-Ray. With AWS X-Ray, you can trace the entire application, which is useful to identify bottlenecks when load testing. You can also trace method runs at the Java method level.

Lambda Powertools for Java allows you to shortcut this process by adding the `@Trace` annotation to a method to see traces on the method level in X-Ray.

To trace a request end to end, complete the following steps:

1.  On the CloudWatch console, choose Service map in the navigation pane.
2.  Select a component to investigate (for example, the Lambda function where you deployed the Kafka producer).
3.  Choose View traces.
![](/images/blog/aws_kafka_blog2_traces.png)
4.  Choose a single Lambda method invocation and investigate further at the Java method level.
3.  Choose View traces.
![](/images/blog/aws_kafka_blog2_java_investigation.png)
## Implement a Kafka producer in Lambda

Kafka natively supports Java. To stay open, cloud native, and without third-party dependencies, the producer is written in that language. Currently, the IAM authenticator is only available to Java. In this example, the Lambda handler receives a message from an API Gateway source and pushes this message to an MSK topic called messages.

Typically, Kafka producers are long-living and pushing a message to a Kafka topic is an asynchronous process. Because Lambda is ephemeral, you must enforce a full flush of a submitted message until the Lambda function ends by calling `producer.flush()`:

```java
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
package software.amazon.samples.kafka.lambda;

// This class is part of the AWS samples package and specifically deals with Kafka integration in a Lambda function.
// It serves as a simple API Gateway to Kafka Proxy, accepting requests and forwarding them to a Kafka topic.
public class SimpleApiGatewayKafkaProxy implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    // Specifies the name of the Kafka topic where the messages will be sent
    public static final String TOPIC_NAME = "messages";

    // Logger instance for logging events of this class
    private static final Logger log = LogManager.getLogger(SimpleApiGatewayKafkaProxy.class);

    // Factory to create properties for Kafka Producer
    public KafkaProducerPropertiesFactory kafkaProducerProperties = new KafkaProducerPropertiesFactoryImpl();

    // Instance of KafkaProducer
    private KafkaProducer<String, String> producer;

    // Overridden method from the RequestHandler interface to handle incoming API Gateway proxy events
    @Override
    @Tracing
    @Logging(logEvent = true)
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        // Creating a response object to send back
        APIGatewayProxyResponseEvent response = createEmptyResponse();
        try {
            // Extracting the message from the request body
            String message = getMessageBody(input);

            // Create a Kafka producer
            KafkaProducer<String, String> producer = createProducer();

            // Creating a record with topic name, request ID as key and message as value
            ProducerRecord<String, String> record = new ProducerRecord<String, String>(TOPIC_NAME, context.getAwsRequestId(), message);

            // Sending the record to Kafka topic and getting the metadata of the record
            Future<RecordMetadata> send = producer.send(record);
            producer.flush();

            // Retrieve metadata about the sent record
            RecordMetadata metadata = send.get();

            // Logging the partition where the message was sent
            log.info(String.format("Message was send to partition %s", metadata.partition()));

            // If the message was successfully sent, return a 200 status code
            return response.withStatusCode(200).withBody("Message successfully pushed to kafka");
        } catch (Exception e) {
            // In case of exception, log the error message and return a 500 status code
            log.error(e.getMessage(), e);
            return response.withBody(e.getMessage()).withStatusCode(500);
        }
    }

    // Creates a Kafka producer if it doesn't already exist
    @Tracing
    private KafkaProducer<String, String> createProducer() {
        if (producer == null) {
            log.info("Connecting to kafka cluster");
            producer = new KafkaProducer<String, String>(kafkaProducerProperties.getProducerProperties());
        }
        return producer;
    }

    // Extracts the message from the request body. If it's base64 encoded, it's decoded first.
    private String getMessageBody(APIGatewayProxyRequestEvent input) {
        String body = input.getBody();
        if (input.getIsBase64Encoded()) {
            body = decode(body);
        }
        return body;
    }

    // Creates an empty API Gateway proxy response event with predefined headers.
    private APIGatewayProxyResponseEvent createEmptyResponse() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        headers.put("X-Custom-Header", "application/json");
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent().withHeaders(headers);
        return response;
    }
}

```

## Connect to Amazon MSK using IAM authentication

This post uses IAM authentication to connect to the respective Kafka cluster. For information about how to configure the producer for connectivity, refer to IAM access control.

Because you configure the cluster via IAM, grant Connect and WriteData permissions to the producer so that it can push messages to Kafka:

```json
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Effect": "Allow",
 "Action": [
 "kafka-cluster:Connect"
 ],
 "Resource": "arn:aws:kafka:region:account-id:cluster/cluster-name/cluster-uuid "
 }
 ]
}

```

```json
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Effect": "Allow",
 "Action": [
 "kafka-cluster:Connect",
 "kafka-cluster: DescribeTopic",
 ],
 "Resource": "arn:aws:kafka:region:account-id:topic/cluster-name/cluster-uuid/topic-name"
 }
 ]
}

```

This shows the Kafka excerpt of the IAM policy, which must be applied to the Kafka producer. When using IAM authentication, be aware of the current limits of IAM Kafka authentication, which affect the number of concurrent connections and IAM requests for a producer. Refer to Amazon MSK quota and follow the recommendation for authentication backoff in the producer client:

```java
Map<String, String> configuration = Map.of(
 “key.serializer”, “org.apache.kafka.common.serialization.StringSerializer”,
 “value.serializer”, “org.apache.kafka.common.serialization.StringSerializer”,
 “bootstrap.servers”, getBootstrapServer(),
 “security.protocol”, “SASL_SSL”,
 “sasl.mechanism”, “AWS_MSK_IAM”,
 “sasl.jaas.config”, “software.amazon.msk.auth.iam.IAMLoginModule required;”,
 “sasl.client.callback.handler.class”, “software.amazon.msk.auth.iam.IAMClientCallbackHandler”,
 “connections.max.idle.ms”, “60”,
 “reconnect.backoff.ms”, “1000”
 );

```

## Additional considerations

Each MSK Serverless cluster can handle 100 requests per second. To reduce IAM authentication requests from the Kafka producer, place it outside of the handler. For frequent calls, there is a chance that Lambda reuses the previously created class instance and only reruns the handler.

For bursting workloads with a high number of concurrent API Gateway requests, this can lead to dropped messages. Although this might be tolerable for some workloads, for others this might not be the case.

In these cases, you can extend the architecture with a buffering technology like Amazon Simple Queue Service (Amazon SQS) or Amazon Kinesis Data Streams between API Gateway and Lambda.

```

```