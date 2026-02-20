load_viirs_nrt <- function(nrt_file) {
  
  if (!file.exists(nrt_file)) {
    message("No NRT file found.")
    return(tibble::tibble())
  }
  
  readr::read_csv(nrt_file, show_col_types = FALSE)
}
