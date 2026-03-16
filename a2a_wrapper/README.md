# ContextForge A2A Wrapper for watsonx Orchestrate

This wrapper translates between watsonx Orchestrate's A2A 0.2.1 protocol and ContextForge's API format, enabling seamless integration of ContextForge agents with watsonx Orchestrate.

## Problem Solved

ContextForge uses a custom A2A protocol (version 1.0) that is incompatible with watsonx Orchestrate's standard A2A 0.2.1 protocol. This wrapper acts as a translation layer between the two systems.

## Features

- ✅ A2A 0.2.1 capabilities discovery endpoint
- ✅ Message forwarding to ContextForge
- ✅ Bearer token authentication
- ✅ Error handling and logging
- ✅ Health check endpoint

## Installation

```bash
cd a2a_wrapper
pip install -r requirements.txt
```

## Configuration

Set the following environment variables:

```bash
export CONTEXTFORGE_URL="https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
export CONTEXTFORGE_TOKEN="your-jwt-token-here"
export PORT=5000  # Optional, defaults to 5000
export DEBUG=false  # Optional, defaults to false
```

## Usage

### Run Locally

```bash
python contextforge_wrapper.py
```

### Run with Gunicorn (Production)

```bash
gunicorn -w 4 -b 0.0.0.0:5000 contextforge_wrapper:app
```

### Test the Wrapper

```bash
# Health check
curl http://localhost:5000/health

# Get agent capabilities
curl http://localhost:5000/a2a/parsing-agent

# Send a message
curl -X POST http://localhost:5000/a2a/parsing-agent/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "test"}]
    }
  }'
```

## Integration with watsonx Orchestrate

1. **Deploy the wrapper** to your preferred platform (Code Engine, Cloud Foundry, etc.)

2. **Get the wrapper URL** (e.g., `https://your-wrapper.example.com`)

3. **Import agent in watsonx Orchestrate:**
   - Go to Agents → Import agent
   - Select "External agent via A2A standard"
   - A2A protocol version: 0.3.0 (or 0.2.1)
   - Authentication type: Bearer token
   - Bearer token: Your ContextForge JWT token
   - External agent's URL: `https://your-wrapper.example.com/a2a/parsing-agent`
   - Display name: Parsing Agent

4. **Test the integration** in Orchestrate

## API Endpoints

### GET `/health`
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "service": "contextforge-a2a-wrapper",
  "version": "1.0.0"
}
```

### GET `/a2a/{agent_name}`
A2A capabilities discovery endpoint

**Response:**
```json
{
  "name": "parsing-agent",
  "description": "ContextForge agent: parsing-agent",
  "version": "0.2.1",
  "capabilities": {
    "message": true,
    "streaming": false,
    "tools": []
  }
}
```

### POST `/a2a/{agent_name}/message`
Forward message to ContextForge agent

**Request:**
```json
{
  "message": {
    "role": "user",
    "parts": [{"kind": "text", "text": "your message"}]
  }
}
```

**Response:** Forwarded from ContextForge

### POST `/a2a/{agent_name}/invoke`
Alternative invoke endpoint for compatibility

## Deployment

### Docker

Create a `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY contextforge_wrapper.py .

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "contextforge_wrapper:app"]
```

Build and run:

```bash
docker build -t contextforge-wrapper .
docker run -p 5000:5000 \
  -e CONTEXTFORGE_URL="https://context-forge.example.com" \
  -e CONTEXTFORGE_TOKEN="your-token" \
  contextforge-wrapper
```

### IBM Code Engine

```bash
ibmcloud ce application create \
  --name contextforge-wrapper \
  --image your-registry/contextforge-wrapper:latest \
  --port 5000 \
  --env CONTEXTFORGE_URL="https://context-forge.example.com" \
  --env CONTEXTFORGE_TOKEN="your-token"
```

## Troubleshooting

### 502 Bad Gateway
- Check that CONTEXTFORGE_URL is correct
- Verify network connectivity to ContextForge
- Check ContextForge service status

### 500 Internal Server Error
- Verify CONTEXTFORGE_TOKEN is set
- Check wrapper logs for details
- Ensure ContextForge agent exists

### 504 Gateway Timeout
- ContextForge agent may be slow to respond
- Check ContextForge agent status
- Consider increasing timeout (default: 60s)

## License

Same as parent repository