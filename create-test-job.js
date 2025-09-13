const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const crypto = require('crypto');

const dynamoClient = new DynamoDBClient({ region: "us-east-2" });
const eventClient = new EventBridgeClient({ region: "us-east-2" });

async function createTestJob() {
    const jobId = crypto.randomBytes(16).toString('hex');
    const timestamp = new Date().toISOString();
    
    // Create DynamoDB record
    const jobData = {
        jobId: { S: jobId },
        businessName: { S: "Test Business Directory Fix" },
        userId: { S: "test-user" },
        productId: { S: "test-product" },
        stage: { S: "AI_DEVELOPMENT" },
        status: { S: "QUEUED" },
        createdAt: { S: timestamp },
        updatedAt: { S: timestamp },
        projectDescription: { S: "Testing directory path fix - source directory validation" },
        userInstructions: { S: "Create a simple Next.js app with home page and about page to test directory paths" }
    };
    
    try {
        // Put item in DynamoDB
        const putCommand = new PutItemCommand({
            TableName: "mvp-pipeline-development-jobs",
            Item: jobData
        });
        
        await dynamoClient.send(putCommand);
        console.log('✅ DynamoDB record created for job:', jobId);
        
        // Send EventBridge event
        const testEvent = {
            Source: "founderdash.web",
            DetailType: "MVP Development Request",
            EventBusName: "mvp-development",
            Detail: JSON.stringify({
                jobId: jobId,
                stage: "AI_DEVELOPMENT",
                projectName: "test-business-directory-fix",
                projectDescription: "Testing directory path fix - source directory validation",
                userInstructions: "Create a simple Next.js app with home page and about page to test directory paths"
            })
        };

        const eventCommand = new PutEventsCommand({
            Entries: [testEvent]
        });
        
        const response = await eventClient.send(eventCommand);
        console.log('✅ EventBridge event sent:', {
            jobId: jobId,
            eventId: response.Entries[0].EventId
        });
        
        return jobId;
    } catch (error) {
        console.error('❌ Error creating test job:', error);
        throw error;
    }
}

createTestJob().catch(console.error);
