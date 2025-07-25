#!/usr/bin/env Rscript

################################################################################
#                                                                              #
#        GREAT BRITAIN ACCESSIBILITY INDICATORS 2023 - MASTER SCRIPT          #
#                                                                              #
#  This script runs all analysis steps in the correct order and logs progress #
#                                                                              #
################################################################################

# Master script to run all accessibility analysis steps
# Created: 2025-07-23
# Author: Automated script generator

# Load required libraries for logging
library(tidyverse)

# Create log function
log_step <- function(step_number, step_name, status = "START") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  message(sprintf("[%s] STEP %02d - %s: %s", timestamp, step_number, step_name, status))
}

# Create error handling function
safe_source <- function(script_path, step_number, step_name) {
  log_step(step_number, step_name, "START")
  
  tryCatch({
    source(script_path)
    log_step(step_number, step_name, "COMPLETED")
    return(TRUE)
  }, error = function(e) {
    log_step(step_number, step_name, paste("ERROR:", e$message))
    return(FALSE)
  })
}

# Initialize execution log
execution_log <- data.frame(
  step = integer(),
  script = character(),
  description = character(),
  start_time = character(),
  end_time = character(),
  status = character(),
  duration_minutes = numeric(),
  stringsAsFactors = FALSE
)

# Function to add to execution log
add_to_log <- function(step, script, description, start_time, end_time, status) {
  duration <- as.numeric(difftime(end_time, start_time, units = "mins"))
  
  execution_log <<- rbind(execution_log, data.frame(
    step = step,
    script = script,
    description = description,
    start_time = format(start_time, "%Y-%m-%d %H:%M:%S"),
    end_time = format(end_time, "%Y-%m-%d %H:%M:%S"),
    status = status,
    duration_minutes = round(duration, 2)
  ))
}

################################################################################
#                               MAIN EXECUTION                                #
################################################################################

