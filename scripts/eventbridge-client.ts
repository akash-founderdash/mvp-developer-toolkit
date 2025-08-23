import { EventBridge } from '@aws-sdk/client-eventbridge';

export interface MVPDevelopmentEvent {
  jobId: string;
  userId: string;
  productId: string;
  founderdashDbUrl: string;
  priority?: 'high' | 'normal' | 'low';
  metadata?: {
    businessName?: string;
    estimatedDuration?: number;
    features?: string[];
    [key: string]: any;
  };
}

export interface EventBridgeConfig {
  region: string;
  eventBusName: string;
  source: string;
  detailType: string;
}

export class MVPEventBridgeClient {
  private eventBridge: EventBridge;
  private config: EventBridgeConfig;

  constructor(config: EventBridgeConfig) {
    this.config = config;
    this.eventBridge = new EventBridge({ 
      region: config.region,
      // AWS credentials will be automatically loaded from environment
    });
  }

  /**
   * Send MVP Development Request to EventBridge
   */
  async sendMVPDevelopmentRequest(event: MVPDevelopmentEvent): Promise<string> {
    try {
      console.log(`🚀 Sending MVP development request for job: ${event.jobId}`);
      
      const eventEntry = {
        Source: this.config.source,
        DetailType: this.config.detailType,
        Detail: JSON.stringify({
          jobId: event.jobId,
          userId: event.userId,
          productId: event.productId,
          founderdashDbUrl: event.founderdashDbUrl,
          priority: event.priority || 'normal',
          timestamp: new Date().toISOString(),
          metadata: event.metadata || {},
        }),
        EventBusName: this.config.eventBusName,
        Resources: [],
      };

      const response = await this.eventBridge.putEvents({
        Entries: [eventEntry]
      });

      // Check for failures
      if (response.FailedEntryCount && response.FailedEntryCount > 0) {
        const failures = response.Entries?.filter(entry => entry.ErrorCode);
        throw new Error(`EventBridge put failed: ${JSON.stringify(failures)}`);
      }

      const eventId = response.Entries?.[0]?.EventId;
      console.log(`✅ Event sent successfully. EventId: ${eventId}`);
      
      return eventId || 'unknown';
      
    } catch (error) {
      console.error('❌ Failed to send event to EventBridge:', error);
      throw new Error(`EventBridge send failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Send batch of MVP development requests
   */
  async sendBatchMVPRequests(events: MVPDevelopmentEvent[]): Promise<string[]> {
    if (events.length > 10) {
      throw new Error('EventBridge supports maximum 10 events per batch');
    }

    try {
      console.log(`🚀 Sending batch of ${events.length} MVP development requests`);
      
      const eventEntries = events.map(event => ({
        Source: this.config.source,
        DetailType: this.config.detailType,
        Detail: JSON.stringify({
          jobId: event.jobId,
          userId: event.userId,
          productId: event.productId,
          founderdashDbUrl: event.founderdashDbUrl,
          priority: event.priority || 'normal',
          timestamp: new Date().toISOString(),
          metadata: event.metadata || {},
        }),
        EventBusName: this.config.eventBusName,
        Resources: [],
      }));

      const response = await this.eventBridge.putEvents({
        Entries: eventEntries
      });

      // Check for failures
      if (response.FailedEntryCount && response.FailedEntryCount > 0) {
        const failures = response.Entries?.filter(entry => entry.ErrorCode);
        throw new Error(`EventBridge batch put failed: ${JSON.stringify(failures)}`);
      }

      const eventIds = response.Entries?.map(entry => entry.EventId || 'unknown') || [];
      console.log(`✅ Batch events sent successfully. EventIds: ${eventIds.join(', ')}`);
      
      return eventIds;
      
    } catch (error) {
      console.error('❌ Failed to send batch events to EventBridge:', error);
      throw new Error(`EventBridge batch send failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Send custom event to EventBridge
   */
  async sendCustomEvent(
    source: string, 
    detailType: string, 
    detail: any, 
    resources: string[] = []
  ): Promise<string> {
    try {
      console.log(`🚀 Sending custom event: ${detailType} from ${source}`);
      
      const eventEntry = {
        Source: source,
        DetailType: detailType,
        Detail: JSON.stringify(detail),
        EventBusName: this.config.eventBusName,
        Resources: resources,
      };

      const response = await this.eventBridge.putEvents({
        Entries: [eventEntry]
      });

      // Check for failures
      if (response.FailedEntryCount && response.FailedEntryCount > 0) {
        const failures = response.Entries?.filter(entry => entry.ErrorCode);
        throw new Error(`Custom event put failed: ${JSON.stringify(failures)}`);
      }

      const eventId = response.Entries?.[0]?.EventId;
      console.log(`✅ Custom event sent successfully. EventId: ${eventId}`);
      
      return eventId || 'unknown';
      
    } catch (error) {
      console.error('❌ Failed to send custom event to EventBridge:', error);
      throw new Error(`Custom event send failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Test EventBridge connection
   */
  async testConnection(): Promise<boolean> {
    try {
      // Send a test event
      const testEvent = {
        jobId: `test_${Date.now()}`,
        userId: 'test_user',
        productId: 'test_product',
        founderdashDbUrl: 'test://connection',
        metadata: {
          isTestEvent: true,
        }
      };

      await this.sendMVPDevelopmentRequest(testEvent);
      return true;
    } catch (error) {
      console.error('EventBridge connection test failed:', error);
      return false;
    }
  }
}

/**
 * Factory function to create EventBridge client with default configuration
 */
export function createMVPEventBridgeClient(overrides: Partial<EventBridgeConfig> = {}): MVPEventBridgeClient {
  const defaultConfig: EventBridgeConfig = {
    region: process.env.AWS_REGION || 'us-east-1',
    eventBusName: process.env.EVENTBRIDGE_BUS_NAME || 'mvp-development',
    source: 'founderdash.web',
    detailType: 'MVP Development Request',
    ...overrides
  };

  return new MVPEventBridgeClient(defaultConfig);
}

export default MVPEventBridgeClient;
