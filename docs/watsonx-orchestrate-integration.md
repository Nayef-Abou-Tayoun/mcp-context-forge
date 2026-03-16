# Integrating watsonx Orchestrate with watsonx.ai Agents via ContextForge

This guide explains how to expose a watsonx.ai agent through ContextForge's A2A interface so that watsonx Orchestrate can integrate with it.

## Architecture Overview

```
watsonx Orchestrate (A2A 0.2.1)
       ↓
A2A Wrapper (Protocol Translation)
       ↓
ContextForge A2A Endpoint
       ↓
watsonx.ai Agent
```

## Prerequisites

1. **ContextForge instance** deployed and accessible
2. **watsonx.ai agent** URL and credentials
3. **IBM Cloud Code Engine** account (for wrapper deployment)
4. **watsonx Orchestrate** access

## Step 1: Register watsonx.ai Agent in ContextForge

### 1.1 Get Your ContextForge Token

```bash
export CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
export CONTEXTFORGE_TOKEN="your-jwt-token"
```

### 1.2 Register the watsonx.ai Agent as an A2A Agent

Use ContextForge's admin API to register your watsonx.ai agent:

```bash
curl -X POST "$CONTEXTFORGE_URL/a2a/agents" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN" \
  -d '{
    "name": "watsonx-agent",
    "description": "watsonx.ai agent proxied through ContextForge",
    "endpoint_url": "https://us-south.ml.cloud.ibm.com/ml/v1/deployments/YOUR_DEPLOYMENT_ID/generation/text",
    "auth_type": "bearer",
    "auth_value": "YOUR_WATSONX_API_KEY",
    "team_id": null,
    "metadata": {
      "backend": "watsonx.ai",
      "project_id": "YOUR_PROJECT_ID"
    }
  }'
```

**Important fields:**
- `name`: Agent identifier (use in URLs)
- `endpoint_url`: Your watsonx.ai agent endpoint
- `auth_type`: "bearer" for API key authentication
- `auth_value`: Your watsonx.ai API key
- `metadata.project_id`: Your watsonx.ai project ID

### 1.3 Verify Registration

```bash
curl "$CONTEXTFORGE_URL/a2a/agents" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN"
```

You should see your `watsonx-agent` in the list.

## Step 2: Deploy A2A Protocol Wrapper

Since watsonx Orchestrate uses A2A 0.2.1 protocol and ContextForge uses a custom A2A format, you need a translation wrapper.

### 2.1 Create Dockerfile

Create `a2a_wrapper/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY contextforge_wrapper.py .

ENV PORT=5000
ENV PYTHONUNBUFFERED=1

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "--timeout", "120", "contextforge_wrapper:app"]
```

### 2.2 Build and Push to IBM Container Registry

```bash
cd a2a_wrapper

# Login to IBM Cloud
ibmcloud login --sso
ibmcloud cr login

# Build and push
docker build -t us.icr.io/your-namespace/contextforge-a2a-wrapper:latest .
docker push us.icr.io/your-namespace/contextforge-a2a-wrapper:latest
```

### 2.3 Deploy to Code Engine

```bash
# Create Code Engine project (if needed)
ibmcloud ce project create --name contextforge-wrapper

# Deploy application
ibmcloud ce application create \
  --name contextforge-a2a-wrapper \
  --image us.icr.io/your-namespace/contextforge-a2a-wrapper:latest \
  --port 5000 \
  --env CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud" \
  --env CONTEXTFORGE_TOKEN="your-jwt-token" \
  --min-scale 1 \
  --max-scale 5 \
  --cpu 0.5 \
  --memory 1G
```

### 2.4 Get Wrapper URL

```bash
ibmcloud ce application get --name contextforge-a2a-wrapper
```

You'll get a URL like:
```
https://contextforge-a2a-wrapper.abc123xyz.us-south.codeengine.appdomain.cloud
```

Save this as `WRAPPER_URL`.

## Step 3: Test the Integration

### 3.1 Test Wrapper Health

```bash
export WRAPPER_URL="https://contextforge-a2a-wrapper.abc123xyz.us-south.codeengine.appdomain.cloud"

curl "$WRAPPER_URL/health"
```

Expected response:
```json
{
  "status": "healthy",
  "service": "contextforge-a2a-wrapper",
  "contextforge_url": "https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
}
```

### 3.2 Test A2A Capabilities Discovery

```bash
curl "$WRAPPER_URL/a2a/watsonx-agent"
```

Expected response:
```json
{
  "name": "watsonx-agent",
  "description": "Agent: watsonx-agent via ContextForge",
  "version": "0.2.1",
  "capabilities": {
    "message": true,
    "streaming": false
  }
}
```

