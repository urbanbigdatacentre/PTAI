# Great Britain Accessibility Indicators 2023 - Docker Environment
# Base image with R and system dependencies
FROM rocker/r-ver:4.3.0

# Metadata
LABEL maintainer="UBDC <ubdc@glasgow.ac.uk>"
LABEL description="Docker environment for Great Britain Accessibility Indicators 2023"
LABEL version="1.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV R_REPOS=https://cran.rstudio.com
ENV TZ=Europe/London

# Install system dependencies
RUN apt-get update && apt-get install -y \
  # Essential system tools
  curl \
  wget \
  git \
  vim \
  nano \
  htop \
  # Build tools
  build-essential \
  cmake \
  # R package dependencies
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libgdal-dev \
  libgeos-dev \
  libproj-dev \
  libudunits2-dev \
  libv8-dev \
  libprotobuf-dev \
  protobuf-compiler \
  libjq-dev \
  # For PDF generation
  texlive-latex-base \
  texlive-latex-recommended \
  texlive-latex-extra \
  texlive-fonts-recommended \
  # Cleanup
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy the R package installation script
COPY install_packages.R /tmp/install_packages.R

# Install all R packages using the script
RUN Rscript /tmp/install_packages.R && rm /tmp/install_packages.R

# Create necessary directories
RUN mkdir -p /workspace/data \
  /workspace/output \
  /workspace/plots \
  /workspace/logs

# Copy project files
COPY . /workspace/

# Make scripts executable
RUN chmod +x /workspace/run_pipeline.sh
RUN chmod +x /workspace/docker_entrypoint.sh 2>/dev/null || true

# Set proper ownership
RUN chown -R rstudio:rstudio /workspace

# Switch to rstudio user
USER rstudio

# Set default command
CMD ["/bin/bash"]

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD R --slave -e "library(tidyverse); library(sf); library(AccessUK)" || exit 1

# Expose port for RStudio Server if needed (optional)
EXPOSE 8787

# Volume for persistent data
VOLUME ["/workspace/data", "/workspace/output"]
