import pandas as pd

data_zone1 = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/data/data/scen_zone1.csv", index_col=0)
data_zone1.head()

mean_24h_zone1 = data_zone1.mean(1) 
