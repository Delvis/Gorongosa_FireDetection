library(ggplot2)
library(dplyr)
library(sf)
library(readr)
library(purrr)

# -------------------------------
# 1. Load Regions & Calculate Areas
# -------------------------------
source("R/viirs_regions.R")
regions_list <- load_viirs_regions()

# Calculate areas in km² for density normalization
region_areas <- sapply(regions_list, function(x) {
  as.numeric(st_area(x)) / 1e6
})

# -------------------------------
# 2. Load and Bind CSVs from Folder
# -------------------------------
csv_folder <- "generated-csv"
# Get all monthly summary files from the specific folder
csv_files <- list.files(path = csv_folder, pattern = "fires_monthly.*\\.csv", full.names = TRUE)

if (length(csv_files) == 0) stop("No CSV files found in: ", csv_folder)

# Combine all years into one data frame
plot_data_all <- csv_files %>%
  map_df(~ read_csv(.x, show_col_types = FALSE))

# -------------------------------
# 3. Format Data for Density Plot
# -------------------------------
plot_data <- plot_data_all %>%
  filter(region %in% c("GNP", "Mountain", "Buffer")) %>%
  mutate(
    area_km2 = region_areas[region],
    fires_per_km2 = n_fires / area_km2,
    # Ensure chronological month order
    month = factor(month, levels = month.name),
    # Year as factor for discrete vertical faceting
    year = factor(year)
  )

# -------------------------------
# 4. Multi-Year Vertical Stack Plot
# -------------------------------
p <- ggplot(plot_data, 
            aes(x = month, y = fires_per_km2, fill = region)) +
  geom_col(position = "dodge") +
  # Top-to-bottom stack by year
  facet_grid(year ~ .) +
  scale_fill_manual(values = c("GNP" = "#27ae60", 
                               "Mountain" = "#2980b9", 
                               "Buffer" = "#f1c40f")) +
  labs(
    x = "Month",
    y = "Fires per km²",
    fill = "Region",
    title = "Historical Fire Density Comparison"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    # Keep year labels on the right horizontal for readability
    strip.text.y = element_text(angle = 0, face = "bold"),
    panel.spacing = unit(0.5, "lines"),
    # Only show x-axis labels at the very bottom
    panel.grid.minor = element_blank()
  )

print(p)

# -------------------------------
# 5. Save the Output
# -------------------------------
num_years <- length(unique(plot_data$year))
outfile <- "plots/monthly_fires_per_km2_historical_stack.png"
dir.create("plots", showWarnings = FALSE)

# Scale height dynamically: ~1.5 inches per year facet
ggsave(outfile, plot = p, width = 12, height = (1.5 * num_years) + 2, dpi = 360, bg = "white")
