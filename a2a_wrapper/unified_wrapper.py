#!/usr/bin/env python3
"""
Unified A2A Wrapper for watsonx Orchestrate
Supports both ContextForge and watsonx.ai agents
"""

import os
import logging
from flask import Flask, request, jsonify
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration for ContextForge
CONTEXTFORGE_URL = os.getenv(
    "CONTEXTFORGE_URL",
    "https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
)
CONTEXTFORGE_TOKEN = os.getenv("CONTEXTFORGE_TOKEN", "")

# Configuration for watsonx.ai
WATSONX_URL = os.getenv("WATSONX_URL", "https://us-south.ml.cloud.ibm.com")
WATSONX_API_KEY = os.getenv("WATSONX_API_KEY", "")
WATSONX_PROJECT_ID = os.getenv("WATSONX_PROJECT_ID", "")

# Agent routing configuration
# Format: "agent-name": "backend" where backend is "contextforge" or "watsonx"
AGENT_ROUTING = {
    "parsing-agent": "contextforge",
    "watsonx-agent": "watsonx",
    # Add more agents as needed
}


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "unified-a2a-wrapper",
        "version": "1.0.0",
        "backends": {
            "contextforge": bool(CONTEXTFORGE_TOKEN),
            "watsonx": bool(WATSONX_API_KEY)
        }
    })


@app.route('/a2a/<agent_name>', methods=['GET'])
def get_capabilities(agent_name: str):
    """
    A2A 0.2.1 capabilities discovery endpoint
    Returns capabilities based on the backend the agent uses
    """
    logger.info(f"Capabilities request for agent: {agent_name}")
    
    backend = AGENT_ROUTING.get(agent_name, "contextforge")
    
    return jsonify({
        "name": agent_name,
        "description": f"Agent: {agent_name} (backend: {backend})",
        "version": "0.2.1",
        "capabilities": {
            "message": True,
            "streaming": False,
            "tools": []
        },
        "metadata": {
            "backend": backend,
            "protocol": "A2A 0.2.1"
        }
    })


@app.route('/a2a/<agent_name>/message', methods=['POST'])
def send_message(agent_name: str):
    """
    Forward A2A message to appropriate backend
    Routes to ContextForge or watsonx.ai based on agent configuration
    """
    try:
        a2a_body = request.json
        logger.info(f"Message request for agent: {agent_name}")
        logger.debug(f"Request body: {a2a_body}")
        
        # Determine backend
        backend = AGENT_ROUTING.get(agent_name, "contextforge")
        logger.info(f"Routing to backend: {backend}")
        
        if backend == "contextforge":
            return forward_to_contextforge(agent_name, a2a_body)
        elif backend == "watsonx":
            return forward_to_watsonx(agent_name, a2a_body)
        else:
            return jsonify({
                "error": "Unknown backend",
                "message": f"Backend '{backend}' not supported"
            }), 500
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


def forward_to_contextforge(agent_name: str, a2a_body: dict):
    """Forward request to ContextForge"""
    try:
        if not CONTEXTFORGE_TOKEN:
            return jsonify({
                "error": "Configuration error",
                "message": "CONTEXTFORGE_TOKEN not configured"
            }), 500
        
        response = requests.post(
            f"{CONTEXTFORGE_URL}/a2a/{agent_name}/message",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {CONTEXTFORGE_TOKEN}"
            },
            json=a2a_body,
            timeout=60
        )
        
        logger.info(f"ContextForge response status: {response.status_code}")
        
        try:
            return jsonify(response.json()), response.status_code
        except ValueError:
            return jsonify({
                "response": response.text,
                "status": response.status_code
            }), response.status_code
        
    except requests.exceptions.Timeout:
        logger.error(f"Timeout calling ContextForge for agent: {agent_name}")
        return jsonify({
            "error": "Gateway timeout",
            "message": "Request to ContextForge timed out"
        }), 504
        
    except requests.exceptions.RequestException as e:
        logger.error(f"ContextForge request error: {str(e)}")
        return jsonify({
            "error": "Bad gateway",
            "message": f"Failed to connect to ContextForge: {str(e)}"
        }), 502


def forward_to_watsonx(agent_name: str, a2a_body: dict):
    """Forward request to watsonx.ai"""
    try:
        if not WATSONX_API_KEY:
            return jsonify({
                "error": "Configuration error",
                "message": "WATSONX_API_KEY not configured"
            }), 500
        
        # Extract message text from A2A format
        message = a2a_body.get("message", {})
        parts = message.get("parts", [])
        text = ""
        for part in parts:
            if part.get("kind") == "text":
                text = part.get("text", "")
                break
        
        # Get IAM token
        iam_token = get_iam_token(WATSONX_API_KEY)
        
        # Call watsonx.ai
        watsonx_response = requests.post(
            f"{WATSONX_URL}/ml/v1/text/generation?version=2023-05-29",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {iam_token}",
                "Accept": "application/json"
            },
            json={
                "input": text,
                "parameters": {
                    "max_new_tokens": 1000,
                    "temperature": 0.7
                },
                "model_id": "ibm/granite-13b-chat-v2",
                "project_id": WATSONX_PROJECT_ID
            },
            timeout=60
        )
        
        logger.info(f"watsonx.ai response status: {watsonx_response.status_code}")
        
        if watsonx_response.status_code == 200:
            wx_result = watsonx_response.json()
            generated_text = wx_result.get("results", [{}])[0].get("generated_text", "")
            
            # Convert to A2A format
            return jsonify({
                "message": {
                    "role": "assistant",
                    "parts": [{"kind": "text", "text": generated_text}]
                }
            }), 200
        else:
            return jsonify({
                "error": "watsonx.ai error",
                "message": watsonx_response.text
            }), watsonx_response.status_code
        
    except Exception as e:
        logger.error(f"watsonx.ai error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Bad gateway",
            "message": f"Failed to connect to watsonx.ai: {str(e)}"
        }), 502


def get_iam_token(api_key: str) -> str:
    """Get IBM Cloud IAM token from API key"""
    response = requests.post(
        "https://iam.cloud.ibm.com/identity/token",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "urn:ibm:params:oauth:grant-type:apikey",
            "apikey": api_key
        },
        timeout=30
    )
    
    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        raise Exception(f"Failed to get IAM token: {response.text}")


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        "error": "Not found",
        "message": "The requested endpoint does not exist"
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({
        "error": "Internal server error",
        "message": "An unexpected error occurred"
    }), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting Unified A2A Wrapper on port {port}")
    logger.info(f"ContextForge URL: {CONTEXTFORGE_URL}")
    logger.info(f"watsonx.ai URL: {WATSONX_URL}")
    logger.info(f"Agent routing: {AGENT_ROUTING}")
    logger.info(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)

# Made with Bob
