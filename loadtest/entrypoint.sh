#!/bin/sh
set -e

# Create railway config with runtime OUTPOST_URL
cat > /loadtest/config/environments/railway.json <<EOF
{
  "name": "railway",
  "api": {
    "baseUrl": "${OUTPOST_URL}",
    "timeout": "30s"
  },
  "mockWebhook": {
    "url": "https://httpbin.org/post",
    "destinationUrl": "https://httpbin.org/post",
    "verificationPollTimeout": "5s"
  },
  "redis": "${REDIS_URL:-redis://localhost:6379}"
}
EOF

echo "Created railway config with OUTPOST_URL: ${OUTPOST_URL}"
cat /loadtest/config/environments/railway.json

# Generate random TESTID to ensure unique tenant each run
TESTID=$(date +%s)-$RANDOM
echo "Running test with TESTID: ${TESTID}"

# If running benchmark scenarios, setup destinations
if [ "$SCENARIO" = "100k-benchmark" ] || [ "$SCENARIO" = "10k-benchmark" ]; then
  echo ""
  echo "=== 100k Benchmark Setup ==="
  TENANT_ID="test-tenant-${TESTID}"
  MOCK_WEBHOOK_URL="${MOCK_WEBHOOK_URL:-https://httpbin.org/post}"
  RABBITMQ_URL="${RABBITMQ_PRIVATE_URL:-${RABBITMQ_URL}}"
  NUM_WEBHOOKS="${NUM_WEBHOOKS:-100}"
  NUM_RABBITMQ="${NUM_RABBITMQ:-10}"

  echo "Creating tenant: $TENANT_ID"

  # Create tenant (idempotent - returns 200 if exists, 201 if created)
  curl -X PUT "$OUTPOST_URL/api/v1/$TENANT_ID" \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{}' \
    -s -o /dev/null -w "Tenant: HTTP %{http_code}\n"

  # Check if destinations already exist
  DEST_COUNT=$(curl -X GET "$OUTPOST_URL/api/v1/$TENANT_ID/destinations" \
    -H "x-api-key: $API_KEY" \
    -s | grep -o '"id"' | wc -l || echo "0")

  DEST_COUNT=$(echo $DEST_COUNT | tr -d ' ')
  EXPECTED_COUNT=$((NUM_WEBHOOKS + NUM_RABBITMQ))

  if [ "$DEST_COUNT" -ge "$EXPECTED_COUNT" ]; then
    echo "Destinations already exist ($DEST_COUNT), skipping setup"
  else
    echo "Creating $NUM_WEBHOOKS webhook destinations..."

    i=1
    while [ $i -le $NUM_WEBHOOKS ]; do
      printf "  Webhook %d/%d\r" $i $NUM_WEBHOOKS

      curl -X POST "$OUTPOST_URL/api/v1/$TENANT_ID/destinations" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"webhook\",
          \"topics\": [\"*\"],
          \"config\": {
            \"url\": \"$MOCK_WEBHOOK_URL/webhook-$i\",
            \"method\": \"POST\"
          }
        }" \
        -s -o /dev/null

      # Rate limit every 10 requests
      if [ $((i % 10)) -eq 0 ]; then
        sleep 0.5
      fi

      i=$((i + 1))
    done

    echo ""

    if [ -n "$RABBITMQ_URL" ]; then
      echo "Creating $NUM_RABBITMQ RabbitMQ destinations..."

      i=1
      while [ $i -le $NUM_RABBITMQ ]; do
        echo "  RabbitMQ $i/$NUM_RABBITMQ"

        curl -X POST "$OUTPOST_URL/api/v1/$TENANT_ID/destinations" \
          -H "x-api-key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d "{
            \"type\": \"rabbitmq\",
            \"topics\": [\"*\"],
            \"config\": {
              \"server_url\": \"$RABBITMQ_URL\",
              \"queue\": \"benchmark-queue-$i\",
              \"exchange\": \"benchmark-exchange\",
              \"routing_key\": \"benchmark.event\"
            },
            \"credentials\": {
              \"username\": \"${RABBITMQ_USER:-guest}\",
              \"password\": \"${RABBITMQ_PASSWORD:-guest}\"
            }
          }" \
          -s -o /dev/null

        sleep 0.5
        i=$((i + 1))
      done
    else
      echo "RABBITMQ_PRIVATE_URL not set, skipping RabbitMQ destinations"
    fi
  fi

  echo ""
  echo "Setup complete! Starting benchmark..."
  echo "=========================="
  echo ""
fi

# Run k6 test
exec k6 run \
  -e ENVIRONMENT=${ENVIRONMENT} \
  -e SCENARIO=${SCENARIO} \
  -e API_KEY=${API_KEY} \
  -e TESTID=${TESTID} \
  /loadtest/src/tests/events-throughput.ts