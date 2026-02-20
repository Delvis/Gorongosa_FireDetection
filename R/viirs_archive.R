load_viirs_archive <- function(start_year,
                               end_year,
                               archive_dir = "fire_moz_archive",
                               cache_file = "cache/viirs_archive_clean.rds",
                               force_rebuild = FALSE) {
  
  if (file.exists(cache_file) && !force_rebuild) {
    message("Loading cached archive...")
    return(readRDS(cache_file))
  }
  
  message("Building archive from CSVs...")
  
  years <- seq(start_year, end_year)
  
  files <- file.path(
    archive_dir,
    paste0(years, "_Mozambique_SUOMI_VIIRS_C2.csv")
  )
  
  files <- files[file.exists(files)]
  
  if (length(files) == 0)
    stop("No archive files found.")
  
  library(data.table)
  
  fires <- rbindlist(lapply(files, fread), fill = TRUE)
  
  # minimal cleaning ONLY
  fires <- unique(
    fires,
    by = intersect(
      c("latitude","longitude","acq_date","acq_time","satellite","instrument"),
      names(fires)
    )
  )
  
  dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)
  saveRDS(fires, cache_file, compress = "xz")
  
  message("Archive cached at: ", cache_file)
  
  fires
}
