const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const crypto = require('crypto');

const client = new EventBridgeClient({ region: "us-east-2" });

async function submitTestJob() {
    const jobId = crypto.randomBytes(16).toString('hex');
    
    const testEvent = {
        Source: "founderdash.mvp.queue",
        DetailType: "MVP Development Request",
        Detail: JSON.stringify({
            jobId: jobId,
            stage: "AI_DEVELOPMENT",
            projectName: "TEST-" + jobId.slice(0, 8),
            projectDescription: "Testing directory path fix - source directory validation",
            userInstructions: "Create a simple Next.js app with home page and about page",
            environment: {
                variables: {
                    LOG_LEVEL: "INFO",
                    AWS_DEFAULT_REGION: "us-east-2"
                }
            }
        })
    };

    try {
        const command = new PutEventsCommand({
            Entries: [testEvent]
        });
        
        const response = await client.send(command);
        console.log('Event submitted successfully:', {
            jobId: jobId,
            projectName: "TEST-" + jobId.slice(0, 8),
            eventId: response.Entries[0].EventId
        });
        
        console.log('Monitor the job at:');
        console.log('https://console.aws.amazon.com/batch/home?region=us-east-2#/jobs');
        console.log('Search for job name containing:', jobId);
        
        return jobId;
    } catch (error) {
        console.error('Error submitting event:', error);
        throw error;
    }
}

submitTestJob().catch(console.error);
