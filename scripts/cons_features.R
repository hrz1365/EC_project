
# Header -----------------------------------------------------------------

# Purpose: Create feature space based on constant features such as elevation
# Author : Hamidreza Zoraghein
# Date   : 5/17/2023




# Options and Packages ----------------------------------------------------

if (!require(terra))        install.packages('terra')       else library(terra)
if (!require(data.table))   install.packages('data.table')  else library(data.table)
if (!require(tidyverse))    install.packages('tidyverse')   else library(tidyverse)

source(file.path('scripts', 'ancillary_functions.R'))




# Inputs and Path ---------------------------------------------------------

boundaries_path  <- 'boundaries'
ini_rasters_path <- 'initial_rasters'
rasters_path     <- 'country_rasters'
fs_path          <- 'feature_space'

cur_country  <- 'ken'
cur_variable <- 'elev'
buffer_sizes <- c(5000, 10000, 25000, 50000) 




# Main Program ------------------------------------------------------------

admin_0   <- file.path(boundaries_path, str_c(cur_country, '_adm0.gpkg')) %>%
  vect() %>%
  project('ESRI:54009')



# Initial elevation raster at 100m
cur_elev_raster <- file.path(ini_rasters_path, paste0(cur_country, '_DEM', '.tif')) %>%
  rast() %>%
  crop(admin_0) %>%
  mask(admin_0)



# Aggregate the initial raster to 1KM
cur_elev_raster_1km <- aggregate_raster(cur_elev_raster, fact = 10, fun = 'mean',
                                        file.path(rasters_path, str_c(cur_country, '_DEM', '.tif')))


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
  
  
  # Derive the focal raster based  on the neighborhood
  focal_raster <- focal(cur_elev_raster_1km, w = neighborhood, fun = mean,
                        fillvalue = NA, expand = F, na.rm = T)
  
  
  # Extract focal raster to points 
  focal_extraction <- terra::extract(focal_raster, feature_points, method = 'simple', bind = T)
  
  
  feature_space_df[, str_c(cur_variable, '_buf_', buffer_size)] <- focal_extraction[, 2]
}


# Save the final data-frame
fwrite(feature_space_df, file.path(fs_path, str_c(cur_country, '_', cur_variable,
                                                  '_fs.csv')))

