# Objective
The assessment of neighborhood effects on the built-up potential for each grid cell

# Specification
Currently, this project follows these steps to assess the neighborhood effects on built-up potential for each grid cell.
1. Specify a country
2. Generate points in the country to be used for model development
3. Feature engineering for each point
4. Divide points into train and test samples
5. Train an LSTM model on the sequence of features for each training point
6. Run the model for both training and test samples
7. Convert the outcomes back to rasters

# Scripts
## R scripts
- **ancillary_functions.R**: The script that contains several functions used in the model. These functions are:
  - aggregate_raster: The function to generate 1KM rasters from 100m rasters.
  - generate_features: The function to generate feature points and the initial feature space. The number of points in the vector feature file corresponds to the number of observations.
  - read_ml_outpus:
  - generate_ml_raster:     
- **cons_features.R**: The script to generate feature space based on buffers of time-invariant attributes such as elevation, slope, land mask, etc. The template data-frames and vector points for the feature space are first created by this script using the generate_features function. Therefore, this function should be run before other R scripts. In general, this script does the following for a given country:
  - Read the first level admin area (JRC provided) and project it to Mollweide.
  - Read the time-invariant rasters (e.g., elevation and land mask) and extract them to the boundary.
  - Generate slope raster based on elevation.
  - Aggregate initial rasters (100m) to 1km using the aggregate_raster function.
  - Generate the feature space, both in vector and tabular formats, using the generate_features function.
  - for each buffer size (5km, 10km, 25km, 50km, 100km):
    - Create a circular neighborhood (radius = buffer size)
    - Create focal rasters by assigning to the focal cell the mean of values in its neighborhood
    - Extract focal rasters to feature points
    - Add values to the tabular feature space
    - Save the resulting dataframe as the feature space comprising constant features.
- **bu_features.R**: The script to generate feature space based on buffers of time-varying attributes. These attributes are built-up values per grid cell over time. For a given country:
  - Load the multi-layer built-up raster in 1km
  - Load feature points and the empty feature space
  - Extract the built-up layer for a single layer
  - For the different buffer sizes:
    - Create a circular neighborhood (radius = buffer size)
    - Create focal rasters by assigning to the focal cell the mean of values in its neighborhood
    - Extract focal rasters to feature points
    - Add values to the tabular feature space  
