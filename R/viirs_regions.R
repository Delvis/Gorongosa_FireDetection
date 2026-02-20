# ============================================================
# Load and construct VIIRS analysis regions
# ============================================================

load_viirs_regions <- function(shapefile_dir = "shapefiles") {
  
  library(sf)
  
  options(stringsAsFactors = FALSE)
  
  message("Loading region shapefiles...")
  
  # -------------------------------
  # Load shapefiles
  # -------------------------------
  
  gnp <- st_read(
    file.path(shapefile_dir,
              "gorongosa_boundary_west_straight_utm.shp"),
    quiet = TRUE
  )
  
  # original CRS fix
  st_crs(gnp) <- 32736
  gnp <- st_transform(gnp, 4326)
  
  gorongosa <- st_read(
    file.path(shapefile_dir,
              "gnp_mountain_boundary_latlong.shp"),
    quiet = TRUE
  )
  gorongosa <- st_set_crs(gorongosa, 4326)
  
  total <- st_read(
    file.path(shapefile_dir,
              "gnp_buffer_latlong_2014.shp"),
    quiet = TRUE
  )
  total <- st_set_crs(total, 4326)
  
  # -------------------------------
  # Geometry validation
  # -------------------------------
  
  gnp <- st_make_valid(gnp)
  gorongosa <- st_make_valid(gorongosa)
  total <- st_make_valid(total)
  
  gnp_geom <- st_geometry(gnp)
  gorongosa_geom <- st_geometry(gorongosa)
  total_geom <- st_geometry(total)
  
  # -------------------------------
  # Derived regions
  # -------------------------------
  
  park_and_mtn_geom <- st_union(gnp_geom, gorongosa_geom)
  
  buffer_geom <- st_difference(total_geom, park_and_mtn_geom)
  buffer_only <- st_as_sf(st_sfc(buffer_geom, crs = 4326))
  
  gnp_mountain_geom <- st_union(gnp_geom, gorongosa_geom)
  gnp_mountain <- st_as_sf(st_sfc(gnp_mountain_geom, crs = 4326))
  
  total_area <- st_as_sf(st_sfc(total_geom, crs = 4326))
  
  # -------------------------------
  # Return named list
  # -------------------------------
  
  regions <- list(
    GNP              = gnp,
    Mountain         = gorongosa,
    GNP_and_Mountain = gnp_mountain,
    Buffer           = buffer_only,
    Total            = total_area
  )
  
  message("Regions loaded.")
  
  return(regions)
}
