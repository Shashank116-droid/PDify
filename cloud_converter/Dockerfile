FROM python:3.11-slim

# Install LibreOffice
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libreoffice-writer \
    libreoffice-impress \
    libreoffice-common \
    fonts-dejavu \
    fonts-liberation \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Create temp directory for conversions
RUN mkdir -p /tmp/conversions

# Cloud Run sets PORT env variable
ENV PORT=8080

EXPOSE 8080

CMD ["python", "app.py"]
