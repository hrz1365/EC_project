# Header ------------------------------------------------------------------

# Purpose: A script to store functions for this project
# Author : Hamidreza Zoraghein
# Date   : 3/9/2023



# Options and Packages ----------------------------------------------------

if (!requireNamespace('terra', quietly = T))       install.packages('terra') 
if (!requireNamespace('data.table', quietly = T))  install.packages('data.table') 
if (!requireNamespace('tidyverse', quietly = T))   install.packages('tidyverse')
if (!requireNamespace('reticulate', quietly = T))  install.packages('reticulate') 


library(terra)
library(data.table)
library(tidyverse)
library(reticulate)

# For python
Sys.setenv(RETICULATE_PYTHON = "venv/Scripts/python.exe")
pd <- reticulate::import('pandas')




# Main Body --------------------------------------------------------------

# Aggregate an input raster by an order of magnitude to and write it to an address
aggregate_raster <- function(input_raster, fact = 10, fun = 'mean', output_path){
  
  cur_agg_raster <- aggregate(input_raster, fact, fun)
  
  
  if (!file.exists(output_path)) {
    
    writeRaster(cur_agg_raster, output_path)
  
  } else {
    
    print('The file already exists')
  }
  
  return(cur_agg_raster)
}



# Generate feature space and feature points
generate_features <- function(input_raster){
  
  # Feature points are based on the vectorization of the input raster
  feature_points         <- input_raster %>% as.points()
  feature_points[['id']] <- 0:(nrow(feature_points) - 1)
  feature_points[[1]]    <- NULL
  
  
  # Feature space df
  feature_space_df <- data.table(feature_id = 0:(nrow(feature_points)-1))
  
  
  return(list(feature_points = feature_points, feature_space_df = feature_space_df))
}



# Read ML outputs
read_ml_outputs <- function(ml_output_path){
  
  # Read the predictions of the ML model
  ml_bu_output <- pd$read_pickle(ml_output_path)
  
  
  ml_bu_output           <- as.data.table(ml_bu_output)
  colnames(ml_bu_output) <- c('feature_id', 'predicted_bu')
  
  
  return(ml_bu_output)
}



# Generate the ML-based raster
generate_ml_raster <- function(ml_output_path, feature_points_path, base_raster){
  
  
  ml_bu_output <- read_ml_outputs(ml_output_path)
  
  
  # Read the point vector file used for training the model
  feature_points <- file.path(feature_points_path) %>%
    vect()
  
  
  # Merge predicted values to the point file
  merged_vect <- merge(feature_points, ml_bu_output, by.x = 'id', by.y = 'feature_id')
  
  
  
  # Point to raster conversion based on predicted values
  predicted_bu_raster <- rasterize(merged_vect, base_raster, field = 'predicted_bu')
  predicted_bu_raster[predicted_bu_raster < 0]  <- 0
  predicted_bu_raster[predicted_bu_raster >= 1] <- 1
  
  
  return(predicted_bu_raster)
}



# Generate the distance decay neighborhood based on buffer distance
distance_decay_matrix <- function(buffer_distance){
  
  length_index   <-  2 * buffer_distance + 1
  
  neighborhood_m <- matrix(data = 0, nrow = length_index, ncol = length_index)
  
  focal_point = c(buffer_distance + 1, buffer_distance + 1)
  
  for (i in 1:length_index){
    
    for (j in 1:length_index){
      
      neighborhood_m[i, j] <- dist(rbind(c(i, j), 
                                         c(focal_point[1], focal_point[2])))
    }
  }
  
  
  neighborhood_m <- exp(-2 * neighborhood_m)
  neighborhood_m[focal_point[1], focal_point[2]] <- 0
  neighborhood_m <- neighborhood_m / sum(neighborhood_m)
  
  return(neighborhood_m)
}



