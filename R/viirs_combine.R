combine_viirs <- function(arch, nrt) {
  
  if (nrow(nrt) == 0) return(arch)
  if (nrow(arch) == 0) return(nrt)
  
  missing_in_nrt  <- setdiff(names(arch), names(nrt))
  missing_in_arch <- setdiff(names(nrt), names(arch))
  
  for (col in missing_in_nrt)  nrt[[col]]  <- NA
  for (col in missing_in_arch) arch[[col]] <- NA
  
  common_cols <- intersect(names(arch), names(nrt))
  
  for (col in common_cols) {
    if (class(arch[[col]])[1] != class(nrt[[col]])[1]) {
      arch[[col]] <- as.character(arch[[col]])
      nrt[[col]]  <- as.character(nrt[[col]])
    }
  }
  
  fires_raw <- dplyr::bind_rows(arch, nrt)
  
  dedup_by <- intersect(
    c("latitude","longitude","acq_date","acq_time","satellite","instrument"),
    names(fires_raw)
  )
  
  dplyr::distinct(fires_raw,
                  dplyr::across(all_of(dedup_by)),
                  .keep_all = TRUE)
}
