#!/usr/bin/env node

/**
 * Simple EventBridge Test Script
 * Tests the EventBridge functionality without complex dependencies
 */

const AWS = require('aws-sdk');

// Configure AWS SDK
const eventBridge = new AWS.EventBridge({
    region: process.env.AWS_REGION || 'us-east-2',
    // AWS credentials should be in environment variables or AWS config
});

const dynamodb = new AWS.DynamoDB.DocumentClient({
    region: process.env.AWS_REGION || 'us-east-2'
});

/**
 * Send a test MVP development event to EventBridge
 */
async function sendTestEvent() {
    const jobId = `test_job_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    
    try {
        // 1. Create job record in DynamoDB
        console.log('🚀 Creating DynamoDB job record...');
        
        const jobRecord = {
            jobId,
            userId: 'test_user_123',
            productId: 'test_product_456', 
            businessName: 'Test Business',
            status: 'PENDING',
            currentStep: 'QUEUED',
            progress: 0,
            timestamps: {
                createdAt: new Date().toISOString(),
                startedAt: null,
                estimatedCompletion: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
                completedAt: null
            },
            resources: {
                batchJobId: null,
                githubRepo: { name: 'test-business-mvp', url: null, branch: 'main' },
                vercel: { projectId: null, deploymentId: null }
            },
            urls: { codeRepository: null, staging: null, production: null },
            errors: [],
            executionLogs: []
        };

        await dynamodb.put({
            TableName: process.env.DYNAMODB_TABLE_NAME || 'mvp-pipeline-development-jobs',
            Item: jobRecord
        }).promise();

        console.log(`✅ DynamoDB record created: ${jobId}`);

        // 2. Send EventBridge event
        console.log('🚀 Sending EventBridge event...');
        
        const eventParams = {
            Entries: [{
                Source: 'founderdash.web',
                DetailType: 'MVP Development Request',
                Detail: JSON.stringify({
                    jobId: jobId,
                    userId: 'test_user_123',
                    productId: 'test_product_456',
                    founderdashDbUrl: process.env.FOUNDERDASH_DATABASE_URL || 'postgresql://test:test@localhost:5432/founderdash',
                    priority: 'normal',
                    timestamp: new Date().toISOString(),
                    metadata: {
                        businessName: 'Test Business',
                        estimatedDuration: 14400,
                        features: ['authentication', 'dashboard', 'payments'],
                        testEvent: true
                    }
                }),
                EventBusName: process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development'
            }]
        };

        const result = await eventBridge.putEvents(eventParams).promise();
        
        if (result.FailedEntryCount > 0) {
            console.error('❌ EventBridge failures:', result.Entries.filter(entry => entry.ErrorCode));
            return;
        }

        const eventId = result.Entries[0].EventId;
        console.log(`✅ EventBridge event sent successfully!`);
        console.log(`   Job ID: ${jobId}`);
        console.log(`   Event ID: ${eventId}`);
        console.log('');
        console.log('💡 Next steps:');
        console.log('   1. Check AWS Batch for job execution');
        console.log('   2. Monitor DynamoDB for status updates');
        console.log(`   3. Query job status: aws dynamodb get-item --table-name ${process.env.DYNAMODB_TABLE_NAME || 'mvp-pipeline-development-jobs'} --key '{"jobId": {"S": "${jobId}"}}'`);

    } catch (error) {
        console.error('❌ Error sending test event:', error);
        
        if (error.code === 'ResourceNotFoundException') {
            console.log('');
            console.log('💡 Make sure to:');
            console.log('   1. Deploy the infrastructure: cd infrastructure && terraform apply');
            console.log('   2. Set environment variables: AWS_REGION, DYNAMODB_TABLE_NAME, EVENTBRIDGE_BUS_NAME');
            console.log('   3. Configure AWS credentials: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY');
        }
        
        process.exit(1);
    }
}

/**
 * Test DynamoDB connection
 */
async function testDynamoDB() {
    try {
        console.log('🔍 Testing DynamoDB connection...');
        
        const tableName = process.env.DYNAMODB_TABLE_NAME || 'mvp-pipeline-development-jobs';
        
        const result = await dynamodb.describeTable({
            TableName: tableName
        }).promise();
        
        console.log(`✅ DynamoDB table '${tableName}' exists`);
        console.log(`   Status: ${result.Table.TableStatus}`);
        console.log(`   Items: ${result.Table.ItemCount || 0}`);
        
    } catch (error) {
        console.error(`❌ DynamoDB connection failed:`, error.message);
        
        if (error.code === 'ResourceNotFoundException') {
            console.log(`💡 Table '${process.env.DYNAMODB_TABLE_NAME || 'mvp-pipeline-development-jobs'}' does not exist. Deploy infrastructure first.`);
        }
    }
}

/**
 * Test EventBridge connection
 */
async function testEventBridge() {
    try {
        console.log('🔍 Testing EventBridge connection...');
        
        const busName = process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development';
        
        const result = await eventBridge.describeEventBus({
            Name: busName
        }).promise();
        
        console.log(`✅ EventBridge bus '${busName}' exists`);
        console.log(`   ARN: ${result.Arn}`);
        
    } catch (error) {
        console.error(`❌ EventBridge connection failed:`, error.message);
        
        if (error.code === 'ResourceNotFoundException') {
            console.log(`💡 EventBridge bus '${process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development'}' does not exist. Deploy infrastructure first.`);
        }
    }
}

/**
 * Main function
 */
async function main() {
    const action = process.argv[2] || 'send';
    
    console.log('EventBridge MVP Development Test');
    console.log('================================');
    console.log('');
    console.log(`Region: ${process.env.AWS_REGION || 'us-east-2'}`);
    console.log(`DynamoDB Table: ${process.env.DYNAMODB_TABLE_NAME || 'mvp-pipeline-development-jobs'}`);
    console.log(`EventBridge Bus: ${process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development'}`);
    console.log('');

    switch (action) {
        case 'send':
            await sendTestEvent();
            break;
        case 'test-dynamo':
            await testDynamoDB();
            break;
        case 'test-eventbridge':
            await testEventBridge();
            break;
        case 'test-all':
            await testDynamoDB();
            console.log('');
            await testEventBridge();
            break;
        default:
            console.log('Usage: node simple-eventbridge-test.js [action]');
            console.log('');
            console.log('Actions:');
            console.log('  send              Send a test MVP development event (default)');
            console.log('  test-dynamo       Test DynamoDB connection');
            console.log('  test-eventbridge  Test EventBridge connection');
            console.log('  test-all          Test all connections');
            console.log('');
            console.log('Environment Variables:');
            console.log('  AWS_REGION                AWS region (default: us-east-2)');
            console.log('  AWS_ACCESS_KEY_ID         AWS access key');
            console.log('  AWS_SECRET_ACCESS_KEY     AWS secret key');
            console.log('  DYNAMODB_TABLE_NAME       DynamoDB table name (default: mvp-pipeline-development-jobs)');
            console.log('  EVENTBRIDGE_BUS_NAME      EventBridge bus name (default: mvp-development)');
            console.log('  FOUNDERDASH_DATABASE_URL  FounderDash database URL');
    }
}

// Run the script
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { sendTestEvent, testDynamoDB, testEventBridge };
