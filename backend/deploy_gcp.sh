#!/bin/bash
set -e

# Replace with your GCP project ID and preferred region
PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
SERVICE_NAME="noteflow-backend"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "Building Docker image..."
# Use Cloud Build if local docker is not set up for pushing large images easily
# gcloud builds submit --tag $IMAGE_NAME .
# OR locally:
docker build -t $IMAGE_NAME .
docker push $IMAGE_NAME

echo "Deploying to Cloud Run with GPU support..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --memory 16Gi \
  --cpu 4 \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --no-cpu-throttling \
  --max-instances 2 \
  --timeout 3600

echo "Deployment complete! Copy the Service URL for the Mac App setting."
