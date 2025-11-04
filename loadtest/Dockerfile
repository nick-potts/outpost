FROM grafana/k6:latest

USER root

# Install curl for API calls in entrypoint
RUN apk add --no-cache curl

# Copy loadtest files
WORKDIR /loadtest
COPY package*.json ./
COPY tsconfig.json ./
COPY src/ ./src/
COPY config/ ./config/
COPY run-test.sh ./
COPY entrypoint.sh ./

# Make scripts executable
RUN chmod +x run-test.sh entrypoint.sh

# Set default environment variables (can be overridden in Railway)
ENV ENVIRONMENT=railway
ENV SCENARIO=basic
ENV TESTID=0

# Use entrypoint script
ENTRYPOINT ["/loadtest/entrypoint.sh"]