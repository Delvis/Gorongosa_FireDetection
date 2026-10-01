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

# Load archive data
arch <- load_viirs_archive(2017, 2025)

# Harmonize NRT data
nrt_part1 <- nrt_part1 %>% mutate(
  acq_time = as.character(acq_time),
  version  = as.character(version)
)
nrt_part2 <- nrt_part2 %>% mutate(
  acq_time = as.character(acq_time),
  version  = as.character(version)
)
nrt <- bind_rows(nrt_part1, nrt_part2)

# Merge datasets and prepare SF points
fires_all <- combine_viirs(arch, nrt)
fires_sf  <- prepare_fires_sf(fires_all) %>%
  mutate(acq_date = as.Date(acq_date))

# Load regions and extract C12 shapefile boundary
regions_list <- load_viirs_regions()
c12_boundary <- regions_list[["C12"]]

# -------------------------------
# 2. FILTER FIRES WITHIN C12
# -------------------------------

# Spatial intersection to isolate fires strictly within C12
c12_fires_sf <- st_filter(fires_sf, c12_boundary)

# Extract tabular coordinates for 2D density mapping
c12_fires_df <- c12_fires_sf %>%
  mutate(
    longitude = st_coordinates(.)[, 1],
    latitude  = st_coordinates(.)[, 2],
    year      = year(acq_date)
  ) %>%
  st_drop_geometry() %>%
  filter(year >= 2017 & year <= 2025) # Exclude 2026 or partial years

# -------------------------------
# 3. SPATIAL HEATMAP PLOT
# -------------------------------

p_heatmap <- ggplot() +
  # Heatmap layer: 2D kernel density filled with heat color scale
  stat_density_2d(
    data = c12_fires_df,
    aes(x = longitude, y = latitude, fill = after_stat(level)),
    geom = "polygon",
    alpha = 0.85,
    bins = 15
  ) +
  # Custom fire intensity color gradient (black background to bright red/yellow)
  scale_fill_viridis_c(
    option = "magma",
    name = "Fire Density"
  ) +
  # Overlay individual fire detection points
  geom_point(
    data = c12_fires_df,
    aes(x = longitude, y = latitude),
    color = "white",
    size = 0.2,
    alpha = 0.3
  ) +
  # Overlay C12 polygon boundary line
  geom_sf(
    data = c12_boundary,
    fill = NA,
    color = "cyan",
    linewidth = 0.8
  ) +
  labs(
    title = "Coutada 12 Spatial Fire Density Heatmap",
    subtitle = "Aggregated VIIRS Fire Detections (2017–2026)",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.background = element_rect(fill = "#111111", color = NA), # Dark background highlights heatmaps
    plot.background  = element_rect(fill = "#111111", color = NA),
    panel.grid       = element_line(color = "#222222"),
    text             = element_text(color = "white"),
    axis.text        = element_text(color = "gray80"),
    legend.position  = "right"
  )

print(p_heatmap)

# -------------------------------
# 4. SAVE PLOT
# -------------------------------
dir.create("plots", showWarnings = FALSE)
ggsave(
  "plots/c12_fire_density_heatmap.png",
  plot = p_heatmap,
  width = 10,
  height = 8,
  dpi = 300
)
