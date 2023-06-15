# Header

# Putpose: This script is for creating a model to predict built-up areas through neighborhood characteristics
# Author : Hamidreza Zoraghein
# Date   : 4/24/2023



# Pacakages 
from pathlib import Path 
import pickle



# Paths and Inputs
main_dir = Path('.')
fs_dir                  = main_dir / 'feature_space'
model_output_path       = main_dir / 'ml_outputs'
train_ids_pkl           = fs_dir / 'train_ids.pkl'
test_ids_pkl            = fs_dir / 'test_ids.pkl'
bu_feature_space_path   = fs_dir / 'ken_bu_fs_all.csv'
elev_feature_space_path = fs_dir / 'ken_elev_fs.csv'


num_time_steps, dim_var_features, dim_cons_features = 5, 5, 4
model_name = 'lstm_elev_bu_all_2020.h5'



# Main Code

# Initial features
bu_feature_space_df   = pd.read_csv(bu_feature_space_path)
elev_feature_space_df = pd.read_csv(elev_feature_space_path)


model_obj = buPredictionModel(bu_feature_space_df, elev_feature_space_df, num_time_steps, 
                              dim_var_features, dim_cons_features)


if train_ids_pkl.is_file() and test_ids_pkl.is_file():
    print('Ids for train and test ids have already been created...')
    with open(train_ids_pkl, 'rb') as load_train_ids:
        train_ids = pickle.load(load_train_ids)
    with open(test_ids_pkl, 'rb') as load_test_ids:
        test_ids  = pickle.load(load_test_ids)

else:

    train_ids, test_ids = model_obj.train_test_id_extract()
    with open(train_ids_pkl, 'wb') as write_train_ids:
        pickle.dump(train_ids, write_train_ids)
    
    with open(test_ids_pkl, 'wb') as write_test_ids:
        pickle.dump(test_ids, write_test_ids)
    


# Extract train and test datasets
train_bu, test_bu, train_elev, test_elev = model_obj.train_test_extract(train_ids, test_ids)


cur_model = model_obj.define()


# Prepare the datasets for training
x_train_bu, x_test_bu = train_bu.iloc[:, :-1].values, test_bu.iloc[:, :-1].values
y_train_bu, y_test_bu = train_bu.iloc[:, -1], test_bu.iloc[:, -1]

# Scale elevation data between 0 and 1
elev_scaler, x_train_elev_scaled, x_test_elev_scaled  = model_obj.scale_features(train_elev, test_elev)


cur_model, history = model_obj.model_fit(cur_model, x_train_bu, x_train_elev_scaled,
                                         x_test_bu, x_test_elev_scaled,
                                         y_train_bu, y_test_bu)
loss = history.history



# Save the model and its history outputs
output_pickle_path = model_output_path / 'history_{}.pkl'.format(model_name[:-3])
if output_pickle_path.is_file():
    print('The pickle file containing the history file of the trained model already exists')
else:
    cur_model.save(model_output_path / model_name)
    with open(output_pickle_path, 'wb') as write_file:
        pickle.dump(loss, write_file)
    


# Create and save the MSE plot
epochs    = [i + 1 for i in list(range(len(loss['loss'])))]
plot_path = model_output_path / 'mse_plot.tif'
model_obj.plot_series(x = epochs, y = loss, end = 30, title = 'Mean Squared Error', xlabel = 'Epoch', ylabel = 'MSE',
                      legend = ['Train MSE', 'Validation MSE'])



# Make predictions to generate the modeled raster
train_predictions = model_obj.model_predict(cur_model, x_train_bu, x_train_elev_scaled)
test_predictions  = model_obj.model_predict(cur_model, x_test_bu, x_test_elev_scaled)



# Create a pickel layer to bo converted to a raster in the R script
prediction_year     = extract_pred_year(bu_feature_space_df)
raster_content_path = model_output_path / 'lstm_{}.pkl'.format(prediction_year)
raster_content      = model_obj.create_raster_content(train_ids, train_predictions, 
                                                      test_ids, test_predictions,
                                                      raster_content_path)