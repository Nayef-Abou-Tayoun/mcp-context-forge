FROM python:3.11-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY contextforge_wrapper.py .

# Environment variables (can be overridden at runtime)
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health', timeout=5)"

# Run with gunicorn for production
CMD gunicorn -w 4 -b 0.0.0.0:${PORT} --timeout 120 --access-logfile - --error-logfile - contextforge_wrapper:app