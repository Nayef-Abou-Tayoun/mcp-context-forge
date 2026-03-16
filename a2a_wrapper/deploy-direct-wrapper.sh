#!/bin/bash
set -e

# Configuration
PROJECT_NAME="ce-itz-wxo-69b79145ff7b2fa48ecc8f"
REGION="us-south"
RESOURCE_GROUP="itz-wxo-69b79145ff7b2fa48ecc8f"
APP_NAME="a2a-direct-wrapper"
IMAGE_NAME="a2a-direct-wrapper"
REGISTRY="us.icr.io"

# watsonx.ai configuration
WATSONX_DEPLOYMENT_URL="https://us-south.ml.cloud.ibm.com/ml/v4/deployments/54a97f4d-1746-4ae7-ae38-70b03080bfc6/ai_service_stream?version=2021-05-01"
WATSONX_IAM_TOKEN="${WATSONX_IAM_TOKEN:-}"

if [ -z "$WATSONX_IAM_TOKEN" ]; then
    echo "Error: WATSONX_IAM_TOKEN environment variable not set"
    echo "Please set it with: export WATSONX_IAM_TOKEN='your-token-here'"
    exit 1
fi

echo "=== Deploying Direct watsonx.ai A2A Wrapper to IBM Code Engine ==="
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo "App Name: $APP_NAME"
echo ""

# Login to IBM Cloud
echo "Step 1: Logging in to IBM Cloud..."
ibmcloud login --apikey "${IBM_CLOUD_API_KEY}" -r "$REGION" -g "$RESOURCE_GROUP"

# Target Code Engine project
echo "Step 2: Targeting Code Engine project..."
ibmcloud ce project select --name "$PROJECT_NAME"

# Build and push Docker image
echo "Step 3: Building Docker image..."
docker build -f Dockerfile.direct -t "$IMAGE_NAME:latest" .

echo "Step 4: Tagging image for IBM Container Registry..."
docker tag "$IMAGE_NAME:latest" "$REGISTRY/$PROJECT_NAME/$IMAGE_NAME:latest"

echo "Step 5: Logging in to IBM Container Registry..."
ibmcloud cr login

echo "Step 6: Pushing image to registry..."
docker push "$REGISTRY/$PROJECT_NAME/$IMAGE_NAME:latest"

# Deploy or update Code Engine application
echo "Step 7: Deploying to Code Engine..."
if ibmcloud ce app get --name "$APP_NAME" &>/dev/null; then
    echo "Updating existing application..."
    ibmcloud ce app update --name "$APP_NAME" \
        --image "$REGISTRY/$PROJECT_NAME/$IMAGE_NAME:latest" \
        --env WATSONX_DEPLOYMENT_URL="$WATSONX_DEPLOYMENT_URL" \
        --env WATSONX_IAM_TOKEN="$WATSONX_IAM_TOKEN" \
        --port 8080 \
        --min-scale 1 \
        --max-scale 5 \
        --cpu 0.5 \
        --memory 1G \
        --request-timeout 300
else
    echo "Creating new application..."
    ibmcloud ce app create --name "$APP_NAME" \
        --image "$REGISTRY/$PROJECT_NAME/$IMAGE_NAME:latest" \
        --env WATSONX_DEPLOYMENT_URL="$WATSONX_DEPLOYMENT_URL" \
        --env WATSONX_IAM_TOKEN="$WATSONX_IAM_TOKEN" \
        --port 8080 \
        --min-scale 1 \
        --max-scale 5 \
        --cpu 0.5 \
        --memory 1G \
        --request-timeout 300
fi

# Get application URL
echo ""
echo "Step 8: Getting application URL..."
APP_URL=$(ibmcloud ce app get --name "$APP_NAME" --output json | jq -r '.status.url')

echo ""
echo "=== Deployment Complete! ==="
echo "Application URL: $APP_URL"
echo ""
echo "Test the wrapper:"
echo "  curl $APP_URL/health"
echo ""
echo "Get capabilities:"
echo "  curl $APP_URL/a2a/watsonx-agent"
echo ""
echo "Send a message:"
echo "  curl -X POST $APP_URL/a2a/watsonx-agent/message \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": {\"role\": \"user\", \"parts\": [{\"kind\": \"text\", \"text\": \"Hello\"}]}}'"
echo ""
echo "Use this URL in watsonx Orchestrate:"
echo "  $APP_URL/a2a/watsonx-agent"

# Made with Bob
