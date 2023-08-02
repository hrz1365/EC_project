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
- **ancillary_functions.R**: An script that contains several functions used in the model. These functions are:
  - aggregate_raster: A function to generate 1KM rasters from 100m rasters.
  - generate_features: A function to generate feature points and the initial feature space. The number of points in the vector feature file corresponds to the number of observations.
  - read_ml_outpus:
  - generate_ml_raster:     
- **cons_features.R**: An script to generate feature space based on buffers of time-invariant attributes such as elevation. The template data-frames and vector points for the feature space are created by this script. Therefore, it should be run first.
