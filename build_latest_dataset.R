# ============================================================
# Build VIIRS datasets (archive / NRT / yearly / latest)
# ============================================================

library(dplyr)
library(lubridate)
library(sf)

options(stringsAsFactors = FALSE)

# -------------------------------
# USER CONTROL
# -------------------------------

mode <- "year"
# options:
# "latest"  → archive + NRT
# "archive" → archive only
# "year"    → specific year
# "nrt"     → NRT only

target_year <- 2025   # only used if mode == "year"

archive_start_year <- 2017
archive_end_year   <- 2025

nrt_file <- "fires_moz_current_year/2026_fire_nrt.csv"

cache_dir <- "cache"

# -------------------------------
# Load pipeline functions
# -------------------------------

source("R/viirs_archive.R")
source("R/viirs_nrt.R")
source("R/viirs_combine.R")
source("R/viirs_sf.R")

dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

# -------------------------------
# Load datasets
# -------------------------------

message("Loading archive...")
arch <- load_viirs_archive(
  archive_start_year,
  archive_end_year
)

message("Loading NRT...")
nrt <- load_viirs_nrt(nrt_file)

# -------------------------------
# Build dataset depending on mode
# -------------------------------

if (mode == "archive") {
  
  message("Mode: ARCHIVE")
  fires <- arch
  outfile <- file.path(cache_dir, "fires_archive_sf.rds")
  
} else if (mode == "nrt") {
  
  message("Mode: NRT only")
  fires <- nrt
  outfile <- file.path(cache_dir, "fires_nrt_sf.rds")
  
} else if (mode == "latest") {
  
  message("Mode: ARCHIVE + NRT")
  fires <- combine_viirs(arch, nrt)
  outfile <- file.path(cache_dir, "fires_latest_sf.rds")
  
} else if (mode == "year") {
  
  message("Mode: SINGLE YEAR → ", target_year)
  
  fires_all <- combine_viirs(arch, nrt)
  
  fires <- fires_all %>%
    mutate(
      acq_date = as.character(acq_date),
      date = ymd(acq_date)
    ) %>%
    filter(year(date) == target_year)
  
  if (nrow(fires) == 0) {
    stop("No detections found for year ", target_year)
  }
  
  outfile <- file.path(
    cache_dir,
    paste0("fires_", target_year, "_sf.rds")
  )
  
} else {
  stop("Unknown mode selected.")
}

# -------------------------------
# Convert to sf
# -------------------------------

message("Preparing sf object...")
fires_sf <- prepare_fires_sf(fires)

# -------------------------------
# Save output
# -------------------------------

saveRDS(fires_sf, outfile, compress = "xz")

message("Saved dataset: ", outfile)
message("Rows: ", nrow(fires_sf))
