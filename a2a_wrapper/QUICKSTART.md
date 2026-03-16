# Quick Start: watsonx Orchestrate Integration

This guide will help you quickly set up watsonx Orchestrate to integrate with a watsonx.ai agent through ContextForge.

## Your Configuration

```bash
CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
CONTEXTFORGE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJuYXllZi5hYm91LnRheW91bkBpYm0uY29tIiwianRpIjoiNGE0YzBkMDgtNWQ5OC00YmQ5LTgxYjAtMTdlNWRkOGZlZDU1IiwidG9rZW5fdXNlIjoiYXBpIiwiaWF0IjoxNzczNjE4OTU4LCJpc3MiOiJtY3BnYXRld2F5IiwiYXVkIjoibWNwZ2F0ZXdheS1hcGkiLCJ1c2VyIjp7ImVtYWlsIjoibmF5ZWYuYWJvdS50YXlvdW5AaWJtLmNvbSIsImZ1bGxfbmFtZSI6IkFQSSBUb2tlbiBVc2VyIiwiaXNfYWRtaW4iOnRydWUsImF1dGhfcHJvdmlkZXIiOiJhcGlfdG9rZW4ifSwidGVhbXMiOltdLCJzY29wZXMiOnsic2VydmVyX2lkIjpudWxsLCJwZXJtaXNzaW9ucyI6W10sImlwX3Jlc3RyaWN0aW9ucyI6W10sInRpbWVfcmVzdHJpY3Rpb25zIjp7fX0sImV4cCI6MTc3NjIxMDk1OH0.SUaf1MgMxb95kd7F69g7wgUNwl5-H7y3KOX0mUEkll8"
```

**Token expires**: 2026-02-12

## Prerequisites

You need:
1. ✅ ContextForge instance (you have this)
2. ✅ ContextForge JWT token (you have this)
3. ⚠️ watsonx.ai agent URL and API key (you need to provide these)
4. ⚠️ IBM Cloud account with Code Engine access
5. ⚠️ watsonx Orchestrate access

## Step 1: Register Your watsonx.ai Agent in ContextForge

First, you need to provide your watsonx.ai agent details:

```bash
# Set your credentials
export CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
export CONTEXTFORGE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJuYXllZi5hYm91LnRheW91bkBpYm0uY29tIiwianRpIjoiNGE0YzBkMDgtNWQ5OC00YmQ5LTgxYjAtMTdlNWRkOGZlZDU1IiwidG9rZW5fdXNlIjoiYXBpIiwiaWF0IjoxNzczNjE4OTU4LCJpc3MiOiJtY3BnYXRld2F5IiwiYXVkIjoibWNwZ2F0ZXdheS1hcGkiLCJ1c2VyIjp7ImVtYWlsIjoibmF5ZWYuYWJvdS50YXlvdW5AaWJtLmNvbSIsImZ1bGxfbmFtZSI6IkFQSSBUb2tlbiBVc2VyIiwiaXNfYWRtaW4iOnRydWUsImF1dGhfcHJvdmlkZXIiOiJhcGlfdG9rZW4ifSwidGVhbXMiOltdLCJzY29wZXMiOnsic2VydmVyX2lkIjpudWxsLCJwZXJtaXNzaW9ucyI6W10sImlwX3Jlc3RyaWN0aW9ucyI6W10sInRpbWVfcmVzdHJpY3Rpb25zIjp7fX0sImV4cCI6MTc3NjIxMDk1OH0.SUaf1MgMxb95kd7F69g7wgUNwl5-H7y3KOX0mUEkll8"

# TODO: Set your watsonx.ai credentials
export WATSONX_API_KEY="YOUR_WATSONX_API_KEY"
export WATSONX_PROJECT_ID="YOUR_WATSONX_PROJECT_ID"
export WATSONX_DEPLOYMENT_ID="YOUR_DEPLOYMENT_ID"
```

Register the agent in ContextForge:

```bash
curl -X POST "$CONTEXTFORGE_URL/a2a/agents" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN" \
  -d '{
    "name": "watsonx-agent",
    "description": "watsonx.ai agent for Orchestrate integration",
    "endpoint_url": "https://us-south.ml.cloud.ibm.com/ml/v1/deployments/'$WATSONX_DEPLOYMENT_ID'/generation/text",
    "auth_type": "bearer",
    "auth_value": "'$WATSONX_API_KEY'",
    "team_id": null,
    "metadata": {
      "backend": "watsonx.ai",
      "project_id": "'$WATSONX_PROJECT_ID'"
    }
  }'
```

