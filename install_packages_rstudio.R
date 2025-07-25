#!/usr/bin/env Rscript

# install_packages_rstudio.R - Install all required R packages for RStudio environment
# This script is used during Docker build to install packages with proper error handling

# Set options for better error reporting
options(repos = 'https://cran.rstudio.com')
options(timeout = 300)
options(download.file.method = 'libcurl')

# Function to install packages with error handling
install_safe <- function(packages, from_github = FALSE) {
  for (pkg in packages) {
    cat('Installing', pkg, '...\n')
    tryCatch({
      if (from_github) {
        devtools::install_github(pkg, dependencies = TRUE, upgrade = 'never')
      } else {
        install.packages(pkg, dependencies = TRUE)
      }
      cat('✓', pkg, 'installed successfully\n')
    }, error = function(e) {
      cat('✗ Failed to install', pkg, ':', e$message, '\n')
      stop(paste('Package installation failed for:', pkg))
    })
  }
}

# Install development tools first
cat('=== Installing development tools ===\n')
install_safe(c('devtools', 'remotes'))

# Install graphics dependencies first (required for kableExtra)
cat('=== Installing graphics dependencies ===\n')
install_safe(c('svglite', 'Cairo'))

# Install core packages
cat('=== Installing core packages ===\n')
install_safe(c('tidyverse', 'data.table', 'readr', 'dplyr', 'ggplot2', 'purrr', 'stringr', 'lubridate'))

# Install spatial packages
cat('=== Installing spatial packages ===\n')
install_safe(c('sf', 'sp', 'rgdal', 'rgeos', 'raster'))

# Install mapping packages
cat('=== Installing mapping packages ===\n')
install_safe(c('mapview', 'leaflet', 'htmlwidgets'))

# Install OpenStreetMap packages
cat('=== Installing OSM packages ===\n')
install_safe(c('osmdata', 'httr', 'jsonlite'))

# Install utility packages
cat('=== Installing utility packages ===\n')
install_safe(c('fs', 'here', 'glue'))

# Install document packages (with dependencies resolved)
cat('=== Installing document packages ===\n')
install_safe(c('knitr', 'rmarkdown', 'kableExtra', 'rticles'))

# Install AccessUK package from GitHub (optional - may fail due to network issues)
cat('=== Installing AccessUK from GitHub ===\n')
cat('Note: This package will be installed if possible, but build will continue if it fails\n')

# Try to install AccessUK with multiple fallback strategies
accessuk_installed <- tryCatch({
  # First try with remotes
  remotes::install_github('urbanbigdatacentre/AccessUK', dependencies = TRUE, upgrade = 'never', force = TRUE)
  TRUE
}, error = function(e1) {
  cat('First attempt failed, trying with devtools...\n')
  tryCatch({
    devtools::install_github('urbanbigdatacentre/AccessUK', dependencies = TRUE, upgrade = 'never', force = TRUE)
    TRUE
  }, error = function(e2) {
    cat('GitHub installation failed, trying alternative approach...\n')
    tryCatch({
      # Try installing from a specific commit or branch if main fails
      devtools::install_github('urbanbigdatacentre/AccessUK@main', dependencies = TRUE, upgrade = 'never')
      TRUE
    }, error = function(e3) {
      cat('⚠️ AccessUK installation failed. This is often due to:\n')
      cat('   - Network connectivity issues\n')
      cat('   - GitHub API rate limiting\n')
      cat('   - Repository access issues\n')
      cat('   Continuing build without AccessUK...\n')
      FALSE
    })
  })
})

if (accessuk_installed) {
  cat('✓ AccessUK installed successfully\n')
} else {
  cat('⚠️ AccessUK not installed - you may need to install it manually later\n')
}

# Verify critical packages
cat('=== Verifying installation ===\n')
library(tidyverse)
library(sf)

# Try to load AccessUK if it was installed
accessuk_available <- tryCatch({
  library(AccessUK)
  TRUE
}, error = function(e) {
  cat('AccessUK not available - this is okay for basic functionality\n')
  FALSE
})

# Show package versions
cat('✅ Core packages installed successfully!\n')
cat('📦 Package versions:\n')
cat('  - tidyverse:', as.character(packageVersion('tidyverse')), '\n')
cat('  - sf:', as.character(packageVersion('sf')), '\n')
if (accessuk_available) {
  cat('  - AccessUK:', as.character(packageVersion('AccessUK')), '\n')
} else {
  cat('  - AccessUK: Not installed (can be installed manually later)\n')
}
cat('🎉 RStudio environment ready!\n')
