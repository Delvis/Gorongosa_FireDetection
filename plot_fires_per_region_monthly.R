library(ggplot2)
library(dplyr)
library(sf)
library(lubridate)

# -------------------------------
# 0. DATASET SELECTION & SOURCES
# -------------------------------
# Fix: Ensure paths to R scripts are correct relative to project root
source("R/viirs_regions.R")
source("R/viirs_summary.R")

plot_year <- 2025
fires_file <- paste0("cache/fires_", plot_year, "_sf.rds")

if (!file.exists(fires_file)) stop("Cache file not found: ", fires_file)
fires_sf <- readRDS(fires_file)

# -------------------------------
# 1. Load regions
# -------------------------------
# returns a named list of sf objects
regions_list <- load_viirs_regions()

# -------------------------------
# 2. Build monthly summary
# -------------------------------
# This function handles the list-to-sf conversion internally
monthly_all <- build_monthly_summary(fires_sf, regions_list)

# -------------------------------
# 3. Region areas (km²)
# -------------------------------
# Fix: Calculate areas from the list elements directly
region_areas <- sapply(regions_list, function(x) {
  as.numeric(st_area(x)) / 1e6
})

# -------------------------------
# 4. Monthly fires per km²
# -------------------------------
monthly_per_km2 <- monthly_all |>
  mutate(
    area_km2 = region_areas[region],
    fires_per_km2 = n_fires / area_km2
  )

# -------------------------------
# 5. Filter & Factor for Plotting
# -------------------------------
plot_data <- monthly_per_km2 |>
  filter(region %in% c("GNP", "Mountain", "Buffer")) |>
  mutate(month = factor(month, levels = month.name)) # Ensure chronological order

# -------------------------------
# 6. Plot
# -------------------------------
p <- ggplot(plot_data,
            aes(x = month, y = fires_per_km2, fill = region)) +
  geom_col(position = "dodge") +
  labs(
    x = plot_year,
    y = "Fires per km²",
    fill = "Region"
  ) +
  theme_minimal(base_size = 14) +
  scale_fill_manual(values = c("GNP" = "#27ae60", 
                               "Mountain" = "#2980b9", 
                               "Buffer" = "#f1c40f")) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )

print(p)

# -------------------------------
# 7. Save plot
# -------------------------------
outfile <- paste0("plots/monthly_fires_per_km2_by_region_", plot_year, ".png")
dir.create("plots", showWarnings = FALSE)

ggsave(outfile, plot = p, width = 10, height = 6, dpi = 300, bg = "white")
message("Saved plot: ", outfile)
