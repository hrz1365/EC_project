
# Header -----------------------------------------------------------------

# Purpose: Create feature space based on constant features such as elevation
# Author : Hamidreza Zoraghein
# Date   : 5/17/2023




# Options and Packages ----------------------------------------------------

if (!requireNamespace('terra', quietly = T))         install.packages('terra') 
if (!requireNamespace('data.table', quietly = T))    install.packages('data.table') 
if (!requireNamespace('tidyverse', quietly = T))     install.packages('tidyverse') 


library(terra)
library(data.table)
library(tidyverse)

source(file.path('scripts', 'ancillary_functions.R'))




# Inputs and Path ---------------------------------------------------------

boundaries_path  <- 'boundaries'
ini_rasters_path <- 'initial_rasters'
rasters_path     <- 'country_rasters'
fs_path          <- 'feature_space'

cur_country  <- 'ken'
buffer_sizes <- c(5000, 10000, 25000, 50000, 100000) 




# Main Program ------------------------------------------------------------

admin_0   <- file.path(boundaries_path, str_c(cur_country, '_adm.gpkg')) %>%
  vect() %>%
  project('ESRI:54009')



# Initial elevation raster at 100m
cur_elev_raster <- file.path(ini_rasters_path, paste0(cur_country, '_DEM.tif')) %>%
  rast() %>%
  crop(admin_0) %>%
  mask(admin_0)


# Create the slope raster
cur_slope_raster <- terrain(cur_elev_raster, v = 'slope')


# Read the landmask raster
cur_lm_raster <- file.path(ini_rasters_path, paste0(cur_country, '_LandMask.tif')) %>%
  rast() %>%
  crop(admin_0) %>%
  mask(admin_0)



# Aggregate the elevation and slope rasters to 1KM
cur_elev_raster_1km  <- aggregate_raster(cur_elev_raster, fact = 10, fun = 'mean',
                                        file.path(rasters_path, str_c(cur_country, '_elev', '.tif')))

cur_slope_raster_1km <- aggregate_raster(cur_slope_raster, fact = 10, fun = 'mean',
                                        file.path(rasters_path, str_c(cur_country, '_slope', '.tif')))

cur_lm_raster_1km    <- aggregate_raster(cur_lm_raster, fact = 10, fun = 'mean',
                                         file.path(rasters_path, str_c(cur_country, '_lm', '.tif')))

# Load the protect area raster, which has already been processes elsewhere
cur_pa_raster_1km <- rast(file.path(rasters_path, str_c(cur_country, '_pa.tif')))



# Generate feature space points and df
feature_space_outputs <- generate_features(cur_elev_raster_1km)

feature_points   <- feature_space_outputs$feature_points
feature_space_df <- feature_space_outputs$feature_space_df



# Save the outputs as the standard feature space and points across all scripts
fs_points_path <- file.path(fs_path, str_c(cur_country, '_feature_points_raw.shp'))

if (!file.exists(fs_points_path)) {
  
  writeVector(feature_points, fs_points_path)
  
} else {
  
  print('The feature points dataset has already been created!')
}


fs_space_path <- file.path(fs_path, str_c(cur_country, '_feature_space_raw.rda'))

if (!file.exists(fs_space_path)) {
  
  saveRDS(feature_space_df, fs_space_path)
  
} else {
  
  print('The feature space has already been created!')
}



# Extract built-up raster to points
for (buffer_size in buffer_sizes){
  
  cat('\nThe buffer size is: ', buffer_size)
  
  
  # Create the neighborhood matrix based on the buffer size
  neighborhood                   <- focalMat(cur_elev_raster_1km, d = buffer_size,
                                             type = 'circle')
  neighborhood[neighborhood > 0] <- 1
  
  
  # Derive the focal elevation and slope rasters based  on the neighborhood
  focal_elev_raster  <- focal(cur_elev_raster_1km, w = neighborhood, fun = mean,
                              fillvalue = NA, expand = F, na.rm = T)
  
  focal_slope_raster <- focal(cur_slope_raster_1km, w = neighborhood, fun = mean,
                              fillvalue = NA, expand = F, na.rm = T)
  
  focal_lm_raster    <- focal(cur_lm_raster_1km, w = neighborhood, fun = mean,
                              fillvalue = NA, expand = F, na.rm = T)
  
  focal_pa_raster    <- focal(cur_pa_raster_1km, w = neighborhood, fun = mean,
                              fillvalue = NA, expand = F, na.rm = T)
  
  
  
  # Extract focal raster to points 
  focal_elev_extraction  <- terra::extract(focal_elev_raster, feature_points, 
                                           method = 'simple', bind = T)
  focal_slope_extraction <- terra::extract(focal_slope_raster, feature_points, 
                                           method = 'simple', bind = T)
  focal_lm_extraction    <- terra::extract(focal_lm_raster, feature_points, 
                                           method = 'simple', bind = T)
  focal_pa_extraction    <- terra::extract(focal_pa_raster, feature_points, 
                                           method = 'simple', bind = T)
  
  
  feature_space_df[, str_c('elev_buf_', buffer_size)]  <- focal_elev_extraction[[2]]
  feature_space_df[, str_c('slope_buf_', buffer_size)] <- focal_slope_extraction[[2]]
  feature_space_df[, str_c('lm_buf_', buffer_size)]    <- focal_lm_extraction[[2]]
  feature_space_df[, str_c('pa_buf_', buffer_size)]    <- focal_pa_extraction[[2]]
}


# Save the final data-frame
fwrite(feature_space_df, file.path(fs_path, str_c(cur_country, '_const_fs.csv')))

