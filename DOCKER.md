# 🐳 Docker Setup for Great Britain Accessibility Indicators 2023

This document provides comprehensive instructions for running the accessibility analysis using Docker.

## Quick Start

### 1. Prerequisites
- Docker installed and running
- Docker Compose (optional, for simplified management)
- Required data files (see main README.md)

### 2. Build and Run
```bash
# Clone the repository
git clone <repository-url>
cd PTAI

# Place your data files in the data/ directory
# (See main README.md for data requirements)

# Build the Docker image
docker build -t ubdc/ptai-analysis .

# Run the analysis
docker run -v $(pwd)/data:/workspace/data:ro \
           -v $(pwd)/output:/workspace/output \
           -v $(pwd)/plots:/workspace/plots \
           ubdc/ptai-analysis
```

## Docker Images

### Main Analysis Image (`Dockerfile`)
- **Purpose**: Run the complete accessibility analysis pipeline
- **Base**: `rocker/r-ver:4.3.0`
- **Size**: ~2.5GB (includes all R packages and system dependencies)
- **Features**: All required R packages, spatial libraries, system tools

### RStudio Server Image (`Dockerfile.rstudio`)
- **Purpose**: Interactive development and exploration
- **Base**: `rocker/rstudio:4.3.0`
- **Access**: Web interface on port 8787
- **Features**: Same packages as main image + RStudio Server

## Usage Options

### Option 1: Docker Run Commands

#### Basic Analysis Run
```bash
docker run --rm \
  -v /path/to/your/data:/workspace/data:ro \
  -v $(pwd)/output:/workspace/output \
  -v $(pwd)/plots:/workspace/plots \
  ubdc/ptai-analysis
```

#### Interactive Session
```bash
docker run -it --rm \
  -v /path/to/your/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  -v $(pwd)/plots:/workspace/plots \
  ubdc/ptai-analysis interactive
```

#### R Session Only
```bash
docker run -it --rm \
  -v /path/to/your/data:/workspace/data \
  ubdc/ptai-analysis r
```

### Option 2: Docker Compose (Recommended)

#### Setup
```bash
# Copy environment template
cp .env.example .env

# Edit .env to set your data paths
nano .env
```

#### Run Analysis
```bash
# Run complete analysis
docker-compose up ptai-analysis

# Run in background
docker-compose up -d ptai-analysis

# View logs
docker-compose logs -f ptai-analysis
```

#### Interactive Development
```bash
# Start interactive container
docker-compose up -d ptai-interactive

# Connect to container
docker-compose exec ptai-interactive bash

# Or run specific commands
docker-compose exec ptai-interactive R
```

#### RStudio Server (Optional)
```bash
# Start RStudio Server
docker-compose --profile rstudio up -d ptai-rstudio

# Access at http://localhost:8787
# Username: rstudio (no password required)
```

## Volume Mounts

### Required Mounts
- **Data**: `/workspace/data` (read-only recommended)
  - Mount your local data directory here
  - Contains all input datasets

### Output Mounts
- **Results**: `/workspace/output`
  - Accessibility indicators and CSV files
- **Plots**: `/workspace/plots`
  - Generated visualizations
- **Logs**: `/workspace/logs`
  - Execution logs and debug information

## Environment Variables

Set in `.env` file or pass with `-e`:

```bash
# Time zone
TZ=Europe/London

# R package repository
R_REPOS=https://cran.rstudio.com

# Resource limits (Docker Compose only)
PTAI_MEMORY_LIMIT=8G
PTAI_CPU_LIMIT=4
```

## Container Modes

The `docker_entrypoint.sh` supports multiple modes:

### Analysis Mode (Default)
```bash
docker run ubdc/ptai-analysis analysis
# or
docker run ubdc/ptai-analysis run
```
- Runs complete analysis pipeline
- Validates environment first
- Requires data to be mounted

### Validation Mode
```bash
docker run ubdc/ptai-analysis validate
```
- Checks R packages and data availability
- Useful for debugging setup issues

