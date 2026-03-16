# Unified A2A Wrapper for watsonx Orchestrate

This wrapper supports **both ContextForge and watsonx.ai agents**, routing requests to the appropriate backend based on agent configuration.

## Features

- ✅ Supports multiple backends (ContextForge + watsonx.ai)
- ✅ A2A 0.2.1 protocol translation
- ✅ Intelligent agent routing
- ✅ Bearer token authentication for ContextForge
- ✅ IBM Cloud IAM authentication for watsonx.ai
- ✅ Health check endpoint
- ✅ Comprehensive error handling

## Architecture

```
watsonx Orchestrate
       ↓
   Unified Wrapper
       ↓
   ┌─────────┴─────────┐
   ↓                   ↓
ContextForge      watsonx.ai
```

## Configuration

### Environment Variables

```bash
# ContextForge
CONTEXTFORGE_URL=https://context-forge.example.com
CONTEXTFORGE_TOKEN=your-jwt-token

# watsonx.ai
WATSONX_URL=https://us-south.ml.cloud.ibm.com
WATSONX_API_KEY=your-api-key
WATSONX_PROJECT_ID=your-project-id

# Server
PORT=5000
DEBUG=false
```

### Agent Routing

Edit `unified_wrapper.py` to configure which agents use which backend:

```python
AGENT_ROUTING = {
    "parsing-agent": "contextforge",
    "watsonx-agent": "watsonx",
    "my-custom-agent": "contextforge",
    # Add more agents as needed
}
```

## Installation

```bash
cd a2a_wrapper
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials
```

## Usage

### Run Locally

```bash
python unified_wrapper.py
```

### Run with Gunicorn (Production)

```bash
gunicorn -w 4 -b 0.0.0.0:5000 unified_wrapper:app
```

### Test the Wrapper

```bash
# Health check
curl http://localhost:5000/health

# Get agent capabilities
curl http://localhost:5000/a2a/parsing-agent

# Send message to ContextForge agent
curl -X POST http://localhost:5000/a2a/parsing-agent/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "test"}]
    }
  }'

# Send message to watsonx.ai agent
curl -X POST http://localhost:5000/a2a/watsonx-agent/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hello"}]
    }
  }'
```

## Deployment to IBM Code Engine

### Using CLI

```bash
# Build Docker image
docker build -t us.icr.io/your-namespace/unified-wrapper:latest -f Dockerfile .
docker push us.icr.io/your-namespace/unified-wrapper:latest

# Deploy to Code Engine
ibmcloud ce application create \
  --name unified-a2a-wrapper \
  --image us.icr.io/your-namespace/unified-wrapper:latest \
  --port 5000 \
  --env CONTEXTFORGE_URL="https://context-forge.example.com" \
  --env CONTEXTFORGE_TOKEN="your-token" \
  --env WATSONX_URL="https://us-south.ml.cloud.ibm.com" \
  --env WATSONX_API_KEY="your-api-key" \
  --env WATSONX_PROJECT_ID="your-project-id" \
  --min-scale 1 \
  --max-scale 5
```

### Using Code Engine Console

1. Go to IBM Cloud → Code Engine → Applications
2. Create application from container image
3. Add environment variables:
   - `CONTEXTFORGE_URL`
   - `CONTEXTFORGE_TOKEN`
   - `WATSONX_URL`
   - `WATSONX_API_KEY`
   - `WATSONX_PROJECT_ID`

## Integration with watsonx Orchestrate

After deploying, you'll get a URL like:
```
https://unified-wrapper.xyz123.us-south.codeengine.appdomain.cloud
```

### For ContextForge Agents

In watsonx Orchestrate:
- Import agent via A2A standard
- URL: `https://unified-wrapper.xyz123.codeengine.appdomain.cloud/a2a/parsing-agent`
- Authentication: Bearer token (your ContextForge token)

### For watsonx.ai Agents

In watsonx Orchestrate:
- Import agent via A2A standard
- URL: `https://unified-wrapper.xyz123.codeengine.appdomain.cloud/a2a/watsonx-agent`
- Authentication: API key (your watsonx.ai API key)

## Adding New Agents

1. **Edit `unified_wrapper.py`:**
   ```python
   AGENT_ROUTING = {
       "parsing-agent": "contextforge",
       "watsonx-agent": "watsonx",
       "new-agent": "contextforge",  # Add this line
   }
   ```

2. **Restart the wrapper**

3. **Import in Orchestrate:**
   - URL: `https://your-wrapper/a2a/new-agent`

## API Endpoints

### GET `/health`
Health check with backend status

**Response:**
```json
{
  "status": "healthy",
  "service": "unified-a2a-wrapper",
  "version": "1.0.0",
  "backends": {
    "contextforge": true,
    "watsonx": true
  }
}
```

### GET `/a2a/{agent_name}`
A2A capabilities discovery

**Response:**
```json
{
  "name": "parsing-agent",
  "description": "Agent: parsing-agent (backend: contextforge)",
  "version": "0.2.1",
  "capabilities": {
    "message": true,
    "streaming": false
  },
  "metadata": {
    "backend": "contextforge",
    "protocol": "A2A 0.2.1"
  }
}
```

### POST `/a2a/{agent_name}/message`
Forward message to appropriate backend

**Request:**
```json
{
  "message": {
    "role": "user",
    "parts": [{"kind": "text", "text": "your message"}]
  }
}
```

**Response:** Varies by backend

## Troubleshooting

### ContextForge Backend Issues

- **502 Bad Gateway**: Check CONTEXTFORGE_URL and network connectivity
- **500 Internal Server Error**: Verify CONTEXTFORGE_TOKEN is set
- **504 Gateway Timeout**: ContextForge agent may be slow

### watsonx.ai Backend Issues

- **401 Unauthorized**: Check WATSONX_API_KEY is valid
- **403 Forbidden**: Verify WATSONX_PROJECT_ID permissions
- **500 Internal Server Error**: Check IAM token generation

### General Issues

- **Agent not routing correctly**: Check AGENT_ROUTING configuration
- **Health check fails**: Verify environment variables are set
- **Logs**: Check wrapper logs for detailed error messages

## License

Same as parent repository