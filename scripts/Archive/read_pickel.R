library(reticulate)
# use_virtualenv("r-reticulate")
# use_python("C:/Users/hzoraghein/Desktop/EC/venv/Scripts/python.exe")


Sys.setenv(RETICULATE_PYTHON = "C:/Users/hzoraghein/Desktop/EC/venv/Scripts/python.exe")

pd <- reticulate::import('pandas')

df <- pd$read_pickle("C:/Users/hzoraghein/Desktop/EC/ml_outputs/lstm1.pkl")
