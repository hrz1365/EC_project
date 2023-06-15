# Reclassify raster
m <- c(0, 2500, NaN,
       2500, 5000, 1,
       5000, 7500, NaN,
       7500, 10000, NaN)

rclmat       <- matrix(m, ncol=3, byrow=TRUE)
rclss_raster <- classify(cur_bu_2020_raster, rclmat, include.lowest = T)


# Convert raster to points
raster_poly <- as.polygons(rclss_raster, na.rm = T)

raster_points <- st_as_sf(as.points(rclss_raster) )

a <- sample(raster_points, size = 1000, prob = values(raster_points)$BUT_15)


b <- spatSample(raster_points, size = 1000, strata = raster_poly)

aa <- spatSample(rclss_raster, 100, "stratified", xy = T, cells = T, na.rm = T)

sample(raster_points, 100)
