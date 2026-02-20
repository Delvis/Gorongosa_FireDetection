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
# 1. LOAD QUARTERLY DATA
# -------------------------------

# Load archive (2017-2025) and NRT (2026)
arch <- load_viirs_archive(2017, 2025)
nrt  <- load_viirs_nrt("fires_moz_current_year/2026_fire_nrt.csv")

# Merge and convert to SF
fires_all <- combine_viirs(arch, nrt)
fires_sf  <- prepare_fires_sf(fires_all)

# Load regions list
regions_list <- load_viirs_regions()

# Summarize using the fixed quarterly function
# (Includes the fix for acq_date character vs date error)
quarterly_all_years <- summarize_quarterly_regions(fires_sf, regions_list)

# Keep only needed columns (standardize)
quarterly_all_years <- quarterly_all_years %>%
  select(region, year, quarter, n_fires, mean_frp, sum_frp)


# -------------------------------
# 2. COMPUTE REGION AREAS (km²) 
# -------------------------------

region_areas <- sapply(regions_list, function(x) {
  as.numeric(st_area(x)) / 1e6
})

# add area + fires/km²
q_per_km2 <- quarterly_all_years %>%
  mutate(
    area_km2 = region_areas[region],
    fires_per_km2 = n_fires / area_km2
  )


# -------------------------------
# 3. Filter only 3 main regions
# -------------------------------
plot_data <- q_per_km2 %>%
  filter(region %in% c("GNP", "Mountain", "Buffer")) %>%
  arrange(year, quarter)


# -------------------------------
# 4. QUARTER FACTOR ORDER
# -------------------------------
# ensures Q1–Q4 ordering across years
plot_data$q_label <- paste0(plot_data$year, "-Q", plot_data$quarter)

plot_data$q_label <- factor(
  plot_data$q_label,
  levels = unique(plot_data$q_label)
)


# -------------------------------
# 5. QUARTERLY BAR PLOT
# -------------------------------
ggplot(plot_data, aes(x = q_label, y = fires_per_km2, fill = region)) +
  geom_col(position = "dodge") +
  labs(
    x = "Quarter (2017 → Present)",
    y = "Fires per km²",
    fill = "Region"
  ) +
  theme_minimal(base_size = 14) +
  scale_fill_manual(values = c("GNP" = "#27ae60",
                               "Mountain" = "#2980b9",
                               "Buffer" = "#f1c40f")) +
  theme(
    axis.text.x = element_text(angle = 60, hjust = 1, size = 9),
    legend.position = "bottom"
  )


# -------------------------------
# 6. SAVE PNG
# -------------------------------
ggsave(
  "plots/quarterly_fires_per_km2_by_region_2017_present.png",
  plot = last_plot(),
  device = "png",
  width = 1800,
  height = 900,
  dpi = 300,
  bg = "white",
  units = "px",
  scale = 1.3
)