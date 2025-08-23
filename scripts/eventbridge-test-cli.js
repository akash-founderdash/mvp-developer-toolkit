#!/usr/bin/env node

/**
 * EventBridge Test CLI
 * A command-line tool to test sending events to EventBridge for MVP development
 */

import { createMVPEventBridgeClient, MVPDevelopmentEvent } from '../packages/api/src/eventbridge-client';

interface CLIOptions {
  action: string;
  jobId?: string;
  userId?: string;
  productId?: string;
  priority?: 'high' | 'normal' | 'low';
  businessName?: string;
  region?: string;
  eventBus?: string;
}

function parseArgs(): CLIOptions {
  const args = process.argv.slice(2);
  const options: CLIOptions = {
    action: 'send',
    priority: 'normal',
    region: process.env.AWS_REGION || 'us-east-1',
    eventBus: process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development'
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const nextArg = args[i + 1];

    switch (arg) {
      case '--action':
      case '-a':
        options.action = nextArg;
        i++;
        break;
      case '--job-id':
      case '-j':
        options.jobId = nextArg;
        i++;
        break;
      case '--user-id':
      case '-u':
        options.userId = nextArg;
        i++;
        break;
      case '--product-id':
      case '-p':
        options.productId = nextArg;
        i++;
        break;
      case '--priority':
        options.priority = nextArg as 'high' | 'normal' | 'low';
        i++;
        break;
      case '--business-name':
      case '-b':
        options.businessName = nextArg;
        i++;
        break;
      case '--region':
      case '-r':
        options.region = nextArg;
        i++;
        break;
      case '--event-bus':
      case '-e':
        options.eventBus = nextArg;
        i++;
        break;
      case '--help':
      case '-h':
        showHelp();
        process.exit(0);
    }
  }

  return options;
}

function showHelp() {
  console.log(`
EventBridge Test CLI - MVP Development Event Sender

USAGE:
  node eventbridge-test-cli.js [OPTIONS]

ACTIONS:
  send          Send a new MVP development request (default)
  test          Test EventBridge connection
  batch         Send multiple test events

OPTIONS:
  -a, --action          Action to perform (send|test|batch)
  -j, --job-id          Job ID (auto-generated if not provided)
  -u, --user-id         User ID (required for send action)
  -p, --product-id      Product ID (required for send action)
  --priority            Priority level (high|normal|low)
  -b, --business-name   Business name for the MVP
  -r, --region          AWS region (default: us-east-1)
  -e, --event-bus       EventBridge bus name (default: mvp-development)
  -h, --help            Show this help message

EXAMPLES:
  # Send a single MVP development request
  node eventbridge-test-cli.js --action send --user-id user123 --product-id prod456 --business-name "My Startup"

  # Test EventBridge connection
  node eventbridge-test-cli.js --action test

  # Send batch of test events
  node eventbridge-test-cli.js --action batch

  # Send high priority request
  node eventbridge-test-cli.js --action send --user-id user123 --product-id prod456 --priority high

ENVIRONMENT VARIABLES:
  AWS_REGION                AWS region for EventBridge
  AWS_ACCESS_KEY_ID         AWS access key
  AWS_SECRET_ACCESS_KEY     AWS secret key
  EVENTBRIDGE_BUS_NAME      EventBridge bus name
  FOUNDERDASH_DATABASE_URL  FounderDash database URL
`);
}

