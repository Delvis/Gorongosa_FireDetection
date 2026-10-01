library(dplyr)
library(ggplot2)
library(sf)
library(lubridate)

# -------------------------------
# 0. LOAD PIPELINE FUNCTIONS
# -------------------------------
source("R/viirs_archive.R")
source("R/viirs_nrt.R")
source("R/viirs_combine.R")
source("R/viirs_regions.R")
source("R/viirs_summary.R")
source("R/viirs_sf.R")

# -------------------------------
# 1. LOAD DATA & EXTRACT C12 BOUNDARY
# -------------------------------

arch <- load_viirs_archive(2017, 2025)

nrt_part1 <- nrt_part1 %>% mutate(acq_time = as.character(acq_time), version = as.character(version))
nrt_part2 <- nrt_part2 %>% mutate(acq_time = as.character(acq_time), version = as.character(version))
nrt <- bind_rows(nrt_part1, nrt_part2)

fires_all <- combine_viirs(arch, nrt)
fires_sf  <- prepare_fires_sf(fires_all) %>%
  mutate(acq_date = as.Date(acq_date))

regions_list <- load_viirs_regions()
c12_boundary <- regions_list[["C12"]]

# -------------------------------
# 2. FILTER FIRES & PREPARE GRID DATA
# -------------------------------

c12_fires_sf <- st_filter(fires_sf, c12_boundary)

c12_fires_df <- c12_fires_sf %>%
  mutate(
    longitude = st_coordinates(.)[, 1],
    latitude  = st_coordinates(.)[, 2],
    year      = year(acq_date)
  ) %>%
  st_drop_geometry() %>%
  filter(year >= 2017 & year <= 2025)

# -------------------------------
# 3. SIMPLE GRID CELL COUNT PLOT
# -------------------------------

# Define grid cell resolution (bins = 50x50 grid over C12 extent)
p_grid <- ggplot() +
  # Grid binning layer: aggregates points into cells and counts them
  stat_bin_2d(
    data = c12_fires_df,
    aes(x = longitude, y = latitude, fill = after_stat(count)),
    bins = 50,           # Adjust number of bins across long/lat to change cell size
    color = "white",      # Subtle grid lines between cells
    linewidth = 0.05
  ) +
  # Orange color scale on white background
  scale_fill_gradient(
    low = "#ffed4a",     # Soft yellow-orange for low counts
    high = "#d35400",    # Deep red-orange for high counts
    name = "Fire Count"
  ) +
  # C12 Polygon boundary line
  geom_sf(
    data = c12_boundary,
    fill = NA,
    color = "black",
    linewidth = 0.8
  ) +
  labs(
    title = "Coutada 12 Fire Count per Grid Cell",
    subtitle = "Aggregated VIIRS Fire Detections (2017–2026)",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background  = element_rect(fill = "white", color = NA),
    panel.grid       = element_line(color = "gray92"),
    text             = element_text(color = "black"),
    legend.position  = "right"
  )

print(p_grid)

# -------------------------------
# 4. SAVE PLOT
# -------------------------------
dir.create("plots", showWarnings = FALSE)
ggsave(
  "plots/c12_fire_grid_count_white.png",
  plot = p_grid,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)
