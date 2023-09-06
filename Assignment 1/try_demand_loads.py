import pandas as pd
import numpy as np

hourly_demand = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/hourly_demands.csv",index_col=0)
percentage_load = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/percentage_load.csv",index_col=0)

hourly_demand_array = np.array(hourly_demand)
percentage_load_array = np.array(percentage_load)