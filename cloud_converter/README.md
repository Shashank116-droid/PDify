# Cloud Converter Service

A lightweight document conversion service using LibreOffice, deployed on Google Cloud Run.

## Supported Conversions
- Word (.docx) → PDF
- PowerPoint (.pptx) → PDF
- PDF → Word (.docx)
- PDF → PowerPoint (.pptx)

## Deploy
```bash
gcloud run deploy pdify-converter \
  --source . \
  --region us-central1 \
  --memory 1Gi \
  --allow-unauthenticated
```
