# Direct watsonx.ai A2A Wrapper

This wrapper calls watsonx.ai **directly** and handles SSE (Server-Sent Events) streaming responses, bypassing ContextForge entirely.

## Why This Solution?

**Problem:** ContextForge's A2A service expects plain JSON responses, but watsonx.ai returns SSE streaming format.

**Solution:** This wrapper:
1. Receives A2A 0.2.1 requests from watsonx Orchestrate
2. Calls watsonx.ai directly with proper authentication
3. Parses the SSE streaming response
4. Returns a complete JSON response in A2A 0.2.1 format

## Architecture

```
watsonx Orchestrate (A2A 0.2.1)
    ↓
Direct Wrapper (handles SSE streaming)
    ↓
watsonx.ai (SSE streaming response)
```

## Deployment

### Prerequisites

1. IBM Cloud CLI with Code Engine plugin
2. Docker
3. IBM Cloud API Key
4. watsonx.ai IAM Token

### Quick Deploy

```bash
# Set your watsonx.ai IAM token
export WATSONX_IAM_TOKEN="your-iam-token-here"

# Set your IBM Cloud API key
export IBM_CLOUD_API_KEY="your-api-key-here"

# Deploy
cd a2a_wrapper
./deploy-direct-wrapper.sh
```

### Manual Deployment

```bash
# Build Docker image
docker build -f Dockerfile.direct -t a2a-direct-wrapper:latest .

# Tag for IBM Container Registry
docker tag a2a-direct-wrapper:latest \
  us.icr.io/ce-itz-wxo-69b79145ff7b2fa48ecc8f/a2a-direct-wrapper:latest

# Push to registry
ibmcloud cr login
docker push us.icr.io/ce-itz-wxo-69b79145ff7b2fa48ecc8f/a2a-direct-wrapper:latest

# Deploy to Code Engine
ibmcloud ce app create --name a2a-direct-wrapper \
  --image us.icr.io/ce-itz-wxo-69b79145ff7b2fa48ecc8f/a2a-direct-wrapper:latest \
  --env WATSONX_DEPLOYMENT_URL="https://us-south.ml.cloud.ibm.com/ml/v4/deployments/54a97f4d-1746-4ae7-ae38-70b03080bfc6/ai_service_stream?version=2021-05-01" \
  --env WATSONX_IAM_TOKEN="your-token" \
  --port 8080 \
  --min-scale 1 \
  --max-scale 5 \
  --cpu 0.5 \
  --memory 1G \
  --request-timeout 300
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `WATSONX_DEPLOYMENT_URL` | watsonx.ai deployment endpoint | Yes |
| `WATSONX_IAM_TOKEN` | IBM Cloud IAM token for watsonx.ai | Yes |
| `PORT` | Port to run on (default: 8080) | No |
| `DEBUG` | Enable debug logging (default: false) | No |

### Token Management

**Important:** IAM tokens expire after 1 hour. For production:

1. **Option 1:** Use IBM Cloud API Key with automatic token refresh
2. **Option 2:** Implement a token refresh mechanism
3. **Option 3:** Use a service account with long-lived credentials

## Testing

### Health Check

```bash
curl https://a2a-direct-wrapper.27jid12fsm9n.us-south.codeengine.appdomain.cloud/health
```

### Get Capabilities (A2A 0.2.1)

```bash
curl https://a2a-direct-wrapper.27jid12fsm9n.us-south.codeengine.appdomain.cloud/a2a/watsonx-agent
```

### Send Message

```bash
curl -X POST https://a2a-direct-wrapper.27jid12fsm9n.us-south.codeengine.appdomain.cloud/a2a/watsonx-agent/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [
        {
          "kind": "text",
          "text": "Hello, can you help me?"
        }
      ]
    }
  }'
```

## Integration with watsonx Orchestrate

1. **Open watsonx Orchestrate**
2. **Navigate to Agent Management**
3. **Add New Agent**
4. **Enter the wrapper URL:**
   ```
   https://a2a-direct-wrapper.27jid12fsm9n.us-south.codeengine.appdomain.cloud/a2a/watsonx-agent
   ```
5. **Test the agent** in Orchestrate chat

## How It Works

### SSE Stream Parsing

The wrapper parses watsonx.ai's SSE stream format:

```
id: 1
event: message
data: {"choices": [{"index": 0, "delta": {"role": "assistant", "content": "Hello"}}]}

id: 2
event: message
data: {"choices": [{"index": 0, "delta": {"role": "assistant", "content": " there"}}]}
```

And combines all `delta.content` chunks into a single response:

```json
{
  "message": {
    "role": "assistant",
    "parts": [
      {
        "kind": "text",
        "text": "Hello there"
      }
    ]
  }
}
```

### Error Handling

The wrapper handles:
- Connection timeouts (120s)
- Network errors
- Invalid responses
- Token expiration
- SSE parsing errors

## Troubleshooting

### Token Expired

**Error:** `401 Unauthorized`

**Solution:** Generate a new IAM token:
```bash
ibmcloud iam oauth-tokens
```

Then update the Code Engine app:
```bash
ibmcloud ce app update --name a2a-direct-wrapper \
  --env WATSONX_IAM_TOKEN="new-token"
```

### Timeout Errors

**Error:** `504 Gateway Timeout`

**Solution:** Increase request timeout:
```bash
ibmcloud ce app update --name a2a-direct-wrapper \
  --request-timeout 600
```

### SSE Parsing Errors

Check logs:
```bash
ibmcloud ce app logs --name a2a-direct-wrapper
```

## Advantages Over ContextForge Integration

1. ✅ **Direct communication** - No intermediate service
2. ✅ **Handles SSE streaming** - Properly parses watsonx.ai responses
3. ✅ **Simpler architecture** - Fewer moving parts
4. ✅ **Better error handling** - Direct control over error responses
5. ✅ **Lower latency** - One less hop in the request chain

## Files

- `direct_watsonx_wrapper.py` - Main wrapper application
- `Dockerfile.direct` - Docker configuration
- `deploy-direct-wrapper.sh` - Automated deployment script
- `requirements.txt` - Python dependencies (shared)

## Support

For issues or questions, check:
- Application logs: `ibmcloud ce app logs --name a2a-direct-wrapper`
- Health endpoint: `/health`
- watsonx.ai API documentation