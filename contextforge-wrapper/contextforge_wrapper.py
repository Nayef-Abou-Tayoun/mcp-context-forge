#!/usr/bin/env python3
"""
ContextForge A2A Wrapper for watsonx Orchestrate
Translates A2A 0.2.1 protocol to ContextForge API format
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

# Configuration
CONTEXTFORGE_URL = os.getenv(
    "CONTEXTFORGE_URL",
    "https://context-forge.27jid12fsm9n.us-south.codeengine.appdomain.cloud"
)
CONTEXTFORGE_TOKEN = os.getenv(
    "CONTEXTFORGE_TOKEN",
    ""
)

if not CONTEXTFORGE_TOKEN:
    logger.warning("CONTEXTFORGE_TOKEN not set - requests will fail")


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "contextforge-a2a-wrapper",
        "version": "1.0.0"
    })


@app.route('/a2a/<agent_name>', methods=['GET'])
def get_capabilities(agent_name: str):
    """
    A2A 0.2.1 capabilities discovery endpoint
    Called by watsonx Orchestrate to discover agent capabilities before invocation
    """
    logger.info(f"Capabilities request for agent: {agent_name}")
    
    return jsonify({
        "name": agent_name,
        "description": f"ContextForge agent: {agent_name}",
        "version": "0.2.1",
        "capabilities": {
            "message": True,
            "streaming": False,
            "tools": []
        },
        "metadata": {
            "provider": "contextforge",
            "endpoint": f"{CONTEXTFORGE_URL}/a2a/{agent_name}",
            "protocol": "A2A 0.2.1"
        }
    })


@app.route('/a2a/<agent_name>/message', methods=['POST'])
def send_message(agent_name: str):
    """
    Forward A2A message to ContextForge
    Translates A2A 0.2.1 format to ContextForge format
    """
    try:
        # Get A2A format from watsonx Orchestrate
        a2a_body = request.json
        logger.info(f"Message request for agent: {agent_name}")
        logger.debug(f"Request body: {a2a_body}")
        
        if not CONTEXTFORGE_TOKEN:
            return jsonify({
                "error": "Configuration error",
                "message": "CONTEXTFORGE_TOKEN not configured"
            }), 500
        
        # Forward to ContextForge (format is already compatible)
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
        
        # Return response from ContextForge
        try:
            return jsonify(response.json()), response.status_code
        except ValueError:
            # If response is not JSON, return as text
            return jsonify({
                "response": response.text,
                "status": response.status_code
            }), response.status_code
        
    except requests.exceptions.Timeout:
        logger.error(f"Timeout calling ContextForge for agent: {agent_name}")
        return jsonify({
            "error": "Gateway timeout",
            "message": "Request to ContextForge timed out after 60 seconds"
        }), 504
        
    except requests.exceptions.ConnectionError as e:
        logger.error(f"Connection error: {str(e)}")
        return jsonify({
            "error": "Bad gateway",
            "message": f"Failed to connect to ContextForge: {str(e)}"
        }), 502
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Request error: {str(e)}")
        return jsonify({
            "error": "Bad gateway",
            "message": f"Request to ContextForge failed: {str(e)}"
        }), 502
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@app.route('/a2a/<agent_name>/invoke', methods=['POST'])
def invoke_agent(agent_name: str):
    """
    Alternative invoke endpoint for compatibility
    Some A2A clients may use /invoke instead of /message
    """
    try:
        body = request.json
        logger.info(f"Invoke request for agent: {agent_name}")
        logger.debug(f"Request body: {body}")
        
        if not CONTEXTFORGE_TOKEN:
            return jsonify({
                "error": "Configuration error",
                "message": "CONTEXTFORGE_TOKEN not configured"
            }), 500
        
        # Forward to ContextForge invoke endpoint
        response = requests.post(
            f"{CONTEXTFORGE_URL}/a2a/{agent_name}/invoke",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {CONTEXTFORGE_TOKEN}"
            },
            json=body,
            timeout=60
        )
        
        logger.info(f"ContextForge invoke response status: {response.status_code}")
        
        try:
            return jsonify(response.json()), response.status_code
        except ValueError:
            return jsonify({
                "response": response.text,
                "status": response.status_code
            }), response.status_code
        
    except Exception as e:
        logger.error(f"Invoke error: {str(e)}", exc_info=True)
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
    
    logger.info(f"Starting ContextForge A2A Wrapper on port {port}")
    logger.info(f"ContextForge URL: {CONTEXTFORGE_URL}")
    logger.info(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)

# Made with Bob
