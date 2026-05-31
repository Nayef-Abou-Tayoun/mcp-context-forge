#!/bin/bash
# Deploy tt_pii_filter plugin to IBM Code Engine
# This script updates the plugin configuration and restarts the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME=${APP_NAME:-context-forge-0}
CONFIGMAP_NAME=${CONFIGMAP_NAME:-plugin-config}

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Deploying tt_pii_filter Plugin${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if logged in
echo -e "${YELLOW}Step 1: Checking IBM Cloud login status...${NC}"
if ! ibmcloud target &> /dev/null; then
    echo -e "${RED}Error: Not logged into IBM Cloud${NC}"
    echo -e "${YELLOW}Please run one of the following:${NC}"
    echo "  ibmcloud login --sso"
    echo "  ibmcloud login --apikey YOUR_API_KEY"
    exit 1
fi
echo -e "${GREEN}✓ Logged in to IBM Cloud${NC}"
echo ""

# Check Code Engine project
echo -e "${YELLOW}Step 2: Checking Code Engine project...${NC}"
if ! ibmcloud ce project current &> /dev/null; then
    echo -e "${RED}Error: No Code Engine project selected${NC}"
    echo -e "${YELLOW}Please select a project:${NC}"
    echo "  ibmcloud ce project list"
    echo "  ibmcloud ce project select --name YOUR_PROJECT_NAME"
    exit 1
fi
PROJECT=$(ibmcloud ce project current --output json 2>/dev/null | grep -o '"name":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Using Code Engine project: ${PROJECT}${NC}"
echo ""

# Check if application exists
echo -e "${YELLOW}Step 3: Checking if application exists...${NC}"
if ! ibmcloud ce app get --name ${APP_NAME} &> /dev/null; then
    echo -e "${RED}Error: Application '${APP_NAME}' not found${NC}"
    echo -e "${YELLOW}Available applications:${NC}"
    ibmcloud ce app list
    exit 1
fi
echo -e "${GREEN}✓ Application '${APP_NAME}' found${NC}"
echo ""

# Update ConfigMap
echo -e "${YELLOW}Step 4: Updating plugin configuration ConfigMap...${NC}"
if ibmcloud ce configmap get --name ${CONFIGMAP_NAME} &> /dev/null; then
    echo "  Updating existing ConfigMap..."
    ibmcloud ce configmap update --name ${CONFIGMAP_NAME} \
        --from-file plugins/config.yaml
    echo -e "${GREEN}✓ ConfigMap updated${NC}"
else
    echo "  Creating new ConfigMap..."
    ibmcloud ce configmap create --name ${CONFIGMAP_NAME} \
        --from-file plugins/config.yaml
    echo -e "${GREEN}✓ ConfigMap created${NC}"
fi
echo ""

# Optional: Create ConfigMap for tt_pii_filter plugin files
echo -e "${YELLOW}Step 5: Creating ConfigMap for tt_pii_filter plugin files...${NC}"
TT_PII_CONFIGMAP="tt-pii-filter"
if ibmcloud ce configmap get --name ${TT_PII_CONFIGMAP} &> /dev/null; then
    echo "  Updating existing tt_pii_filter ConfigMap..."
    ibmcloud ce configmap update --name ${TT_PII_CONFIGMAP} \
        --from-file plugins/tt_pii_filter/__init__.py \
        --from-file plugins/tt_pii_filter/tt_pii_filter.py \
        --from-file plugins/tt_pii_filter/tt_pii_filter_rust.py \
        --from-file plugins/tt_pii_filter/plugin-manifest.yaml \
        --from-file plugins/tt_pii_filter/README.md
    echo -e "${GREEN}✓ tt_pii_filter ConfigMap updated${NC}"
else
    echo "  Creating new tt_pii_filter ConfigMap..."
    ibmcloud ce configmap create --name ${TT_PII_CONFIGMAP} \
        --from-file plugins/tt_pii_filter/__init__.py \
        --from-file plugins/tt_pii_filter/tt_pii_filter.py \
        --from-file plugins/tt_pii_filter/tt_pii_filter_rust.py \
        --from-file plugins/tt_pii_filter/plugin-manifest.yaml \
        --from-file plugins/tt_pii_filter/README.md
    echo -e "${GREEN}✓ tt_pii_filter ConfigMap created${NC}"
fi
echo ""

# Restart application
echo -e "${YELLOW}Step 6: Restarting application to load new plugin...${NC}"
ibmcloud ce app update --name ${APP_NAME} --force
echo -e "${GREEN}✓ Application restart initiated${NC}"
echo ""

# Wait for application to be ready
echo -e "${YELLOW}Step 7: Waiting for application to be ready...${NC}"
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(ibmcloud ce app get --name ${APP_NAME} --output json 2>/dev/null | grep -o '"status":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    if [ "$STATUS" = "Ready" ]; then
        echo -e "${GREEN}✓ Application is ready${NC}"
        break
    fi
    echo "  Waiting... ($ELAPSED/$MAX_WAIT seconds)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}⚠️  Timeout waiting for application${NC}"
    echo "Check logs with: ibmcloud ce app logs --name ${APP_NAME}"
fi
echo ""

# Get application URL
echo -e "${YELLOW}Step 8: Getting application URL...${NC}"
APP_URL=$(ibmcloud ce app get --name ${APP_NAME} --output json 2>/dev/null | grep -o '"url":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Application URL: ${APP_URL}${NC}"
echo ""

# Show recent logs
echo -e "${YELLOW}Step 9: Showing recent logs (looking for tt_pii_filter)...${NC}"
ibmcloud ce app logs --name ${APP_NAME} --tail 50 | grep -i "pii\|plugin" || echo "  (No plugin-related logs in last 50 lines)"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the plugin with a request containing TT Type: s373-2312-r543"
echo "2. View live logs: ibmcloud ce app logs --name ${APP_NAME} --follow"
echo "3. Check application: ${APP_URL}"
echo ""
echo -e "${YELLOW}The tt_pii_filter plugin will now detect and mask:${NC}"
echo "  - Format: s373-2312-r543 (letter+3digits-4digits-letter+3digits)"
echo "  - Masked as: ****-****-r543"

# Made with Bob
