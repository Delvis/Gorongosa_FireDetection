prepare_fires_sf <- function(fires) {
  
  fires %>%
    dplyr::mutate(acq_date = as.character(acq_date)) %>%
    dplyr::mutate(date = lubridate::ymd(acq_date)) %>%
    dplyr::filter(!is.na(date)) %>%
    sf::st_as_sf(coords = c("longitude","latitude"),
                 crs = 4326,
                 remove = FALSE) %>%
    dplyr::mutate(
      year = lubridate::year(date),
      month_date = lubridate::floor_date(date, "month"),
      month = lubridate::month(month_date, label = TRUE, abbr = FALSE),
      quarter = paste0(year, "-Q", lubridate::quarter(date))
    )
}
