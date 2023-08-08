# Header

# Putpose: This script is for generating projections of built-up areas over time
# Author : Hamidreza Zoraghein
# Date   : 6/6/2023



# Pacakages 
from pathlib import Path 
import pickle



# Paths and Inputs
main_dir                = Path('.')
model_output_path       = main_dir / 'ml_outputs'
fs_dir                  = main_dir / 'feature_space'
train_ids_pkl           = fs_dir / 'train_ids.pkl'
test_ids_pkl            = fs_dir / 'test_ids.pkl'
bu_feature_space_path   = fs_dir / 'ken_bu_fs_2030.csv'
con_feature_space_path  = fs_dir / 'ken_const_fs.csv'

num_time_steps, dim_var_features, dim_cons_features = 4, 5, 20
prediction_year = int(bu_feature_space_path.stem.split('_')[-1]) + 10



# Main Code
bu_feature_space_df   = pd.read_csv(bu_feature_space_path)
con_feature_space_df  = pd.read_csv(con_feature_space_path)


raster_content_path = model_output_path / 'lstm_{}.pkl'.format(prediction_year)


model_obj = buPredictionModel(bu_feature_space_df, con_feature_space_df, num_time_steps, 
                                dim_var_features, dim_cons_features)

cur_model = tf.keras.models.load_model(model_output_path / 'lstm_2020.h5')


with open(train_ids_pkl, 'rb') as train_ids_load:
    train_ids = pickle.load(train_ids_load)

with open(test_ids_pkl, 'rb') as test_ids_load:
    test_ids = pickle.load(test_ids_load)


train_bu, test_bu, train_con, test_con = model_obj.train_test_extract(train_ids, test_ids)

# Scale the data into -1 to 1
con_scaler, x_train_con, x_test_con = model_obj.scale_features(train_con, test_con)


if prediction_year == 2020:
    train_bu = train_bu.iloc[:, :-1]
    test_bu  = test_bu.iloc[:, :-1]


train_predictions = model_obj.model_predict(cur_model, train_bu.values, x_train_con)
test_predictions  = model_obj.model_predict(cur_model, test_bu.values, x_test_con)


raster_content = model_obj.create_raster_content(train_ids, train_predictions, 
                                                 test_ids, test_predictions,
                                                 raster_content_path)