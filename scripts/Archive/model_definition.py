
# Pacakages 
import sklearn
import numpy as np 
import pandas as pd 
import matplotlib.pyplot as plt
import tensorflow as tf
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, LSTM, Input, concatenate, Bidirectional
from tensorflow.python.ops import math_ops
from sklearn.preprocessing import MinMaxScaler


class buPredictionModel():

    def __init__(self, bu_feature_space, elev_feature_space, num_time_steps, dim_var_features, dim_cons_features):
        self.bu_feature_space   = bu_feature_space
        self.elev_feature_space = elev_feature_space
        self.num_time_steps     = num_time_steps
        self.dim_var_features   = dim_var_features
        self.dim_cons_features  = dim_cons_features
    

    def train_test_id_extract(self):
        
        # Randomly select 80% of points in each built-up category for training
        train_set = (self.bu_feature_space
                         .groupby('bu_category', group_keys = False)
                         .apply(lambda x: x.sample(frac = 0.8, random_state = np.random.RandomState(123))))
        train_ids = train_set.feature_id

        # Create the test set
        test_ids = np.asarray([test_id for test_id in self.bu_feature_space.feature_id if test_id not in train_ids]) 

        train_ids = train_ids.values

        return(train_ids, test_ids)

    
    def train_test_extract(self, train_ids, test_ids):
        bu_train = self.bu_feature_space.loc[train_ids, ~self.bu_feature_space.columns.isin(['feature_id', 'bu_category'])]
        bu_test  = self.bu_feature_space.loc[test_ids, ~self.bu_feature_space.columns.isin(['feature_id', 'bu_category'])]

        elev_train = self.elev_feature_space.loc[train_ids, ~self.elev_feature_space.columns.isin(['feature_id'])]
        elev_test  = self.elev_feature_space.loc[test_ids, ~self.elev_feature_space.columns.isin(['feature_id'])]

        return(bu_train, bu_test, elev_train, elev_test)


    def define(self):
        fst_input       = Input(batch_shape = (256, self.num_time_steps, self.dim_var_features))
        fst_lstm_output = LSTM(64)(fst_input)
        # snd_lstm_output = LSTM(128)(fst_lstm_output)
        # trd_lstm_output = LSTM(64)(snd_lstm_output)

        snd_input = Input(batch_shape = (256, self.dim_cons_features))
        fst_dense = Dense(64, activation = 'relu')(snd_input)

        concat = concatenate([fst_lstm_output, fst_dense])

        output = Dense(1)(concat)

        model = Model(inputs = [fst_input, snd_input], outputs = output)

        return(model)


    @staticmethod
    def scale_features(train, test):
        scaler = MinMaxScaler(feature_range = (-1, 1))
        scaler = scaler.fit(train)

        train_scaled = scaler.transform(train)
        test_scaled  = scaler.transform(test)

        return(scaler, train_scaled, test_scaled)


    
    def model_fit(self, model, train_bu_scaled, x_train_elev, test_bu_scaled, x_test_elev):

        # Separate built-up features from the target variable
        # Built-up area
        x_train_bu = train_bu_scaled[:, :-1]
        x_test_bu  = test_bu_scaled[:, :-1]


        # Target variable, which is built-up area in 2020 
        y_train = train_bu_scaled[:, -1]
        y_test  = test_bu_scaled[:, -1]


        x_train_bu   = x_train_bu.reshape((-1, self.num_time_steps, self.dim_var_features))
        x_train_elev = x_train_elev.reshape((-1, self.dim_cons_features))

        x_test_bu   = x_test_bu.reshape((-1, self.num_time_steps, self.dim_var_features))
        x_test_elev = x_test_elev.reshape((-1, self.dim_cons_features))


        model.compile(loss = 'mse', optimizer = tf.keras.optimizers.Adam(learning_rate=0.001))

        history = model.fit([x_train_bu, x_train_elev], y_train, epochs = 5, verbose = True,
                            validation_data = ([x_test_bu, x_test_elev], y_test))

        return(model, history) 


    @staticmethod
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

        plt.xticks(ticks = list(range(1,21)))

        if legend:
            plt.legend(legend)

        plt.title(title)

        plt.grid(True)

        plt.show()



    def model_predict(self, model, bu_features, elev_features):

        scaled_bu   = bu_features.reshape((-1, self.num_time_steps, self.dim_var_features))
        scaled_elev = elev_features.reshape((-1, self.dim_cons_features))
        
        
        predictions = model.predict([scaled_bu, scaled_elev], batch_size = 128)

        return(predictions) 



    @staticmethod
    def invert_scale(bu_scaler, bu_features, bu_predictions):

        X_y                = np.append(bu_features, bu_predictions, 1)
        transformed_values = np.round(bu_scaler.inverse_transform(X_y)[:, -1], 2) 

        return(transformed_values)


    @staticmethod
    def create_raster_content(train_ids, train_predictions, test_ids, test_predictions, output_path):
    
        # Create the raster to export to R
        train_outcome = np.hstack((np.expand_dims(train_ids, -1), np.expand_dims(train_predictions, -1)))
        test_outcome  = np.hstack((np.expand_dims(test_ids, -1), np.expand_dims(test_predictions, -1)))

        total_content = np.vstack((train_outcome, test_outcome))

        with open(output_path, 'wb') as write_file:
            pickle.dump(total_content, write_file)



def extract_pred_year(feature_space_df):

    first_selection  = feature_space_df.columns.map(len) == 7 * feature_space_df.columns.str.endswith('0')
    first_extraction = feature_space_df.columns[first_selection] 

    split_columns = first_extraction.str.split('_', expand=False)

    pred_year = max([year_column[1] for year_column in list(split_columns)])

    return(int(pred_year))