cat("================================================================================\n")
cat("        GREAT BRITAIN ACCESSIBILITY INDICATORS 2023 - ANALYSIS PIPELINE       \n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("R version:", R.version.string, "\n")
cat("Working directory:", getwd(), "\n")
cat("================================================================================\n\n")

# Check if required directories exist
required_dirs <- c("R", "data", "output", "plots")
missing_dirs <- required_dirs[!dir.exists(required_dirs)]

if (length(missing_dirs) > 0) {
  cat("Creating missing directories:", paste(missing_dirs, collapse = ", "), "\n")
  sapply(missing_dirs, dir.create, recursive = TRUE)
}

# Define all analysis steps
analysis_steps <- list(
  list(step = 1, script = "R/01_gp_practice.r", desc = "Process GP practices data"),
  list(step = 2, script = "R/02_supermarkets.r", desc = "Process supermarkets data (OpenStreetMap)"),
  list(step = 3, script = "R/03_employment.R", desc = "Process employment data"),
  list(step = 4, script = "R/04_schools.r", desc = "Process schools data"),
  list(step = 5, script = "R/05_urban_centre.r", desc = "Process urban centres data"),
  list(step = 6, script = "R/06_hospitals.r", desc = "Process hospitals data"),
  list(step = 7, script = "R/07_pharmacies.r", desc = "Process pharmacies data"),
  list(step = 8, script = "R/08_parks_gardens.R", desc = "Process parks and gardens data"),
  list(step = 9, script = "R/09_aggregate_services.R", desc = "Aggregate all services at LSOA/DZ level"),
  list(step = 10, script = "R/10_estimate_accessibility.R", desc = "Estimate accessibility indicators (MAIN ANALYSIS)"),
  list(step = 11, script = "R/11_exploratory.R", desc = "Exploratory data analysis"),
  list(step = 12, script = "R/12_destination_summary.R", desc = "Create destination summary"),
  list(step = 13, script = "R/13_file_inventory.R", desc = "Generate file inventory")
)

# Execute all steps
total_steps <- length(analysis_steps)
successful_steps <- 0
failed_steps <- 0

for (i in seq_along(analysis_steps)) {
  step_info <- analysis_steps[[i]]
  
  cat(sprintf("\n[%d/%d] %s\n", i, total_steps, step_info$desc))
  cat(sprintf("Script: %s\n", step_info$script))
  cat("----------------------------------------\n")
  
  # Check if script exists
  if (!file.exists(step_info$script)) {
    cat("ERROR: Script file not found!\n")
    add_to_log(step_info$step, step_info$script, step_info$desc, 
               Sys.time(), Sys.time(), "FILE_NOT_FOUND")
    failed_steps <- failed_steps + 1
    next
  }
  
  # Execute step with timing
  start_time <- Sys.time()
  success <- safe_source(step_info$script, step_info$step, step_info$desc)
  end_time <- Sys.time()
  
  # Log results
  status <- if (success) "SUCCESS" else "FAILED"
  add_to_log(step_info$step, step_info$script, step_info$desc, 
             start_time, end_time, status)
  
  if (success) {
    successful_steps <- successful_steps + 1
  } else {
    failed_steps <- failed_steps + 1
  }
  
  # Show duration
  duration <- difftime(end_time, start_time, units = "mins")
  cat(sprintf("Duration: %.2f minutes\n", as.numeric(duration)))
  
  # Memory cleanup between steps
  if (i %% 3 == 0) {
    cat("Performing garbage collection...\n")
    gc()
  }
}

################################################################################
#                               FINAL SUMMARY                                 #
################################################################################

pipeline_end_time <- Sys.time()
total_duration <- difftime(pipeline_end_time, 
                          as.POSIXct(execution_log$start_time[1]), 
                          units = "mins")

cat("\n================================================================================\n")
cat("                               EXECUTION SUMMARY                               \n")
cat("================================================================================\n")
cat("End time:", format(pipeline_end_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Total duration:", sprintf("%.2f minutes (%.2f hours)", 
                               as.numeric(total_duration), 
                               as.numeric(total_duration)/60), "\n")
cat("Successful steps:", successful_steps, "/", total_steps, "\n")
cat("Failed steps:", failed_steps, "/", total_steps, "\n")

if (failed_steps > 0) {
  cat("\nFAILED STEPS:\n")
  failed_steps_df <- execution_log[execution_log$status == "FAILED", ]
  for (i in 1:nrow(failed_steps_df)) {
    cat(sprintf("  - Step %d: %s\n", failed_steps_df$step[i], failed_steps_df$description[i]))
  }
}

cat("\n================================================================================\n")

# Save execution log
log_filename <- sprintf("execution_log_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
write_csv(execution_log, file.path("output", log_filename))
cat("Execution log saved to:", file.path("output", log_filename), "\n")

# Create summary statistics
if (nrow(execution_log) > 0) {
  cat("\nSTEP DURATION SUMMARY:\n")
  cat("  Fastest step:", sprintf("%.2f minutes (Step %d: %s)", 
                                 min(execution_log$duration_minutes),
                                 execution_log$step[which.min(execution_log$duration_minutes)],
                                 execution_log$description[which.min(execution_log$duration_minutes)]), "\n")
  cat("  Slowest step:", sprintf("%.2f minutes (Step %d: %s)", 
                                 max(execution_log$duration_minutes),
                                 execution_log$step[which.max(execution_log$duration_minutes)],
                                 execution_log$description[which.max(execution_log$duration_minutes)]), "\n")
  cat("  Average step duration:", sprintf("%.2f minutes", mean(execution_log$duration_minutes)), "\n")
}

# Final status
if (failed_steps == 0) {
  cat("\n🎉 ALL STEPS COMPLETED SUCCESSFULLY! 🎉\n")
  cat("Check the 'output/' directory for accessibility indicators.\n")
  cat("Check the 'plots/' directory for visualizations.\n")
} else {
  cat("\n⚠️  PIPELINE COMPLETED WITH ERRORS ⚠️\n")
  cat("Please review the failed steps and check data availability.\n")
}

cat("================================================================================\n")

# Return the execution log for further analysis if needed
invisible(execution_log)
