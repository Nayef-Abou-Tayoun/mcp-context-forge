#!/bin/bash
set -e

# Configuration
APP_NAME="contextforge-a2a-wrapper"
IMAGE_NAME="contextforge-a2a-wrapper"
REGISTRY="us.icr.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ContextForge A2A Wrapper Deployment to IBM Code Engine ===${NC}"

# Check if required environment variables are set
if [ -z "$CONTEXTFORGE_URL" ]; then
    echo -e "${RED}Error: CONTEXTFORGE_URL environment variable is not set${NC}"
    echo "Example: export CONTEXTFORGE_URL='https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud'"
    exit 1
fi

if [ -z "$CONTEXTFORGE_TOKEN" ]; then
    echo -e "${RED}Error: CONTEXTFORGE_TOKEN environment variable is not set${NC}"
    echo "Example: export CONTEXTFORGE_TOKEN='your-jwt-token'"
    exit 1
fi

if [ -z "$IBM_CR_NAMESPACE" ]; then
    echo -e "${RED}Error: IBM_CR_NAMESPACE environment variable is not set${NC}"
    echo "Example: export IBM_CR_NAMESPACE='your-namespace'"
    exit 1
fi

# Check if logged into IBM Cloud
echo -e "${YELLOW}Checking IBM Cloud login...${NC}"
if ! ibmcloud target &> /dev/null; then
    echo -e "${RED}Not logged into IBM Cloud. Please run: ibmcloud login --sso${NC}"
    exit 1
fi

# Login to IBM Container Registry
echo -e "${YELLOW}Logging into IBM Container Registry...${NC}"
ibmcloud cr login

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ${REGISTRY}/${IBM_CR_NAMESPACE}/${IMAGE_NAME}:latest .

# Push to registry
echo -e "${YELLOW}Pushing image to registry...${NC}"
docker push ${REGISTRY}/${IBM_CR_NAMESPACE}/${IMAGE_NAME}:latest

# Check if Code Engine project exists, create if not
echo -e "${YELLOW}Checking Code Engine project...${NC}"
if ! ibmcloud ce project current &> /dev/null; then
    echo -e "${YELLOW}No Code Engine project selected. Creating new project...${NC}"
    read -p "Enter project name (default: contextforge-wrapper): " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-contextforge-wrapper}
    ibmcloud ce project create --name ${PROJECT_NAME}
fi

# Check if application exists
echo -e "${YELLOW}Checking if application exists...${NC}"
if ibmcloud ce application get --name ${APP_NAME} &> /dev/null; then
    echo -e "${YELLOW}Application exists. Updating...${NC}"
    ibmcloud ce application update \
        --name ${APP_NAME} \
        --image ${REGISTRY}/${IBM_CR_NAMESPACE}/${IMAGE_NAME}:latest \
        --env CONTEXTFORGE_URL="${CONTEXTFORGE_URL}" \
        --env CONTEXTFORGE_TOKEN="${CONTEXTFORGE_TOKEN}"
else
    echo -e "${YELLOW}Creating new application...${NC}"
    ibmcloud ce application create \
        --name ${APP_NAME} \
        --image ${REGISTRY}/${IBM_CR_NAMESPACE}/${IMAGE_NAME}:latest \
        --port 5000 \
        --env CONTEXTFORGE_URL="${CONTEXTFORGE_URL}" \
        --env CONTEXTFORGE_TOKEN="${CONTEXTFORGE_TOKEN}" \
        --min-scale 1 \
        --max-scale 5 \
        --cpu 0.5 \
        --memory 1G \
        --registry-secret icr-secret
fi

# Get application URL
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}Getting application URL...${NC}"
APP_URL=$(ibmcloud ce application get --name ${APP_NAME} --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -n "$APP_URL" ]; then
    echo -e "${GREEN}Application URL: ${APP_URL}${NC}"
    echo ""
    echo -e "${YELLOW}Testing health endpoint...${NC}"
    sleep 5  # Wait for app to be ready
    if curl -s "${APP_URL}/health" | grep -q "healthy"; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${RED}✗ Health check failed${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}=== Next Steps ===${NC}"
    echo "1. Test the wrapper:"
    echo "   curl ${APP_URL}/health"
    echo ""
    echo "2. Test A2A capabilities (replace 'watsonx-agent' with your agent name):"
    echo "   curl ${APP_URL}/a2a/watsonx-agent"
    echo ""
    echo "3. Test message forwarding:"
    echo "   curl -X POST ${APP_URL}/a2a/watsonx-agent/message \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"message\": {\"role\": \"user\", \"parts\": [{\"kind\": \"text\", \"text\": \"Hello\"}]}}'"
    echo ""
    echo "4. Use this URL in watsonx Orchestrate:"
    echo "   ${APP_URL}/a2a/watsonx-agent"
else
    echo -e "${RED}Could not retrieve application URL${NC}"
fi

echo ""
echo -e "${GREEN}Deployment script completed!${NC}"

# Made with Bob
