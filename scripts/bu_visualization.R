
# Header ------------------------------------------------------------------

# Purpose: Visualization of Built-up areas
# Author : Hamidreza Zoraghein
# Date   : 3/9/2023




# Options and Packages ----------------------------------------------------

if (!requireNamespace('terra', quietly = T))         install.packages('terra') 
if (!requireNamespace('data.table', quietly = T))    install.packages('data.table') 
if (!requireNamespace('tidyverse', quietly = T))     install.packages('tidyverse') 


library(terra)
library(data.table)
library(tidyverse)

source(file.path('scripts', 'ancillary_functions.R'))

options(readr.show_progress = F)




# Inputs and Path ---------------------------------------------------------

# Built-up path
bu_path         <- 'initial_rasters'
boundaries_path <- 'boundaries'
rasters_path    <- 'country_rasters'

cur_country <- 'ken'




# Main Program ------------------------------------------------------------

admin_0   <- file.path(boundaries_path, str_c(cur_country, '_adm.gpkg')) %>%
  vect() %>%
  project('ESRI:54009')


bu_raster <- rast(file.path(bu_path, 'BUTOT_MEDIAN.tif'))



# Extract the built-up layer in 2020 for the country of interest
cur_bu_raster <- bu_raster %>%
  terra::crop(admin_0) %>%
  terra::mask(admin_0)


# Change the values to proportion
cur_bu_raster <- cur_bu_raster / 10000


# Aggregate by an order of magnitude to 1km resolution
cur_bu_raster_1km <- aggregate_raster(cur_bu_raster, fact = 10, fun = 'mean',
                                      file.path(rasters_path, str_c(cur_country, '_bu', '.tif')))


# Convert to data-frame for plotting of the built-up in 2020
cur_bu_2020_df <- cur_bu_raster_1km[[15]] %>%
  as.data.frame(xy = T) %>%
  drop_na()


cur_map <- ggplot() +
  geom_raster(data = cur_bu_2020_df, aes(x = x, y = y, fill = BUT_15)) +
  geom_sf(fill = 'transparent', data = admin_0) +
  scale_fill_viridis_c(name = 'Built-up Proportion', direction = -1) +
  labs(x = '', y = '', title = 'Built-up Proportion in Kenya in 2020') +
  theme(legend.position  = 'bottom',
        panel.grid       = element_blank(),
        panel.background = element_rect(fill = NA, color = 'black')) +
  guides(fill =guide_colorsteps(title.position = 'top', barwidth = unit(4, 'in'),
                                barheight = 0.5))
  

