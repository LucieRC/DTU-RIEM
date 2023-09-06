import pandas as pd

demands_24h = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/demands_24h.csv")
demands_24h.head()


supplies_24h = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/supplies_24h.csv")
supplies_24h.head()


demands_24h.sum(0) - supplies_24h.sum(0)