### Interactive Mode
```bash
docker run -it ubdc/ptai-analysis interactive
```
- Starts bash session
- Full access to container environment
- Useful for debugging and development

### R Session Mode
```bash
docker run -it ubdc/ptai-analysis r
```
- Starts R session directly
- Useful for package testing and debugging

## Resource Requirements

### Minimum Requirements
- **RAM**: 4GB
- **CPU**: 2 cores
- **Disk**: 10GB free space
- **Network**: Internet access for package installation

### Recommended Specifications
- **RAM**: 8GB or more
- **CPU**: 4+ cores
- **Disk**: 20GB+ free space
- **SSD**: Recommended for better I/O performance

## Troubleshooting

### Common Issues

1. **Out of Memory Errors**
   ```bash
   # Increase Docker memory limit
   docker run --memory=8g ubdc/ptai-analysis
   ```

2. **Permission Issues**
   ```bash
   # Fix ownership of output files
   sudo chown -R $USER:$USER output/
   ```

3. **Data Not Found**
   ```bash
   # Check data mount
   docker run -it ubdc/ptai-analysis bash
   ls -la /workspace/data/
   ```

4. **Package Installation Failures**
   ```bash
   # Rebuild image with --no-cache
   docker build --no-cache -t ubdc/ptai-analysis .
   ```

### Debug Mode
```bash
# Run with debug output
docker run -e DEBUG=1 ubdc/ptai-analysis

# Check container logs
docker logs <container_id>

# Access container for debugging
docker exec -it <container_id> bash
```

## Common Build Issues and Solutions

### DevTools Package Installation Error

**Issue**: `Error in loadNamespace(x) : there is no package called 'devtools'`

**Cause**: Docker layers don't persist R package state between separate RUN commands

**Solution**: We've consolidated all R package installations into a single RUN command in the Dockerfile. This ensures that `devtools` is available when installing the GitHub package `AccessUK`.

**Technical Details**:
- All packages are installed in dependency order within one RUN command
- Environment variables are properly referenced using `Sys.getenv()`
- Package installation is verified after completion
- GitHub package installation includes dependencies

### Build Performance Tips

1. **Use Docker BuildKit**: `DOCKER_BUILDKIT=1 docker build ...`
2. **Layer Caching**: Avoid `--no-cache` unless necessary
3. **Multi-stage Builds**: Separate build and runtime environments
4. **Resource Limits**: Allocate sufficient memory for R package compilation

## Building Custom Images

### Modify Dockerfile
```dockerfile
# Add custom packages
RUN R -e "install.packages('your_package')"

# Add system dependencies
RUN apt-get update && apt-get install -y your-package
```

### Build with Custom Tag
```bash
docker build -t your-org/ptai-analysis:custom .
```

## Performance Optimization

### Multi-stage Build (Advanced)
- Separate build and runtime stages
- Reduces final image size
- Faster container startup

### Parallel Processing
```bash
# Use multiple CPU cores
docker run --cpus=4 ubdc/ptai-analysis
```

### Memory Management
```bash
# Set memory limits
docker run --memory=8g --memory-swap=16g ubdc/ptai-analysis
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run PTAI Analysis
  run: |
    docker build -t ptai-analysis .
    docker run -v ${{ github.workspace }}/data:/workspace/data:ro \
               -v ${{ github.workspace }}/output:/workspace/output \
               ptai-analysis
```

### Automated Testing
```bash
# Test environment setup
docker run ubdc/ptai-analysis validate

# Run with sample data
docker run -v ./test_data:/workspace/data:ro ubdc/ptai-analysis
```

## Security Considerations

- Data volumes mounted as read-only when possible
- Non-root user execution
- Minimal base image
- Regular security updates

## Support

For Docker-specific issues:
1. Check container logs: `docker logs <container_id>`
2. Validate environment: `docker run ubdc/ptai-analysis validate`
3. Test interactively: `docker run -it ubdc/ptai-analysis bash`
4. Review Docker documentation: https://docs.docker.com/
