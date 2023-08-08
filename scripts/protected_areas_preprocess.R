
# Header -----------------------------------------------------------------

# Purpose: Process protected areas for a given country and convert it into a raster
# Author : Hamidreza Zoraghein
# Date   : 8/3/2023




# Options and Packages ----------------------------------------------------

if (!requireNamespace('sf', quietly = T))          install.packages('sf') 
if (!requireNamespace('terra', quietly = T))       install.packages('terra') 
if (!requireNamespace('miceadds', quietly = T))    install.packages('miceadds') 
if (!requireNamespace('tidyverse', quietly = T))   install.packages('tidyverse') 


library(sf)
library(terra)
library(miceadds)
library(tidyverse)




# Inputs and Path ---------------------------------------------------------

boundaries_path  <- 'boundaries'
vectors_path     <- 'country_vectors'
rasters_path     <- 'country_rasters'
cur_country      <- 'ken' 




# Main Program ------------------------------------------------------------

admin_0   <- file.path(boundaries_path, str_c(cur_country, '_adm.gpkg')) %>%
  vect() %>%
  project('ESRI:54009')


# Read the initial protected area vector
load.Rdata(file.path(vectors_path, str_c(cur_country, '_ProtectedAreas.RData')),
                                  objname = 'ini_protected_areas')

ini_protected_areas <- vect(ini_protected_areas)



# Rasterization
# Load the elevation layer to use a reference for rasterization
ref_raster <- file.path(rasters_path, str_c(cur_country, '_elev.tif')) %>%
  rast()


protected_areas <- rasterize(ini_protected_areas, ref_raster) %>%
  
protected_areas[is.na(protected_areas)] <- 0
  
protected_areas <- protected_areas %>%
  crop(admin_0) %>%
  mask(admin_0)


writeRaster(protected_areas, file.path(rasters_path, str_c(cur_country, '_pa.tif')),
            overwrite = T)
