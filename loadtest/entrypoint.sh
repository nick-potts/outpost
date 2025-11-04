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
  "redis": ""
}
EOF

echo "Created railway config with OUTPOST_URL: ${OUTPOST_URL}"
cat /loadtest/config/environments/railway.json

# Generate TESTID if not set
TESTID=${TESTID:-$(date +%s)}
echo "Running test with TESTID: ${TESTID}"

# Run k6 test
exec k6 run \
  -e ENVIRONMENT=${ENVIRONMENT} \
  -e SCENARIO=${SCENARIO} \
  -e API_KEY=${API_KEY} \
  -e TESTID=${TESTID} \
  /loadtest/src/tests/events-throughput.ts