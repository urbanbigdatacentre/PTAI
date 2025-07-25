#!/bin/bash

################################################################################
#                                                                              #
#           DOCKER ENTRYPOINT FOR ACCESSIBILITY INDICATORS ANALYSIS          #
#                                                                              #
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] ✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] ⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] ❌${NC} $1"
}

echo "================================================================================"
echo "    GREAT BRITAIN ACCESSIBILITY INDICATORS 2023 - DOCKER ENVIRONMENT         "
echo "================================================================================"
echo "Container started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Working directory: $(pwd)"
echo "User: $(whoami)"
echo "R version: $(R --version | head -n1)"
echo "================================================================================"

# Function to check data availability
check_data() {
    print_status "Checking data availability..."
    
    if [ ! -d "/workspace/data" ]; then
        print_warning "Data directory not found. Creating..."
        mkdir -p /workspace/data
    fi
    
    if [ ! "$(ls -A /workspace/data/ 2>/dev/null)" ]; then
        print_warning "Data directory is empty!"
        print_warning "Please mount your data directory to /workspace/data"
        print_warning "Example: docker run -v /path/to/your/data:/workspace/data ..."
        return 1
    else
        print_success "Data directory found with $(find /workspace/data -type f | wc -l) files"
        return 0
    fi
}

# Function to validate R packages
validate_packages() {
    print_status "Validating R packages..."
    
    required_packages=(
        "tidyverse"
        "sf" 
        "mapview"
        "osmdata"
        "data.table"
        "fs"
        "kableExtra"
        "AccessUK"
    )
    
    missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! R --slave -e "library($package)" >/dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        print_error "Missing R packages: ${missing_packages[*]}"
        print_error "Please rebuild the Docker image"
        return 1
    else
        print_success "All required R packages are available"
        return 0
    fi
}

# Function to run analysis
run_analysis() {
    print_status "Starting accessibility analysis pipeline..."
    
    # Ensure output directory exists
    mkdir -p /workspace/output /workspace/plots
    
    # Run the analysis
    if [ -f "/workspace/run_analysis.R" ]; then
        print_status "Running R analysis script..."
        cd /workspace
        
        # Capture both stdout and stderr
        if R --vanilla --no-restore --no-save < run_analysis.R 2>&1 | tee /workspace/logs/analysis_$(date '+%Y%m%d_%H%M%S').log; then
            print_success "Analysis completed successfully!"
            
            # Show summary
            if [ -d "/workspace/output" ] && [ "$(ls -A /workspace/output/)" ]; then
                print_success "Generated $(find /workspace/output -type f | wc -l) output files"
            fi
            
            if [ -d "/workspace/plots" ] && [ "$(ls -A /workspace/plots/)" ]; then
                print_success "Generated $(find /workspace/plots -type f | wc -l) plot files"
            fi
            
            return 0
        else
            print_error "Analysis failed. Check logs for details."
            return 1
        fi
    else
        print_error "run_analysis.R not found"
        return 1
    fi
}

# Function to start interactive session
start_interactive() {
    print_status "Starting interactive session..."
    print_status "Available commands:"
    echo "  - run_analysis.R: Run the full analysis pipeline"
    echo "  - R: Start R session"
    echo "  - bash: Start bash session"
    echo "  - ls data/: List data files"
    echo "  - ls output/: List output files"
    exec /bin/bash
}

# Main execution logic
case "${1:-auto}" in
    "analysis"|"run")
        print_status "Mode: Analysis"
        if validate_packages && check_data; then
            run_analysis
        else
            print_error "Prerequisites not met. Exiting."
            exit 1
        fi
        ;;
    "validate")
        print_status "Mode: Validation only"
        validate_packages && check_data
        ;;
    "interactive"|"bash")
        print_status "Mode: Interactive"
        validate_packages
        start_interactive
        ;;
    "r"|"R")
        print_status "Mode: R session"
        validate_packages
        exec R
        ;;
    "help"|"--help")
        echo "Available modes:"
        echo "  analysis|run     : Run the full analysis pipeline (default)"
        echo "  validate         : Validate environment only"
        echo "  interactive|bash : Start interactive bash session"
        echo "  r|R             : Start R session"
        echo "  help            : Show this help"
        ;;
    *)
        print_status "Mode: Auto (analysis if data available, interactive otherwise)"
        if validate_packages; then
            if check_data; then
                run_analysis
            else
                print_warning "No data found. Starting interactive session."
                start_interactive
            fi
        else
            exit 1
        fi
        ;;
esac
