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
-ancillary_functions.R: An script that contains several functions used in the program.
