#!/bin/bash

# Quick Docker build test script
set -e

echo "🐳 Testing Docker build for PTAI Analysis..."
echo "=============================================="

# Build the main image
echo "📦 Building main analysis image..."
docker build -t ubdc/ptai-analysis:test .

echo "✅ Build successful!"

# Test basic functionality
echo "🧪 Testing basic R functionality..."
docker run --rm ubdc/ptai-analysis:test R --slave -e "
library(tidyverse)
library(sf) 
library(AccessUK)
cat('✅ All critical packages loaded successfully!\n')
cat('📊 tidyverse version:', as.character(packageVersion('tidyverse')), '\n')
cat('🗺️  sf version:', as.character(packageVersion('sf')), '\n')
cat('🚀 AccessUK version:', as.character(packageVersion('AccessUK')), '\n')
"

echo "🎉 Docker image is ready for use!"
echo ""
echo "Usage examples:"
echo "  docker run --rm ubdc/ptai-analysis:test validate"
echo "  docker run -it --rm ubdc/ptai-analysis:test interactive"
echo "  docker-compose up ptai-analysis"
