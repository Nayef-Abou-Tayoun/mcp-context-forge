#!/bin/bash
set -e

# Sync COS to Local and Deploy Script
# This script downloads all files from COS to local directories, then redeploys the application

echo "=== COS to Local Sync and Deploy ==="
echo "This script will:"
echo "  1. Download all files from COS to local directories"
echo "  2. Redeploy the application with updated files"
echo ""

# Configuration
COS_BUCKET="contextforge-plugins"
COS_ENDPOINT="s3.us-south.cloud-object-storage.appdomain.cloud"
LOCAL_PLUGIN_DIR="mcp-context-forge/plugins"
APP_NAME="context-forge-0"

# Step 1: Download config.yaml from COS
echo "Step 1: Downloading config.yaml from COS..."
ibmcloud cos object-get \
    --bucket "$COS_BUCKET" \
    --key "plugins/config.yaml" \
    --output "$LOCAL_PLUGIN_DIR/config.yaml"
echo "✓ Downloaded config.yaml"

# Step 2: Download all plugin files from COS
echo ""
echo "Step 2: Downloading plugin files from COS..."

# List all objects in the plugins/ prefix
PLUGIN_FILES=$(ibmcloud cos objects --bucket "$COS_BUCKET" --prefix "plugins/" --output json | jq -r '.Contents[]?.Key // empty')

if [ -z "$PLUGIN_FILES" ]; then
    echo "WARNING: No plugin files found in COS bucket"
else
    echo "Found $(echo "$PLUGIN_FILES" | wc -l) files in COS"
    
    # Download each file
    while IFS= read -r key; do
        # Skip directory markers
        if [[ "$key" == */ ]]; then
            continue
        fi
        
        # Remove 'plugins/' prefix to get relative path
        relative_path="${key#plugins/}"
        local_path="$LOCAL_PLUGIN_DIR/$relative_path"
        
        # Create directory if needed
        mkdir -p "$(dirname "$local_path")"
        
        # Download file
        echo "  Downloading: $key -> $local_path"
        ibmcloud cos object-get \
            --bucket "$COS_BUCKET" \
            --key "$key" \
            --output "$local_path"
    done <<< "$PLUGIN_FILES"
    
    echo "✓ Downloaded all plugin files"
fi

# Step 3: Verify downloaded files
echo ""
echo "Step 3: Verifying downloaded files..."
if [ -f "$LOCAL_PLUGIN_DIR/config.yaml" ]; then
    echo "✓ config.yaml exists"
else
    echo "ERROR: config.yaml not found"
    exit 1
fi

# Count plugin directories
PLUGIN_COUNT=$(find "$LOCAL_PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "external" ! -name "resources" | wc -l)
echo "✓ Found $PLUGIN_COUNT plugin directories"

# Step 4: Update ConfigMap with synced config
echo ""
echo "Step 4: Updating ConfigMap with synced config..."
if ibmcloud ce configmap get --name plugin-config &>/dev/null; then
    ibmcloud ce configmap update --name plugin-config \
        --from-file "$LOCAL_PLUGIN_DIR/config.yaml"
    echo "✓ ConfigMap updated"
else
    ibmcloud ce configmap create --name plugin-config \
        --from-file "$LOCAL_PLUGIN_DIR/config.yaml"
    echo "✓ ConfigMap created"
fi

# Step 5: Force application restart to pick up changes
echo ""
echo "Step 5: Redeploying application..."
TIMESTAMP=$(date +%s)
ibmcloud ce app update --name "$APP_NAME" \
    --env FORCE_RESTART="$TIMESTAMP" \
    --no-wait

echo "✓ Application update initiated"

# Step 6: Wait for deployment
echo ""
echo "Step 6: Waiting for deployment to complete..."
echo "This may take a few minutes..."

MAX_WAIT=300
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(ibmcloud ce app get --name "$APP_NAME" --output json 2>/dev/null | jq -r '.status.conditions[] | select(.type=="Ready") | .status' || echo "Unknown")
    
    if [ "$STATUS" = "True" ]; then
        echo "✓ Application is ready!"
        break
    fi
    
    echo "  Status: $STATUS (waiting...)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "⚠️  Timeout waiting for application to be ready"
    echo "Check application status with: ibmcloud ce app get --name $APP_NAME"
    exit 1
fi

# Step 7: Get application URL
echo ""
echo "Step 7: Getting application URL..."
APP_URL=$(ibmcloud ce app get --name "$APP_NAME" --output json | jq -r '.status.url')
echo "✓ Application URL: $APP_URL"

echo ""
echo "=== Sync and Deploy Complete ==="
echo ""
echo "Summary:"
echo "  - Downloaded all files from COS to local directories"
echo "  - Updated ConfigMap with latest config"
echo "  - Redeployed application"
echo "  - Application URL: $APP_URL"
echo ""
echo "To view logs:"
echo "  ibmcloud ce app logs --name $APP_NAME --follow"
echo ""

# Made with Bob