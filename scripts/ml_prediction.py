# Header

# Putpose: This script is for generating projections of built-up areas over time
# Author : Hamidreza Zoraghein
# Date   : 6/6/2023



# Pacakages 
from pathlib import Path 
import pickle



# Paths and Inputs
main_dir                = Path('.')
fs_dir                  = main_dir / 'feature_space'
train_ids_pkl           = fs_dir / 'train_ids.pkl'
test_ids_pkl            = fs_dir / 'test_ids.pkl'
bu_feature_space_path   = fs_dir / 'ken_bu_fs_all_2040.csv'
elev_feature_space_path = fs_dir / 'ken_elev_fs.csv'



# Main Code
bu_feature_space_df   = pd.read_csv(bu_feature_space_path)
elev_feature_space_df = pd.read_csv(elev_feature_space_path)



prediction_year = extract_pred_year(bu_feature_space_df)

raster_content_path = fs_dir / 'ml_outputs' / 'lstm_{}.pkl'.format(prediction_year+10)


model_obj = buPredictionModel(bu_feature_space_df, elev_feature_space_df, num_time_steps, 
                                dim_var_features, dim_cons_features)

cur_model = tf.keras.models.load_model(fs_dir / 'ml_outputs')


with open(train_ids_pkl, 'rb') as train_ids_load:
    train_ids = pickle.load(train_ids_load)

with open(test_ids_pkl, 'rb') as test_ids_load:
    test_ids = pickle.load(test_ids_load)


train_bu, test_bu, train_elev, test_elev = model_obj.train_test_extract(train_ids, test_ids)

# Scale the data into -1 to 1
elev_scaler, x_train_elev, x_test_elev = model_obj.scale_features(train_elev, test_elev)



train_predictions = model_obj.model_predict(cur_model, train_bu.values, x_train_elev)
test_predictions  = model_obj.model_predict(cur_model, test_bu.values, x_test_elev)


raster_content = model_obj.create_raster_content(train_ids, train_predictions, 
                                                 test_ids, test_predictions,
                                                 raster_content_path)