Verify registration:

```bash
curl "$CONTEXTFORGE_URL/a2a/agents" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN"
```

## Step 2: Deploy A2A Wrapper to Code Engine

The wrapper translates between watsonx Orchestrate's A2A 0.2.1 protocol and ContextForge's format.

### Option A: Automated Deployment (Recommended)

```bash
cd a2a_wrapper

# Set required environment variables
export CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
export CONTEXTFORGE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJuYXllZi5hYm91LnRheW91bkBpYm0uY29tIiwianRpIjoiNGE0YzBkMDgtNWQ5OC00YmQ5LTgxYjAtMTdlNWRkOGZlZDU1IiwidG9rZW5fdXNlIjoiYXBpIiwiaWF0IjoxNzczNjE4OTU4LCJpc3MiOiJtY3BnYXRld2F5IiwiYXVkIjoibWNwZ2F0ZXdheS1hcGkiLCJ1c2VyIjp7ImVtYWlsIjoibmF5ZWYuYWJvdS50YXlvdW5AaWJtLmNvbSIsImZ1bGxfbmFtZSI6IkFQSSBUb2tlbiBVc2VyIiwiaXNfYWRtaW4iOnRydWUsImF1dGhfcHJvdmlkZXIiOiJhcGlfdG9rZW4ifSwidGVhbXMiOltdLCJzY29wZXMiOnsic2VydmVyX2lkIjpudWxsLCJwZXJtaXNzaW9ucyI6W10sImlwX3Jlc3RyaWN0aW9ucyI6W10sInRpbWVfcmVzdHJpY3Rpb25zIjp7fX0sImV4cCI6MTc3NjIxMDk1OH0.SUaf1MgMxb95kd7F69g7wgUNwl5-H7y3KOX0mUEkll8"
export IBM_CR_NAMESPACE="your-namespace"  # TODO: Set your IBM Container Registry namespace

# Login to IBM Cloud
ibmcloud login --sso

# Make script executable and run
chmod +x deploy-to-code-engine.sh
./deploy-to-code-engine.sh
```

The script will output your wrapper URL. Save it for Step 3.

### Option B: Manual Deployment

```bash
cd a2a_wrapper

# Login to IBM Cloud
ibmcloud login --sso
ibmcloud cr login

# Build and push image
docker build -t us.icr.io/YOUR_NAMESPACE/contextforge-a2a-wrapper:latest .
docker push us.icr.io/YOUR_NAMESPACE/contextforge-a2a-wrapper:latest

# Deploy to Code Engine
ibmcloud ce project create --name contextforge-wrapper
ibmcloud ce application create \
  --name contextforge-a2a-wrapper \
  --image us.icr.io/YOUR_NAMESPACE/contextforge-a2a-wrapper:latest \
  --port 5000 \
  --env CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud" \
  --env CONTEXTFORGE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJuYXllZi5hYm91LnRheW91bkBpYm0uY29tIiwianRpIjoiNGE0YzBkMDgtNWQ5OC00YmQ5LTgxYjAtMTdlNWRkOGZlZDU1IiwidG9rZW5fdXNlIjoiYXBpIiwiaWF0IjoxNzczNjE4OTU4LCJpc3MiOiJtY3BnYXRld2F5IiwiYXVkIjoibWNwZ2F0ZXdheS1hcGkiLCJ1c2VyIjp7ImVtYWlsIjoibmF5ZWYuYWJvdS50YXlvdW5AaWJtLmNvbSIsImZ1bGxfbmFtZSI6IkFQSSBUb2tlbiBVc2VyIiwiaXNfYWRtaW4iOnRydWUsImF1dGhfcHJvdmlkZXIiOiJhcGlfdG9rZW4ifSwidGVhbXMiOltdLCJzY29wZXMiOnsic2VydmVyX2lkIjpudWxsLCJwZXJtaXNzaW9ucyI6W10sImlwX3Jlc3RyaWN0aW9ucyI6W10sInRpbWVfcmVzdHJpY3Rpb25zIjp7fX0sImV4cCI6MTc3NjIxMDk1OH0.SUaf1MgMxb95kd7F69g7wgUNwl5-H7y3KOX0mUEkll8" \
  --min-scale 1 \
  --max-scale 5 \
  --cpu 0.5 \
  --memory 1G

# Get wrapper URL
ibmcloud ce application get --name contextforge-a2a-wrapper
```

