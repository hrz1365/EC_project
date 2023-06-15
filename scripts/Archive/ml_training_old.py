# Header

# Putpose: This script is for running different ML-based models to predict built-up areas through neighborhood characteristics
# Author : Hamidreza Zoraghein
# Date   : 4/24/2023



# Pacakages 
import sklearn
import numpy as np 
import pandas as pd 
import matplotlib.pyplot as plt
from pathlib import Path 
import pickle
import tensorflow as tf
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, LSTM, Input, concatenate
from tensorflow.python.ops import math_ops
from sklearn.preprocessing import MinMaxScaler



def scale(train, test):
    scaler = MinMaxScaler(feature_range = (-1, 1))
    scaler = scaler.fit(train)

    train_scaled = scaler.transform(train)
    test_scaled  = scaler.transform(test)

    return(scaler, train_scaled, test_scaled)



def invert_scale(scaler, X, yhat):
    X_y                = np.append(X, yhat, 1) 
    transformed_values = np.round(scaler.inverse_transform(X_y)[:, -1], 2)
    return(transformed_values)



def train_test_id_extract(feature_space_df):
    
    np.random.seed(seed = 123)

    # Randomly select 80% of points in each built-up category for training
    train_set = feature_space_df.groupby('bu_category', group_keys=False).apply(lambda x: x.sample(frac = 0.8))
    train_ids = train_set.feature_id


    # Create the test set
    test_ids = np.asarray([test_id for test_id in feature_space_df.feature_id if test_id not in train_ids])
    # test_set = feature_space_df[feature_space_df.feature_id.isin(test_ids)]

    train_ids = train_ids.values

    return(train_ids, test_ids)



def train_test_extract(feature_space_df, train_ids, test_ids):

    if ('bu_category' in feature_space_df.columns):
        train = feature_space_df.loc[train_ids, ~feature_space_df.columns.isin(['feature_id', 'bu_category'])]
        test  = feature_space_df.loc[test_ids, ~feature_space_df.columns.isin(['feature_id', 'bu_category'])]
    else:
        train = feature_space_df.loc[train_ids, ~feature_space_df.columns.isin(['feature_id'])]
        test  = feature_space_df.loc[test_ids, ~feature_space_df.columns.isin(['feature_id'])]

    return(train, test)



def define_model(num_time_steps, dim_var_features, dim_cons_features):
    fst_input        = Input(batch_shape = (256, num_time_steps, dim_var_features))
    fst_lstm_output  = LSTM(128, return_sequences = True)(fst_input) 
    snd_lstm_output  = LSTM(128)(fst_lstm_output)

    snd_input = Input(batch_shape = (256, dim_cons_features))
    fst_dense = Dense(128, activation = 'relu')(snd_input)

    concat = concatenate([snd_lstm_output, fst_dense])

    output = Dense(1)(concat)


    model = Model(inputs = [fst_input, snd_input], outputs = output)
    return(model)



def model_fit(model, x_train_bu, x_train_elev, y_train, x_test_bu, x_test_elev, y_test):
    x_train_bu   = x_train_bu.reshape((-1, 5, 5))
    x_train_elev = x_train_elev.reshape((-1, 4))
    x_test_bu    = x_test_bu.reshape((-1, 5, 5))
    x_test_elev  = x_test_elev.reshape((-1, 4))

    model.compile(loss = 'mse', optimizer = 'adam')
    history = model.fit([x_train_bu, x_train_elev], y_train, epochs = 5, batch_size = 512, verbose = True,
                        validation_data = ([x_test_bu, x_test_elev], y_test))
    return(model, history)


def plot_series(x, y, format = '-', start = 0, end = None,
                title = None, xlabel = None, ylabel = None, legend = None):
    
    plt.figure(figsize = (10, 6))

    if type(y) is dict:
        dict_keys = y.keys()
        for dict_key in dict_keys:
            plt.plot(x[start:end], y.get(dict_key)[start:end], format)
    
    else:
        plt.plot(x[start:end], y[start:end], format)
    
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)

    if legend:
        plt.legend(legend)
    
    plt.title(title)

    plt.grid(True)

    plt.show()



