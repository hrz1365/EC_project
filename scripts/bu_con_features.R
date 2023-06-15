
# Header ------------------------------------------------------------------

# Purpose: Create feature space based on continuous matrics on built-up
# Author : Hamidreza Zoraghein
# Date   : 4/12/2023




# Options and Packages ----------------------------------------------------

if (!require(raster))       install.packages('raster')      else library(raster)
if (!require(terra))        install.packages('terra')       else library(terra)
if (!require(sf))           install.packages('sf')          else library(sf)
if (!require(geodiv))       install.packages('geodiv')      else library(geodiv)
if (!require(data.table))   install.packages('data.table')  else library(data.table)
if (!require(doParallel))   install.packages('doParallel')  else library(doParallel)
if (!require(foreach))      install.packages('foreach')     else library(foreach)




# Functions ---------------------------------------------------------------

con_metrics_estimate <- function(bu_raster, points_buffer){
  
  feature_space_df <- foreach(f_id = 1:10, .combine = rbind) %dopar% {
    
    # Calculate continuous metrics per point
    # cur_buffer_raster <- country_bu_raster_2020 %>%
    #   terra::crop(country_points_buffer[f_id])
    c <- 1
    (country_bu_raster_2020 + c)
    # cur_sq   <- sq(raster(cur_buffer_raster))
    # cur_s10z <- s10z(raster(cur_buffer_raster))
    # cur_sbi  <- sbi(raster(cur_buffer_raster))
    # cur_svi  <- svi(raster(cur_buffer_raster))
    # cur_sds  <- sds(raster(cur_buffer_raster))
    # cur_sdq  <- sdq(raster(cur_buffer_raster))
    # cur_std  <- std(raster(cur_buffer_raster))[1]
    # cur_stdi <- std(raster(cur_buffer_raster))[2]
    # cur_srw  <- srw(raster(cur_buffer_raster))[1]
    # cur_srwi <- srw(raster(cur_buffer_raster))[2]
    # 
    # data.table(feature_id = f_id, sq = cur_sq, s10z = cur_s10z, sbi = cur_sbi,
    #            svi  = cur_svi, sds = cur_sds, sdq = cur_sdq, std = cur_std,
    #            stdi = cur_stdi, srw = cur_srw, srwi = cur_srwi)
    
  }
  
  return(feature_space_df)  
}




# Inputs and Path ---------------------------------------------------------

boundaries_path <- 'boundaries'
rasters_path    <- 'country_rasters'

cur_country <- 'ken'




# Main Program ------------------------------------------------------------

country_bu_raster <- file.path(rasters_path, paste0(cur_country, '.tif')) %>%
  rast()

country_bu_raster_2020 <- country_bu_raster[[15]]


# Create buffer around point features
country_points_buffer <- country_bu_raster_2020 %>%
  as.points() %>%
  buffer(10000) 

country_points_buffer[['feature_id']] <- 1:nrow(country_points_buffer)



cl <- makeCluster(detectCores(logical = F) - 1)
registerDoParallel(cl)
clusterEvalQ(cl, {
  library(geodiv)
  library(data.table)
  library(terra)
  library(tidyverse)
  library(raster)
})
clusterExport(cl, c('country_bu_raster_2020', 'country_points_buffer'))

stopCluster(cl)

feature_space_df <- con_metrics_estimate(country_bu_raster_2020, country_points_buffer)



# The table that will contain the feature space 
feature_space_df           <- data.table(matrix(data = 0, 
                                                nrow = 5,
                                                ncol = 11))
colnames(feature_space_df) <- c('feature_id', 'sq', 's10z', 'sbi', 'svi', 'sds', 'sdq',
                                'std', 'stdi', 'srw', 'srwi')
# feature_space_df[, feature_id := 1:nrow(country_points_buffer)]
feature_space_df[, feature_id := 1:5]


for (f_id in 1:nrow(country_points_buffer)){
  
  # Calculate continuous metrics per point
  cur_buffer_raster <- country_bu_raster_2020 %>%
    terra::crop(country_points_buffer[feature_id]) %>%
    terra::mask(country_points_buffer[feature_id])
  
  
  feature_space_df[feature_id == f_id, sq   := sq(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, s10z := s10z(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, sbi  := sbi(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, svi  := svi(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, sds  := sds(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, sdq  := sdq(raster(cur_buffer_raster))]
  feature_space_df[feature_id == f_id, std  := std(raster(cur_buffer_raster))[1]]
  feature_space_df[feature_id == f_id, stdi := std(raster(cur_buffer_raster))[2]]
  feature_space_df[feature_id == f_id, srw  := srw(raster(cur_buffer_raster))[1]]
  feature_space_df[feature_id == f_id, srwi := srw(raster(cur_buffer_raster))[2]]
  
  cat(f_id, 'is done\n')
}


a <- raster(country_bu_raster_2020)

b <- raster::focal(a, w = matrix(1, 3, 3), fun = test, pad = T, padValue = NA)


test <- function(x) 
  {
    if (inherits(x, "RasterLayer") == TRUE) {
      z <- getValues(x)
    }
    else {
      z <- x
    }
    zbar <- mean(z, na.rm = TRUE)
    s <- sd(z, na.rm = TRUE)
    N <- length(na.omit(z))
    val_unadj <- (sum((z - zbar)^3, na.rm = TRUE)/N)/(s^3)

    val <- (sqrt((N * (N - 1)))/(N - 2)) * val_unadj


    return(val)
  }

ssd(a)


