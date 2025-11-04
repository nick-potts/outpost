# Outpost Benchmark Specification - Railway Deployment

## Objective

Measure the true latency that Outpost adds to event delivery, from event receipt to delivery attempt.

## Test Scenario

**Target:** 100,000 events
**Infrastructure:** Railway (managed Postgres, Redis, RabbitMQ)
**Message Size:** Common Stripe/Shopify JSON event payload (~8KB)

### Publishers
- **Concurrent Publishers:** 10
- **Rate per Publisher:** 100 events/second
- **Total Rate:** 1,000 events/second
- **Duration:** 100 seconds to publish 100,000 messages

### Destinations/Subscriptions

To avoid connection reuse and test realistic fanout:

- **Webhooks:** 100 unique destinations (different URLs)
- **RabbitMQ:** 10 queues

**Total Subscriptions:** 110 destinations

### Topics

Not currently testing topic-based routing as part of benchmark. All destinations subscribe to wildcard `["*"]` or single test topic.

## Timestamps & Latency Measurement

### Timestamp Points

1. **Publisher Timestamp** (`t1`): When publisher sends event to Outpost
2. **Outpost Receipt** (`t2`): When Outpost API receives event
3. **Delivery Attempt** (`t3`): When Outpost delivery service attempts delivery
4. **Destination Receipt** (`t4`): When destination receives event

### Key Metrics

**Outpost Latency:** `t3 - t2` (true latency added by Outpost)
- This measures Outpost's internal processing time from API receipt to delivery attempt
- Excludes publisher → Outpost network time
- Excludes Outpost → destination network time

### Implementation

**Publisher (k6 test):**
- Add `sent_at` timestamp to event metadata before publishing
- Record when `POST /api/v1/publish` is called

**Outpost API:**
- Add `received_at` timestamp when event hits API handler (before queue)
- Store in event metadata

**Outpost Delivery Service:**
- Add `delivery_attempted_at` timestamp before HTTP request to destination
- Store in delivery attempt record

**Destination (Mock Webhook):**
- Record `received_at` timestamp when webhook receives event
- Store in Redis with event ID for verification

### Metric Calculations

**Throughput:**
```
messages_per_second = total_messages / (last_message_timestamp - first_message_timestamp)
```

**Latency Percentiles (for t3 - t2):**
- **P50 (Median):** 50% of messages processed faster
- **P95:** 95% of messages processed faster (acceptable max)
- **P99:** 99% processed faster (tail latency)
- **Max:** Worst case latency

## Railway Infrastructure Requirements

### Services

1. **Outpost API** (3 instances)
   - CPU: 4 vCPU
   - Memory: 4GB RAM
   - Horizontal scaling enabled

2. **Outpost Delivery Service** (5 instances)
   - CPU: 4 vCPU
   - Memory: 4GB RAM
   - `DELIVERY_MAX_CONCURRENCY=100`

3. **Outpost Log Service** (2 instances)
   - CPU: 2 vCPU
   - Memory: 2GB RAM
   - `LOG_MAX_CONCURRENCY=50`

4. **PostgreSQL**
   - Railway Postgres plugin
   - Plan: Pro ($25/mo for benchmark duration)

5. **Redis**
   - Railway Redis plugin
   - Plan: Pro ($10/mo for benchmark duration)

6. **RabbitMQ**
   - Railway RabbitMQ template
   - Instance: 4GB RAM, 2 vCPU

7. **Mock Webhook Server** (for 100 webhook destinations)
   - Custom service that accepts webhooks
   - Records `received_at` timestamp
   - Stores results in Redis
   - Returns 200 OK

8. **Load Test Runner** (k6)
   - The k6 service we already created
   - Configured with 10 publishers scenario

### Environment Variables

**Outpost Services:**
```bash
# Topics
TOPICS=benchmark.event

# Concurrency
PUBLISH_MAX_CONCURRENCY=200
DELIVERY_MAX_CONCURRENCY=100
LOG_MAX_CONCURRENCY=50

# Retry config (disable for benchmark)
RETRY_INTERVAL_SECONDS=0
MAX_RETRY_LIMIT=0

# Internal URLs
POSTGRES_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
MQ_RABBITMQ_URL=${{RabbitMQ.RABBITMQ_URL}}
```