### 3.3 Test Message Forwarding

```bash
curl -X POST "$WRAPPER_URL/a2a/watsonx-agent/message" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hello, what can you help me with?"}]
    }
  }'
```

You should get a response from your watsonx.ai agent.

## Step 4: Configure watsonx Orchestrate

### 4.1 Import Agent

1. Log into watsonx Orchestrate
2. Navigate to **Skills** → **Import**
3. Select **External agent via A2A standard**
4. Enter agent details:
   - **Name**: watsonx Agent via ContextForge
   - **URL**: `https://contextforge-a2a-wrapper.abc123xyz.us-south.codeengine.appdomain.cloud/a2a/watsonx-agent`
   - **Authentication**: None (wrapper handles ContextForge auth internally)

### 4.2 Test in Orchestrate

1. Go to **Chat** in watsonx Orchestrate
2. Type a message to test your agent
3. Verify the response comes from your watsonx.ai agent

## Architecture Details

### Request Flow

1. **watsonx Orchestrate** sends A2A 0.2.1 message:
   ```json
   {
     "message": {
       "role": "user",
       "parts": [{"kind": "text", "text": "Hello"}]
     }
   }
   ```

2. **A2A Wrapper** receives and forwards to ContextForge:
   ```bash
   POST /a2a/watsonx-agent/message
   Authorization: Bearer <CONTEXTFORGE_TOKEN>
   ```

3. **ContextForge** routes to watsonx.ai agent:
   - Looks up agent configuration
   - Transforms to watsonx.ai format
   - Adds authentication (API key)
   - Forwards to watsonx.ai endpoint

4. **watsonx.ai** processes and responds

5. **Response flows back** through the chain:
   - watsonx.ai → ContextForge → Wrapper → Orchestrate

### Security Considerations

- **ContextForge token** is stored in wrapper environment (not exposed to Orchestrate)
- **watsonx.ai API key** is stored in ContextForge (not exposed to wrapper or Orchestrate)
- **Wrapper** acts as authentication proxy
- **No credentials** are passed through watsonx Orchestrate

## Troubleshooting

### Wrapper Returns 502 Bad Gateway

**Cause**: Cannot reach ContextForge
**Solution**: 
- Verify `CONTEXTFORGE_URL` is correct
- Check network connectivity
- Verify ContextForge is running

### Wrapper Returns 500 Internal Server Error

**Cause**: Invalid ContextForge token
**Solution**:
- Verify `CONTEXTFORGE_TOKEN` is set correctly
- Check token hasn't expired
- Generate new token if needed

### ContextForge Returns 404 Not Found

**Cause**: Agent not registered
**Solution**:
- Verify agent name matches registration
- Check agent exists: `curl $CONTEXTFORGE_URL/a2a/agents -H "Authorization: Bearer $TOKEN"`

### watsonx.ai Returns 401 Unauthorized

**Cause**: Invalid watsonx.ai credentials
**Solution**:
- Update agent registration with correct API key
- Verify API key has access to the deployment

### Orchestrate Cannot Import Agent

**Cause**: URL or protocol mismatch
**Solution**:
- Verify wrapper URL is accessible from Orchestrate
- Check wrapper returns valid A2A 0.2.1 capabilities
- Test wrapper endpoints manually first

## Monitoring

### Check Wrapper Logs

```bash
ibmcloud ce application logs --name contextforge-a2a-wrapper --follow
```

### Check ContextForge Logs

Access ContextForge admin UI or check deployment logs.

### Monitor Request Flow

Enable debug logging in wrapper by setting:
```bash
ibmcloud ce application update --name contextforge-a2a-wrapper --env DEBUG=true
```

## Updating Configuration

### Update watsonx.ai Credentials

```bash
curl -X PATCH "$CONTEXTFORGE_URL/a2a/agents/watsonx-agent" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CONTEXTFORGE_TOKEN" \
  -d '{
    "auth_value": "NEW_API_KEY"
  }'
```

### Update Wrapper Environment

```bash
ibmcloud ce application update \
  --name contextforge-a2a-wrapper \
  --env CONTEXTFORGE_TOKEN="new-token"
```

## Next Steps

- Add multiple watsonx.ai agents
- Enable streaming responses (if supported)
- Add custom authentication for Orchestrate
- Monitor usage and performance
- Set up alerts for failures

## Support

For issues:
- **ContextForge**: Check ContextForge documentation
- **Wrapper**: Review wrapper logs in Code Engine
- **watsonx Orchestrate**: Contact IBM support
- **watsonx.ai**: Verify agent deployment and credentials