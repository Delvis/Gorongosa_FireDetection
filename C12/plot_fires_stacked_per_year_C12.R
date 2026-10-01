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
# 1. LOAD & COMBINE DATA IN MEMORY
# -------------------------------

# Load archive data (2017-2025)
arch <- load_viirs_archive(2017, 2025)

# Harmonize NRT columns to prevent type mismatch during bind_rows
nrt_part1 <- nrt_part1 %>% mutate(
  acq_time = as.character(acq_time),
  version  = as.character(version)
)

nrt_part2 <- nrt_part2 %>% mutate(
  acq_time = as.character(acq_time),
  version  = as.character(version)
)

nrt <- bind_rows(nrt_part1, nrt_part2)

# Merge datasets and convert to Spatial Features (sf) object
fires_all <- combine_viirs(arch, nrt)
fires_sf  <- prepare_fires_sf(fires_all) %>%
  mutate(acq_date = as.Date(acq_date))

# Load region shapefiles
regions_list <- load_viirs_regions()

# -------------------------------
# 2. MONTHLY SUMMARY & AREA CALCULATION
# -------------------------------

# Summarize directly using pipeline's monthly aggregation function
monthly_all_years <- summarize_monthly_regions(fires_sf, regions_list)

# Compute surface area in km² for each region (ensure named vector)
region_areas <- vapply(regions_list, function(x) {
  as.numeric(st_area(x)) / 1e6
}, FUN.VALUE = numeric(1))

# -------------------------------
# 3. FORMAT DATA FOR DENSITY PLOT
# -------------------------------
plot_data <- monthly_all_years %>%
  mutate(region = as.character(region)) %>% # Ensure character type for matching
  filter(region %in% c("GNP", "Mountain", "C12", "Buffer")) %>%
  mutate(
    area_km2      = region_areas[region],
    fires_per_km2 = n_fires / area_km2,
    # Convert month numbers (or short names) to ordered full month names
    month         = factor(month.name[as.numeric(month)], levels = month.name),
    # Year as factor for discrete vertical faceting
    year          = factor(year)
  )

# -------------------------------
# 4. MULTI-YEAR VERTICAL STACK PLOT
# -------------------------------
p <- ggplot(plot_data, 
            aes(x = month, y = fires_per_km2, fill = region)) +
  geom_col(position = "dodge") +
  # Top-to-bottom stack by year
  facet_grid(year ~ .) +
  scale_fill_manual(
    values = c(
      "GNP"      = "#27ae60", 
      "Mountain" = "#2980b9",
      "C12"      = "#e67e22",
      "Buffer"   = "#f1c40f"
    ),
    drop = FALSE # Retain C12 in legend even if 0 fires occur in a panel
  ) +
  labs(
    x     = "Month",
    y     = "Fires per km²",
    fill  = "Region",
    title = "Historical Fire Density Comparison"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x      = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    strip.text.y     = element_text(angle = 0, face = "bold"),
    panel.spacing    = unit(0.5, "lines"),
    panel.grid.minor = element_blank()
  )

print(p)

# -------------------------------
# 5. SAVE HIGH-RES OUTPUT
# -------------------------------
num_years <- length(unique(plot_data$year))
outfile   <- "plots/monthly_fires_per_km2_historical_stack_C12.png"
dir.create("plots", showWarnings = FALSE)

# Scale height dynamically: ~1.5 inches per year facet
ggsave(outfile, plot = p, width = 12, height = (1.5 * num_years) + 2, dpi = 360, bg = "white")
