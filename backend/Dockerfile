FROM python:3.11-slim

WORKDIR /app

# Prevent Python from buffering stdout/stderr — required for streaming responses in Docker
ENV PYTHONUNBUFFERED=1

# Install system dependencies required for lxml and curl_cffi
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    libxml2-dev \
    libxslt-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY backend/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the backend code
COPY . .

# Expose the API port
EXPOSE 8000

# Run the FastAPI application
CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
