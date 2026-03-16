#!/usr/bin/env python3
"""
Direct watsonx.ai A2A Wrapper for watsonx Orchestrate
Calls watsonx.ai directly and handles SSE streaming responses
"""

import os
import logging
import json
from flask import Flask, request, jsonify
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
WATSONX_DEPLOYMENT_URL = os.getenv(
    "WATSONX_DEPLOYMENT_URL",
    "https://us-south.ml.cloud.ibm.com/ml/v4/deployments/54a97f4d-1746-4ae7-ae38-70b03080bfc6/ai_service_stream?version=2021-05-01"
)
WATSONX_IAM_TOKEN = os.getenv("WATSONX_IAM_TOKEN", "")

if not WATSONX_IAM_TOKEN:
    logger.warning("WATSONX_IAM_TOKEN not set - requests will fail")


def parse_sse_stream(response):
    """
    Parse Server-Sent Events (SSE) stream from watsonx.ai
    Combines all delta content chunks into a single response
    """
    full_content = ""
    
    for line in response.iter_lines():
        if not line:
            continue
            
        line = line.decode('utf-8')
        
        # SSE format: "data: {json}"
        if line.startswith('data: '):
            try:
                data = json.loads(line[6:])  # Remove "data: " prefix
                
                # Extract content from delta
                if 'choices' in data and len(data['choices']) > 0:
                    choice = data['choices'][0]
                    if 'delta' in choice and 'content' in choice['delta']:
                        full_content += choice['delta']['content']
                        
            except json.JSONDecodeError:
                logger.debug(f"Skipping non-JSON SSE line: {line}")
                continue
    
    return full_content


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "direct-watsonx-a2a-wrapper",
        "version": "1.0.0"
    })


@app.route('/a2a/<agent_name>', methods=['GET'])
def get_capabilities(agent_name: str):
    """
    A2A 0.2.1 capabilities discovery endpoint
    """
    logger.info(f"Capabilities request for agent: {agent_name}")
    
    return jsonify({
        "name": agent_name,
        "description": f"watsonx.ai agent: {agent_name}",
        "version": "0.2.1",
        "capabilities": {
            "message": True,
            "streaming": False,
            "tools": []
        },
        "metadata": {
            "provider": "watsonx.ai",
            "model": "meta-llama/llama-3-3-70b-instruct",
            "protocol": "A2A 0.2.1"
        }
    })


@app.route('/a2a/<agent_name>/message', methods=['POST'])
def send_message(agent_name: str):
    """
    Forward A2A message directly to watsonx.ai
    Handles SSE streaming response and returns JSON
    """
    try:
        # Get A2A format from watsonx Orchestrate
        a2a_body = request.json
        logger.info(f"Message request for agent: {agent_name}")
        logger.debug(f"Request body: {a2a_body}")
        
        if not WATSONX_IAM_TOKEN:
            return jsonify({
                "error": "Configuration error",
                "message": "WATSONX_IAM_TOKEN not configured"
            }), 500
        
        # Extract message from A2A format
        message_text = ""
        if 'message' in a2a_body:
            msg = a2a_body['message']
            if 'parts' in msg:
                for part in msg['parts']:
                    if part.get('kind') == 'text':
                        message_text = part.get('text', '')
                        break
        
        if not message_text:
            return jsonify({
                "error": "Invalid request",
                "message": "No text message found in request"
            }), 400
        
        # Convert to watsonx.ai format
        watsonx_payload = {
            "messages": [
                {
                    "role": "user",
                    "content": message_text
                }
            ]
        }
        
        logger.info(f"Calling watsonx.ai with message: {message_text[:100]}...")
        
        # Call watsonx.ai with streaming
        response = requests.post(
            WATSONX_DEPLOYMENT_URL,
            headers={
                "Authorization": f"Bearer {WATSONX_IAM_TOKEN}",
                "Content-Type": "application/json"
            },
            json=watsonx_payload,
            timeout=120,
            stream=True  # Enable streaming
        )
        
        if response.status_code != 200:
            logger.error(f"watsonx.ai error: {response.status_code} - {response.text}")
            return jsonify({
                "error": "Upstream error",
                "message": f"watsonx.ai returned {response.status_code}: {response.text}"
            }), response.status_code
        
        # Parse SSE stream
        logger.info("Parsing SSE stream from watsonx.ai...")
        full_response = parse_sse_stream(response)
        
        logger.info(f"Received response: {full_response[:100]}...")
        
        # Return in A2A format
        return jsonify({
            "message": {
                "role": "assistant",
                "parts": [
                    {
                        "kind": "text",
                        "text": full_response
                    }
                ]
            },
            "metadata": {
                "model": "meta-llama/llama-3-3-70b-instruct",
                "provider": "watsonx.ai"
            }
        }), 200
        
    except requests.exceptions.Timeout:
        logger.error(f"Timeout calling watsonx.ai for agent: {agent_name}")
        return jsonify({
            "error": "Gateway timeout",
            "message": "Request to watsonx.ai timed out after 120 seconds"
        }), 504
        
    except requests.exceptions.ConnectionError as e:
        logger.error(f"Connection error: {str(e)}")
        return jsonify({
            "error": "Bad gateway",
            "message": f"Failed to connect to watsonx.ai: {str(e)}"
        }), 502
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


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
    # Run the Flask app
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting Direct watsonx.ai A2A Wrapper on port {port}")
    logger.info(f"watsonx.ai URL: {WATSONX_DEPLOYMENT_URL}")
    logger.info(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)

# Made with Bob