async function sendMVPEvent(options: CLIOptions): Promise<void> {
  if (!options.userId || !options.productId) {
    console.error('❌ Error: --user-id and --product-id are required for send action');
    process.exit(1);
  }

  const client = createMVPEventBridgeClient({
    region: options.region!,
    eventBusName: options.eventBus!,
    source: 'founderdash.web',
    detailType: 'MVP Development Request'
  });

  const jobId = options.jobId || `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

  const event: MVPDevelopmentEvent = {
    jobId,
    userId: options.userId,
    productId: options.productId,
    founderdashDbUrl: process.env.FOUNDERDASH_DATABASE_URL || 'postgresql://test:test@localhost:5432/founderdash',
    priority: options.priority,
    metadata: {
      businessName: options.businessName || 'Test Business',
      estimatedDuration: 4 * 60 * 60, // 4 hours
      features: ['authentication', 'dashboard', 'payments'],
      testEvent: true,
      generatedAt: new Date().toISOString()
    }
  };

  try {
    console.log('🚀 Sending MVP development event...');
    console.log('Event Details:');
    console.log(JSON.stringify(event, null, 2));
    console.log('');

    const eventId = await client.sendMVPDevelopmentRequest(event);
    
    console.log('✅ Event sent successfully!');
    console.log(`Event ID: ${eventId}`);
    console.log(`Job ID: ${jobId}`);
    console.log(`Priority: ${options.priority}`);
    console.log('');
    console.log('💡 You can now check AWS Batch for job execution.');
    console.log('💡 Monitor DynamoDB for job status updates.');

  } catch (error) {
    console.error('❌ Failed to send event:', error);
    process.exit(1);
  }
}

async function testConnection(options: CLIOptions): Promise<void> {
  const client = createMVPEventBridgeClient({
    region: options.region!,
    eventBusName: options.eventBus!,
    source: 'founderdash.cli.test',
    detailType: 'Connection Test'
  });

  try {
    console.log('🔍 Testing EventBridge connection...');
    console.log(`Region: ${options.region}`);
    console.log(`Event Bus: ${options.eventBus}`);
    console.log('');

    const isConnected = await client.testConnection();
    
    if (isConnected) {
      console.log('✅ EventBridge connection successful!');
      console.log('🎉 Your AWS credentials and configuration are working correctly.');
    } else {
      console.log('❌ EventBridge connection failed.');
      console.log('💡 Check your AWS credentials and region configuration.');
    }

  } catch (error) {
    console.error('❌ Connection test failed:', error);
    console.log('');
    console.log('💡 Troubleshooting tips:');
    console.log('   - Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables');
    console.log('   - Check AWS_REGION environment variable');
    console.log('   - Ensure EventBridge permissions are configured correctly');
    console.log('   - Verify the EventBridge bus exists in your AWS account');
    process.exit(1);
  }
}

async function sendBatchEvents(options: CLIOptions): Promise<void> {
  const client = createMVPEventBridgeClient({
    region: options.region!,
    eventBusName: options.eventBus!,
    source: 'founderdash.cli.batch',
    detailType: 'MVP Development Request'
  });

  const batchSize = 5;
  const events: MVPDevelopmentEvent[] = [];

  for (let i = 1; i <= batchSize; i++) {
    const timestamp = Date.now();
    const jobId = `batch_job_${timestamp}_${i}_${Math.random().toString(36).substr(2, 6)}`;
    
    events.push({
      jobId,
      userId: `batch_user_${i}`,
      productId: `batch_product_${i}`,
      founderdashDbUrl: process.env.FOUNDERDASH_DATABASE_URL || 'postgresql://test:test@localhost:5432/founderdash',
      priority: i % 3 === 0 ? 'high' : i % 2 === 0 ? 'normal' : 'low',
      metadata: {
        businessName: `Batch Test Business ${i}`,
        estimatedDuration: 4 * 60 * 60,
        features: ['feature1', 'feature2', 'feature3'],
        batchTest: true,
        batchIndex: i,
        generatedAt: new Date().toISOString()
      }
    });
  }

  try {
    console.log(`🚀 Sending batch of ${batchSize} MVP development events...`);
    console.log('');

    const eventIds = await client.sendBatchMVPRequests(events);
    
    console.log('✅ Batch events sent successfully!');
    console.log('Event Details:');
    
    eventIds.forEach((eventId, index) => {
      const event = events[index];
      console.log(`  ${index + 1}. Job ID: ${event.jobId} | Event ID: ${eventId} | Priority: ${event.priority}`);
    });
    
    console.log('');
    console.log('💡 Check AWS Batch for multiple job executions.');
    console.log('💡 Monitor DynamoDB for job status updates.');

  } catch (error) {
    console.error('❌ Failed to send batch events:', error);
    process.exit(1);
  }
}

async function main() {
  const options = parseArgs();

  console.log('EventBridge Test CLI for MVP Development');
  console.log('=====================================');
  console.log('');

  switch (options.action) {
    case 'send':
      await sendMVPEvent(options);
      break;
    case 'test':
      await testConnection(options);
      break;
    case 'batch':
      await sendBatchEvents(options);
      break;
    default:
      console.error(`❌ Unknown action: ${options.action}`);
      console.log('Use --help for usage information.');
      process.exit(1);
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

// Run the CLI
if (require.main === module) {
  main().catch(console.error);
}

export { CLIOptions, sendMVPEvent, testConnection, sendBatchEvents };
