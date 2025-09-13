#!/usr/bin/env node

// Test script for updated pipeline with dynamic repository naming
const { EventBridgeClient, PutEventsCommand } = require('@aws-sdk/client-eventbridge');
const { DynamoDBClient, GetItemCommand } = require('@aws-sdk/client-dynamodb');

const region = 'us-east-2';
const eventBridge = new EventBridgeClient({ region });
const dynamodb = new DynamoDBClient({ region });

async function testUpdatedPipeline() {
    const timestamp = Date.now();
    const jobId = `test_updated_${timestamp}`;
    
    console.log('🚀 Testing Updated Pipeline with Enhanced develop-mvp.sh');
    console.log(`📝 Job ID: ${jobId}`);
    console.log('=' .repeat(60));
    
    // Test event with loan calculator MVP
    const testEvent = {
        Source: 'founderdash.web',
        DetailType: 'MVP Development Request',
        Detail: JSON.stringify({
            jobId: jobId,
            businessName: 'TechStartup Solutions',
            productDescription: 'AI-powered loan calculator with real-time interest rate analysis and personalized recommendations',
            requirements: 'Interactive loan calculator with dynamic rate updates, modern UI/UX, responsive design, and integration-ready APIs',
            timestamp: new Date().toISOString()
        }),
        EventBusName: 'mvp-development'
    };
    
    try {
        console.log('📤 Sending test event to EventBridge...');
        const command = new PutEventsCommand({
            Entries: [testEvent]
        });
        
        const result = await eventBridge.send(command);
        console.log('✅ Event sent successfully');
        console.log(`📊 EventBridge Response:`, {
            FailedEntryCount: result.FailedEntryCount,
            Entries: result.Entries?.length || 0
        });
        
        if (result.FailedEntryCount > 0) {
            console.error('❌ Some events failed:', result.Entries);
            return;
        }
        
        console.log('\n⏳ Waiting for job to start (30 seconds)...');
        await new Promise(resolve => setTimeout(resolve, 30000));
        
        // Monitor job progress
        console.log('\n📊 Monitoring job progress...');
        await monitorJobProgress(jobId);
        
    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

async function monitorJobProgress(jobId) {
    const maxChecks = 20; // 10 minutes max
    let checks = 0;
    
    while (checks < maxChecks) {
        try {
            const command = new GetItemCommand({
                TableName: 'mvp-pipeline-development-jobs',
                Key: {
                    jobId: { S: jobId }
                }
            });
            
            const result = await dynamodb.send(command);
            
            if (result.Item) {
                const status = result.Item.status?.S || 'UNKNOWN';
                const step = result.Item.step?.S || 'UNKNOWN';
                const progress = result.Item.progress?.N || '0';
                const repoName = result.Item.repoName?.S || 'Not set';
                const repoUrl = result.Item.repoUrl?.S || 'Not set';
                const lastUpdated = result.Item.updatedAt?.S || 'Unknown';
                
                console.log(`📊 Status Update [${new Date().toLocaleTimeString()}]:`);
                console.log(`   Status: ${status}`);
                console.log(`   Step: ${step}`);
                console.log(`   Progress: ${progress}%`);
                console.log(`   Repository Name: ${repoName}`);
                console.log(`   Repository URL: ${repoUrl}`);
                console.log(`   Last Updated: ${lastUpdated}`);
                console.log('-'.repeat(50));
                
                // Check for completion or failure
                if (status === 'COMPLETED') {
                    console.log('🎉 Pipeline completed successfully!');
                    console.log(`✅ Repository created: ${repoName}`);
                    console.log(`🔗 Repository URL: ${repoUrl}`);
                    break;
                } else if (status === 'FAILED') {
                    console.log('❌ Pipeline failed');
                    const error = result.Item.error?.S;
                    if (error) {
                        console.log(`💥 Error: ${error}`);
                    }
                    break;
                }
            } else {
                console.log(`⏳ Job ${jobId} not found in database yet...`);
            }
            
            checks++;
            if (checks < maxChecks) {
                console.log('⏳ Waiting 30 seconds before next check...\n');
                await new Promise(resolve => setTimeout(resolve, 30000));
            }
            
        } catch (error) {
            console.error(`❌ Error checking job status:`, error.message);
            checks++;
        }
    }
    
    if (checks >= maxChecks) {
        console.log('⏰ Monitoring timeout reached');
        console.log('💡 Check AWS Batch console and CloudWatch logs for more details');
    }
}

// Run the test
testUpdatedPipeline().catch(console.error);