## Test Execution Plan

### Phase 1: Setup (10 minutes)

1. Deploy all Railway services
2. Create 100 webhook destinations pointing to mock server
3. Create 10 RabbitMQ destinations
4. Verify all destinations are healthy

### Phase 2: Warm-up (30 seconds)

1. Send 100 events/sec for 30 seconds
2. Verify delivery pipeline is working
3. Check metrics are being collected

### Phase 3: Benchmark Run (100 seconds)

1. Start 10 k6 publishers
2. Each publishes 100 events/sec
3. Total: 1,000 events/sec sustained
4. Monitor resource utilization
5. Collect all timestamps

### Phase 4: Cool-down (60 seconds)

1. Wait for all deliveries to complete
2. Verify event counts match
3. Export metrics from Redis/Postgres

### Phase 5: Analysis (manual)

1. Calculate throughput
2. Calculate latency percentiles (P50, P95, P99)
3. Identify bottlenecks
4. Document Railway costs

## Expected Deliverables

### 1. Throughput Report
```
Total Events Published: 100,000
Total Events Delivered: 11,000,000 (100k × 110 destinations)
Duration: 100 seconds
Throughput: 1,000 events/sec (ingest)
Fanout Throughput: 110,000 deliveries/sec (output)
```

### 2. Latency Report (Outpost Internal: t3 - t2)
```
P50 (Median): ___ms
P95: ___ms
P99: ___ms
Max: ___ms
Mean: ___ms
```

### 3. End-to-End Latency (t4 - t1)
```
P50: ___ms
P95: ___ms
P99: ___ms
```

### 4. Resource Utilization
- API Service CPU/Memory
- Delivery Service CPU/Memory
- Database connections
- Redis memory usage
- RabbitMQ queue depth

### 5. Railway Cost Report
```
Service Costs (per month, prorated for test duration):
- Outpost API (3×): $___
- Outpost Delivery (5×): $___
- Outpost Log (2×): $___
- Postgres Pro: $___
- Redis Pro: $___
- RabbitMQ: $___
- Mock Webhook: $___
- k6 Runner: $___

Total for 2-hour test: $___
Estimated monthly cost at this scale: $___
```

## Test Configuration Files

### k6 Scenario: 100k-benchmark.json
```json
{
  "options": {
    "scenarios": {
      "publishers": {
        "executor": "constant-arrival-rate",
        "rate": 1000,
        "timeUnit": "1s",
        "duration": "100s",
        "preAllocatedVUs": 100,
        "maxVUs": 200
      }
    },
    "thresholds": {
      "http_req_duration": ["p(95)<500", "p(99)<1000"],
      "http_req_failed": ["rate<0.01"]
    }
  }
}
```

### Setup Script: setup-benchmark.sh
```bash
#!/bin/bash
# Creates 100 webhook + 10 RabbitMQ destinations
# To be implemented
```

### Verification Script: verify-benchmark.sh
```bash
#!/bin/bash
# Verifies all 11M deliveries completed
# Calculates latency metrics
# Exports CSV report
# To be implemented
```

## Success Criteria

✅ **Throughput:** Successfully ingest 1,000 events/sec
✅ **Fanout:** Successfully deliver to 110 destinations per event
✅ **Latency P95 < 100ms:** 95% of events processed in under 100ms
✅ **Latency P99 < 500ms:** 99% under 500ms
✅ **No Data Loss:** 100,000 events in = 11,000,000 deliveries out
✅ **Cost Documented:** Clear cost breakdown for this scale

## Next Steps

1. **Create mock webhook server** with timestamp recording
2. **Implement timestamp tracking** in Outpost (t2, t3)
3. **Create 100k-benchmark scenario** for k6
4. **Create setup/verification scripts**
5. **Document Railway deployment steps**
6. **Run benchmark and collect data**
7. **Analyze results and create report**

## Notes

- RabbitMQ destinations avoid connection reuse by targeting different queues
- Webhook destinations use different mock server paths or unique URLs
- Timestamps should be in microsecond precision for accurate latency measurement
- All times should be UTC to avoid timezone issues
- Consider using Railway's built-in metrics for resource monitoring