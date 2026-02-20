# viirs_summary.R
# Helper functions to summarize VIIRS fire data by month, quarter, and region

# Load required libraries once
library(dplyr)
library(sf)
library(lubridate)

# --------------------------------------------------------------------------------
# Function: Summarize monthly fires by individual regions (with FRP stats)
# --------------------------------------------------------------------------------
summarize_monthly_regions <- function(fires_sf, regions) {
  
  summarize_region <- function(region_sf, region_name) {
    
    clipped <- suppressWarnings(st_intersection(fires_sf, region_sf))
    
    if (nrow(clipped) == 0) return(tibble())
    
    st_drop_geometry(clipped) %>%
      mutate(
        month_date = floor_date(acq_date, "month"),
        month = month(month_date, label = TRUE, abbr = FALSE),
        year = year(acq_date)
      ) %>%
      group_by(year, month) %>%
      summarise(
        n_fires = n(),
        mean_frp = mean(frp, na.rm = TRUE),
        sum_frp = sum(frp, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(region = region_name)
  }
  
  bind_rows(lapply(names(regions), function(nm) summarize_region(regions[[nm]], nm)))
}

# --------------------------------------------------------------------------------
# Function: Summarize quarterly fires by individual regions (with FRP stats)
# --------------------------------------------------------------------------------
# R/viirs_summary.R

summarize_quarterly_regions <- function(fires_sf, regions_list) {
  
  # 1. Combine all regions into one SF object (Standardized)
  regions_sf <- do.call(rbind, lapply(names(regions_list), function(nm) {
    r <- regions_list[[nm]]
    data.frame(region = nm, geometry = st_geometry(r)) %>% 
      st_as_sf(crs = st_crs(r))
  }))
  
  # 2. Convert acq_date to Date object once to avoid repetition
  fires_sf <- fires_sf %>%
    mutate(acq_date = lubridate::as_date(acq_date))
  
  # 3. Perform a single Spatial Join (much faster than intersection loop)
  # This matches points to region names
  fires_joined <- st_join(fires_sf, regions_sf, join = st_intersects)
  
  # 4. Summarize the joined data
  fires_joined %>%
    st_drop_geometry() %>%
    filter(!is.na(region)) %>% # Exclude fires outside your 3 regions
    mutate(
      year = year(acq_date),
      quarter = quarter(acq_date)
    ) %>%
    group_by(region, year, quarter) %>%
    summarise(
      n_fires = n(),
      mean_frp = mean(frp, na.rm = TRUE),
      sum_frp = sum(frp, na.rm = TRUE),
      .groups = "drop"
    )
}
# --------------------------------------------------------------------------------
# Function: Build monthly fire summary for all regions (count only)
# --------------------------------------------------------------------------------
build_monthly_summary <- function(fires_sf, regions_list) {
  
  # Fix: Select only the geometry and create a standardized 'region' column
  # This prevents the 'numbers of columns do not match' error
  regions_sf <- do.call(rbind, lapply(names(regions_list), function(nm) {
    r <- regions_list[[nm]]
    # Keep only the geometry and add the region label
    data.frame(region = nm, geometry = st_geometry(r)) %>% 
      st_as_sf(crs = st_crs(r))
  }))
  
  fires_sf <- fires_sf %>%
    mutate(
      year = lubridate::year(acq_date),
      month = lubridate::month(acq_date, label = TRUE, abbr = FALSE)
    )
  
  # Spatial join: assign fires to regions
  fires_joined <- st_join(fires_sf, regions_sf)
  
  fires_joined %>%
    st_drop_geometry() %>%
    filter(!is.na(region)) %>% # Only keep fires that actually fell in a region
    group_by(region, year, month) %>%
    summarise(
      n_fires = n(),
      .groups = "drop"
    )
}