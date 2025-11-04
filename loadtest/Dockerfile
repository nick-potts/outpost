FROM grafana/k6:latest

# Install Node.js for TypeScript compilation (k6 doesn't need it at runtime, but good for development)
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
ENV ENVIRONMENT=local
ENV SCENARIO=basic
ENV TESTID=0

# Default command - run the throughput test
# Override in Railway with: CMD ["run", "/loadtest/src/tests/events-throughput.ts"]
ENTRYPOINT ["sh", "-c"]
CMD ["TESTID=${TESTID:-$(date +%s)} k6 run -e ENVIRONMENT=${ENVIRONMENT} -e SCENARIO=${SCENARIO} -e API_KEY=${API_KEY} -e TESTID=${TESTID} /loadtest/src/tests/events-throughput.ts"]