#!/bin/sh
set -e

# Setup script for 100k benchmark
# Creates 100 webhook destinations + 10 RabbitMQ destinations

OUTPOST_URL="${OUTPOST_URL:-http://localhost:3333}"
API_KEY="${API_KEY}"
TENANT_ID="${TENANT_ID:-benchmark-tenant}"
MOCK_WEBHOOK_URL="${MOCK_WEBHOOK_URL:-https://httpbin.org/post}"
RABBITMQ_URL="${RABBITMQ_PRIVATE_URL:-${RABBITMQ_URL}}"

if [ -z "$API_KEY" ]; then
  echo "Error: API_KEY environment variable is required"
  exit 1
fi

echo "Setting up 100k benchmark..."
echo "Outpost URL: $OUTPOST_URL"
echo "Tenant ID: $TENANT_ID"
echo ""

# Create tenant
echo "Creating tenant: $TENANT_ID"
curl -X PUT "$OUTPOST_URL/api/v1/$TENANT_ID" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{}' \
  -s -o /dev/null -w "HTTP %{http_code}\n"

echo ""
echo "Creating 100 webhook destinations..."

# Create 100 webhook destinations
i=1
while [ $i -le 100 ]; do
  printf "  Creating webhook destination %d/100...\r" $i

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
  if [ $(($i % 10)) -eq 0 ]; then
    sleep 1
  fi

  i=$((i + 1))
done

echo ""
echo ""
echo "Creating 10 RabbitMQ destinations..."

# Create 10 RabbitMQ destinations (if RabbitMQ is available)
if [ -n "$RABBITMQ_URL" ]; then
  i=1
  while [ $i -le 10 ]; do
    echo "  Creating RabbitMQ destination $i/10..."

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
          \"username\": \"guest\",
          \"password\": \"guest\"
        }
      }" \
      -s -o /dev/null

    sleep 1
    i=$((i + 1))
  done
else
  echo "  RABBITMQ_PRIVATE_URL or RABBITMQ_URL not set, skipping RabbitMQ destinations"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Ready to run benchmark with:"
echo "  TENANT_ID=$TENANT_ID SCENARIO=100k-benchmark ./run-test.sh events-throughput --environment railway"