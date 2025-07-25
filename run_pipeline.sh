#!/bin/bash

################################################################################
#                                                                              #
#        GREAT BRITAIN ACCESSIBILITY INDICATORS 2023 - BASH RUNNER           #
#                                                                              #
#  This script sets up the environment and runs the R analysis pipeline       #
#                                                                              #
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

echo "================================================================================"
echo "        GREAT BRITAIN ACCESSIBILITY INDICATORS 2023 - PIPELINE RUNNER        "
echo "================================================================================"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================================"

# Check if we're in the right directory
if [ ! -f "accessibility_indices23.Rproj" ]; then
    print_error "accessibility_indices23.Rproj not found. Please run this script from the project root directory."
    exit 1
fi

print_success "Found R project file"

# Check if R is installed
if ! command -v R &> /dev/null; then
    print_error "R is not installed or not in PATH"
    exit 1
fi

print_success "R is available: $(R --version | head -n1)"

# Check for required directories
print_status "Checking directory structure..."

required_dirs=("R" "data" "output" "plots")
missing_dirs=()

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -ne 0 ]; then
    print_warning "Creating missing directories: ${missing_dirs[*]}"
    for dir in "${missing_dirs[@]}"; do
        mkdir -p "$dir"
        print_success "Created directory: $dir"
    done
fi

# Check for data files (basic check)
print_status "Checking for data availability..."

if [ ! "$(ls -A data/ 2>/dev/null)" ]; then
    print_warning "Data directory is empty. Make sure to download and place required datasets."
    print_warning "See README.md for data requirements."
fi

# Check for R scripts
print_status "Checking for R scripts..."

r_scripts=(
    "R/01_gp_practice.r"
    "R/02_supermarkets.r"
    "R/03_employment.R"
    "R/04_schools.r"
    "R/05_urban_centre.r"
    "R/06_hospitals.r"
    "R/07_pharmacies.r"
    "R/08_parks_gardens.R"
    "R/09_aggregate_services.R"
    "R/10_estimate_accessibility.R"
    "R/11_exploratory.R"
    "R/12_destination_summary.R"
    "R/13_file_inventory.R"
)

missing_scripts=()
for script in "${r_scripts[@]}"; do
    if [ ! -f "$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -ne 0 ]; then
    print_error "Missing R scripts: ${missing_scripts[*]}"
    exit 1
fi

print_success "All R scripts found"

# Create a backup of existing output
if [ -d "output" ] && [ "$(ls -A output/)" ]; then
    backup_dir="output_backup_$(date '+%Y%m%d_%H%M%S')"
    print_status "Backing up existing output to $backup_dir"
    cp -r output "$backup_dir"
    print_success "Backup created"
fi

# Run the main R script
print_status "Starting R analysis pipeline..."
echo "================================================================================"

start_time=$(date +%s)

# Run the master R script
if R --vanilla < run_analysis.R; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    print_success "R analysis pipeline completed successfully!"
    print_success "Total execution time: ${minutes}m ${seconds}s"
    
    # Check outputs
    if [ -d "output" ] && [ "$(ls -A output/)" ]; then
        print_success "Output files generated in 'output/' directory"
        print_status "Output file count: $(find output -type f | wc -l)"
    fi
    
    if [ -d "plots" ] && [ "$(ls -A plots/)" ]; then
        print_success "Plot files available in 'plots/' directory"
        print_status "Plot file count: $(find plots -type f | wc -l)"
    fi
    
    # Show execution log if available
    log_file=$(find output -name "execution_log_*.csv" | head -n1)
    if [ -n "$log_file" ]; then
        print_success "Execution log saved: $log_file"
        
        # Show summary from log if R is available
        echo ""
        print_status "Execution Summary:"
        echo "================================================================================"
        R --slave --vanilla -e "
        library(readr)
        log <- read_csv('$log_file', show_col_types = FALSE)
        cat('Total steps:', nrow(log), '\n')
        cat('Successful steps:', sum(log\$status == 'SUCCESS'), '\n')
        cat('Failed steps:', sum(log\$status == 'FAILED'), '\n')
        if(sum(log\$status == 'FAILED') > 0) {
          cat('\nFailed steps:\n')
          failed <- log[log\$status == 'FAILED',]
          for(i in 1:nrow(failed)) {
            cat('  -', failed\$description[i], '\n')
          }
        }
        cat('Total duration:', round(sum(log\$duration_minutes), 2), 'minutes\n')
        "
    fi
    
else
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    print_error "R analysis pipeline failed after ${minutes}m ${seconds}s"
    print_error "Check the error messages above for details"
    exit 1
fi

echo "================================================================================"
echo "                                 COMPLETED                                     "
echo "================================================================================"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"

print_status "Next steps:"
echo "  1. Check output/ directory for accessibility indicators"
echo "  2. Check plots/ directory for visualizations"
echo "  3. Review execution log for detailed timing information"
echo "  4. Refer to README.md for interpretation of results"

echo "================================================================================"