def create_raster_content(train_ids, train_values, test_ids, test_values):
    
    # Create the raster to export to R
    train_outcome = np.hstack((np.expand_dims(train_ids, -1), np.expand_dims(train_values, -1)))
    test_outcome  = np.hstack((np.expand_dims(test_ids, -1), np.expand_dims(test_values, -1)))

    total_content = np.vstack((train_outcome, test_outcome))

    return(total_content)



fs_dir = Path('.')

bu_feature_space_df = pd.read_csv(fs_dir / 'feature_space' / 'ken_bu_fs.csv')

elev_feature_space_df = pd.read_csv(fs_dir / 'feature_space' / 'ken_elev_fs.csv')



# Read the built-up area data and group them into train, test datasets

train_ids, test_ids = train_test_id_extract(bu_feature_space_df)
train_bu, test_bu   = train_test_extract(bu_feature_space_df, train_ids, test_ids)


# Read the elevation data and group them into train, test datasets

train_elev, test_elev = train_test_extract(elev_feature_space_df, train_ids, test_ids)


# Scale the data into -1 to 1
bu_scaler, train_bu_scaled, test_bu_scaled = scale(train_bu, test_bu)
elev_scaler, x_train_elev, x_test_elev     = scale(train_elev, test_elev)


# Separate built-up features from the target variable
# Built-up area
x_train_bu = train_bu_scaled[:, :-1]
x_test_bu  = test_bu_scaled[:, :-1]


# Target variable, which is built-up area in 2020 
y_train = train_bu_scaled[:, -1]
y_test  = test_bu_scaled[:, -1]





model = define_model(num_time_steps, dim_var_features, dim_cons_features)

model, history = model_fit(model, x_train_bu, x_train_elev, y_train,
                            x_test_bu, x_test_elev, y_test)


loss = history.history
epochs = range(len(loss)) 
plot_series(x = epochs, y = loss, title = 'MSE', xlabel = 'Epochs', legend = ['Train MSE', 'Validation MSE'])



y_train_hat = model.predict([x_train_bu.reshape((-1, 5, 5)), x_train_elev.reshape((-1, 4))], batch_size = 128)
y_test_hat  = model.predict([x_test_bu.reshape((-1, 5, 5)), x_test_elev.reshape((-1, 4))], batch_size = 128)



num_time_steps, dim_var_features, dim_cons_features = 5, 5, 4

transformed_y_train_values = invert_scale(bu_scaler, x_train_bu, y_train_hat) 
transformed_y_test_values  = invert_scale(bu_scaler, x_test_bu, y_test_hat)


raster_content = create_raster_content(train_ids, transformed_y_train_values, test_ids, transformed_y_test_values)



model_test = buPredictionModel(bu_feature_space_df, elev_feature_space_df, num_time_steps, 
                                dim_var_features, dim_cons_features)

train_ids, test_ids = model_test.train_test_id_extract()

train_bu, test_bu, train_elev, test_elev = model_test.train_test_extract(train_ids, test_ids)

cur_model = model_test.define()


# Scale the data into -1 to 1
bu_scaler, train_bu_scaled, test_bu_scaled = model_test.scale_features(train_bu, test_bu)
elev_scaler, x_train_elev, x_test_elev     = model_test.scale_features(train_elev, test_elev)


model, history = model_test.model_fit(cur_model, train_bu_scaled, x_train_elev, test_bu_scaled, x_test_elev)


model.save('trained_model')


train_predictions = model_test.model_predict(model, train_bu_scaled[:, :-1], x_train_elev)
test_predictions  = model_test.model_predict(model, test_bu_scaled[:, :-1], x_test_elev)


transformed_bu_train_predictions = model_test.invert_scale(bu_scaler, train_bu_scaled[:, :-1], train_predictions) 
transformed_bu_test_predictions  = model_test.invert_scale(bu_scaler, test_bu_scaled[:, :-1], test_predictions)



loss = history.history
epochs = range(len(loss['loss']))
model_test.plot_series(x = epochs, y = loss, title = 'MSE', xlabel = 'Epochs', legend = ['Train MSE', 'Validation MSE'])


raster_content = model_test.create_raster_content(train_ids, transformed_bu_train_predictions,
                                                  test_ids, transformed_bu_test_predictions)


with open(fs_dir / 'ml_outputs' / 'lstm1.pkl', 'wb') as write_file:
    pickle.dump(raster_content, write_file)