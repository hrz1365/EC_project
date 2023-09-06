
# Header -----------------------------------------------------------------

# Purpose: Create feature space based on built-up evolution
# Author : Hamidreza Zoraghein
# Date   : 4/19/2023




# Options and Packages ----------------------------------------------------

if (!requireNamespace('terra', quietly = T))         install.packages('terra') 
if (!requireNamespace('data.table', quietly = T))    install.packages('data.table') 
if (!requireNamespace('tidyverse', quietly = T))     install.packages('tidyverse') 


library(terra)
library(data.table)
library(tidyverse)

source(file.path('scripts', 'ancillary_functions.R'))




# Inputs and Path ---------------------------------------------------------

cur_country     <- 'ken'
buffer_sizes    <- c(5000, 10000, 25000, 50000, 100000) 
fst_actual_year <- 1970
lst_actual_year <- 2020
built_up_yrs    <- seq(fst_actual_year, lst_actual_year, 10)
fst_year        <- 2060
lst_year        <- 2090


boundaries_path     <- 'boundaries'
rasters_path        <- 'country_rasters'
fs_path             <- 'feature_space'
ml_path             <- 'ml_outputs'

feature_points_path <- file.path(fs_path, str_c(cur_country, '_feature_points_raw.shp'))




# Main Program ------------------------------------------------------------

cur_bu_raster_1km <- file.path(rasters_path, paste0(cur_country, '_bu', '.tif')) %>%
  rast()

cur_elev_raster_1km <- file.path(rasters_path, str_c(cur_country, '_elev', '.tif')) %>%
  rast()



# Read the feature space datasets created at the "cons_features" script
feature_points  <- feature_points_path %>%
  vect()

feature_space_df <- file.path(fs_path, str_c(cur_country, '_feature_space_raw.rda')) %>%
  readRDS()



# For each year, derive different built-up features
for (year in seq(fst_year, lst_year, 10)){
  
  cat('\nThe year is: ', year)
  
  if (year <= lst_actual_year) {
    
    # Extract the current built-up year
    year_index   <- 2 * (which(built_up_yrs == year) - 1) + 5
    cur_bu_layer <- cur_bu_raster_1km[[year_index]]
    
  } else {
    
    ml_output_path  <- file.path(ml_path, str_c('lstm_', year, '.pkl'))
    cur_bu_layer    <- generate_ml_raster(ml_output_path, feature_points_path,
                                          cur_elev_raster_1km)
  }

  
  feature_space_df[, str_c('bu_', year)] <- terra::extract(cur_bu_layer, feature_points, method = 'simple', bind = T)[[2]]
  
  
  for (buffer_size in buffer_sizes){
    
    cat('\nThe buffer size is: ', buffer_size)
    
    
    # Create the neighborhood matrix based on the buffer size
    neighborhood                   <- focalMat(cur_bu_layer, d = buffer_size,
                                               type = 'circle')
    neighborhood[neighborhood > 0] <- 1
    
    distance_decay_mat <- distance_decay_matrix(buffer_size / 1e3)
    
    final_neighborhood <- neighborhood * distance_decay_mat
    
    
    # Derive the focal raster based  on the neighborhood
    built_up_focal <- focal(cur_bu_layer, w = final_neighborhood, fun = sum,
                            na.policy = 'omit', fillvalue = NA, expand = F, na.rm = T)
    
    
    # Extract focal raster to points 
    focal_extraction <- terra::extract(built_up_focal, feature_points, method = 'simple', bind = T)
    
    
    feature_space_df[, str_c('bu_buf_', buffer_size, '_', year)] <- focal_extraction[[2]]
  }
  
}


# Extract the target attribute, which is built-up proportion in 2020
target_year <- lst_year + 10
target_col  <- str_c('bu_', target_year)
if (target_year == 2020) {
  
  cur_bu_layer       <- cur_bu_raster_1km[[15]]
  builtup_extraction <- terra::extract(cur_bu_layer, feature_points, method = 'simple',
                                       bind = T)
  feature_space_df[, target_col] <- builtup_extraction[[2]]
  
  
  # Categorize different levels of built-up in 2020
  feature_space_df[, bu_category := fcase(
     bu_2020 <= quantile(bu_2020, 0.5), 1,
    (bu_2020 > quantile(bu_2020, 0.5)) & (bu_2020 <= quantile(bu_2020, 0.75)), 2,
    (bu_2020 > quantile(bu_2020, 0.75)) & (bu_2020 <= quantile(bu_2020, 0.9)), 3,
    (bu_2020 > quantile(bu_2020, 0.9)), 4
  )]
  
} 

# else {
#   
#   ml_output_path  <- file.path(ml_path, str_c('lstm_', target_year, '.pkl'))
#   cur_bu_layer    <- generate_ml_raster(ml_output_path, feature_points_path,
#                                         cur_elev_raster_1km)
#   
#   builtup_extraction <- terra::extract(cur_bu_layer, feature_points, method = 'simple',
#                                        bind = T)
#   feature_space_df[, target_col] <- builtup_extraction[[2]]
# }



# Save the final data-frame
fwrite(feature_space_df, file.path(fs_path, str_c(cur_country,
                                                  '_bu_fs_', lst_year, '.csv')))


