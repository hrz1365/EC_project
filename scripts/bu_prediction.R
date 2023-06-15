

# Header ------------------------------------------------------------------

# Purpose: Create the built-up raster from the ML output
# Author : Hamidreza Zoraghein
# Date   : 5/5/2023




# Options and Packages ----------------------------------------------------

if (!require(terra))        install.packages('terra')        else library(terra)
if (!require(data.table))   install.packages('data.table')   else library(data.table)
if (!require(tidyverse))    install.packages('tidyverse')    else library(tidyverse)
if (!require(reticulate))   install.packages('reticulate')   else library(reticulate)


source(file.path('scripts', 'ancillary_functions.R'))




# Inputs and Path ---------------------------------------------------------

ml_path             <- 'ml_outputs'
fs_path             <- 'feature_space'
rasters_path        <- 'country_rasters'
cur_country         <- 'ken'
ml_output_path      <- file.path(ml_path, 'lstm_2040.pkl')
feature_points_path <- file.path(fs_path, str_c(cur_country,
                                                '_feature_points_raw.shp'))



# Main Program ------------------------------------------------------------

# Read the elevation and built-up area rasters
cur_bu_raster_1km   <- file.path(rasters_path, str_c(cur_country, '_bu', '.tif')) %>%
  rast()

cur_elev_raster_1km <- file.path(rasters_path, str_c(cur_country, '_DEM', '.tif')) %>%
  rast()



# Read the predictions of the ML model
predicted_bu_raster <- generate_ml_raster(ml_output_path, feature_points_path,
                                          cur_elev_raster_1km)


# diff <- predicted_bu_raster - c


