FROM grafana/k6:latest

USER root

# Copy loadtest files
WORKDIR /loadtest
COPY package*.json ./
COPY tsconfig.json ./
COPY src/ ./src/
COPY config/ ./config/
COPY run-test.sh ./

# Make run script executable
RUN chmod +x run-test.sh

# Set default environment variables (can be overridden in Railway)
ENV ENVIRONMENT=railway
ENV SCENARIO=basic
ENV TESTID=0

# Default command - creates railway config at runtime with OUTPOST_URL
ENTRYPOINT ["sh", "-c"]
CMD ["cat > /loadtest/config/environments/railway.json <<EOF\n\
{\n\
  \"name\": \"railway\",\n\
  \"api\": {\n\
    \"baseUrl\": \"${OUTPOST_URL}\",\n\
    \"timeout\": \"30s\"\n\
  },\n\
  \"mockWebhook\": {\n\
    \"url\": \"https://httpbin.org/post\",\n\
    \"destinationUrl\": \"https://httpbin.org/post\",\n\
    \"verificationPollTimeout\": \"5s\"\n\
  },\n\
  \"redis\": \"\"\n\
}\n\
EOF\n\
&& TESTID=${TESTID:-$(date +%s)} k6 run -e ENVIRONMENT=${ENVIRONMENT} -e SCENARIO=${SCENARIO} -e API_KEY=${API_KEY} -e TESTID=${TESTID} /loadtest/src/tests/events-throughput.ts"]