## Step 3: Test the Wrapper

Replace `WRAPPER_URL` with your actual wrapper URL from Step 2:

```bash
export WRAPPER_URL="https://contextforge-a2a-wrapper.abc123xyz.us-south.codeengine.appdomain.cloud"

# Test health
curl "$WRAPPER_URL/health"

# Test A2A capabilities
curl "$WRAPPER_URL/a2a/watsonx-agent"

# Test message forwarding
curl -X POST "$WRAPPER_URL/a2a/watsonx-agent/message" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hello, what can you help me with?"}]
    }
  }'
```

## Step 4: Configure watsonx Orchestrate

1. **Login to watsonx Orchestrate**
   - Go to your watsonx Orchestrate instance

2. **Import Agent**
   - Navigate to **Skills** → **Import**
   - Select **External agent via A2A standard**

3. **Enter Agent Details**
   - **Name**: watsonx Agent via ContextForge
   - **URL**: `https://your-wrapper-url.codeengine.appdomain.cloud/a2a/watsonx-agent`
   - **Authentication**: None (wrapper handles auth internally)

4. **Test in Orchestrate**
   - Go to **Chat**
   - Send a test message
   - Verify response from your watsonx.ai agent

## Architecture Flow

```
┌─────────────────────┐
│ watsonx Orchestrate │
│   (A2A 0.2.1)       │
└──────────┬──────────┘
           │
           │ POST /a2a/watsonx-agent/message
           │ {"message": {"role": "user", ...}}
           ↓
┌─────────────────────┐
│   A2A Wrapper       │
│  (Code Engine)      │
│  - Protocol Trans   │
│  - Auth Proxy       │
└──────────┬──────────┘
           │
           │ POST /a2a/watsonx-agent/message
           │ Authorization: Bearer <token>
           ↓
┌─────────────────────┐
│   ContextForge      │
│  - Route to agent   │
│  - Add watsonx auth │
└──────────┬──────────┘
           │
           │ POST /ml/v1/deployments/.../generation/text
           │ Authorization: Bearer <watsonx-key>
           ↓
┌─────────────────────┐
│   watsonx.ai        │
│   Agent/Model       │
└─────────────────────┘
```

## Troubleshooting

### Wrapper Health Check Fails

```bash
# Check wrapper logs
ibmcloud ce application logs --name contextforge-a2a-wrapper --follow

# Verify environment variables
ibmcloud ce application get --name contextforge-a2a-wrapper
```

### ContextForge Returns 404

```bash
# Verify agent is registered
curl "$CONTEXTFORGE_URL/a2a/agents" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN"

# Check agent name matches
curl "$CONTEXTFORGE_URL/a2a/watsonx-agent/message" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": {"role": "user", "parts": [{"kind": "text", "text": "test"}]}}'
```

### watsonx.ai Returns 401

Update agent credentials in ContextForge:

```bash
curl -X PATCH "$CONTEXTFORGE_URL/a2a/agents/watsonx-agent" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN" \
  -d '{
    "auth_value": "NEW_WATSONX_API_KEY"
  }'
```

## Next Steps

- ✅ Add more watsonx.ai agents
- ✅ Monitor usage in ContextForge admin UI
- ✅ Set up alerts for failures
- ✅ Configure rate limiting if needed

## Support

- **ContextForge**: Check admin UI at `$CONTEXTFORGE_URL/admin`
- **Wrapper**: Check Code Engine logs
- **watsonx.ai**: Verify deployment status in watsonx.ai console
- **Orchestrate**: Contact IBM support

## Important Notes

- Your ContextForge token expires on **2026-02-12**
- Generate a new token before expiration using ContextForge admin UI
- Update wrapper environment variable when token changes:
  ```bash
  ibmcloud ce application update \
    --name contextforge-a2a-wrapper \
    --env CONTEXTFORGE_TOKEN="new-token"