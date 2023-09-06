import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

MCP_5_1 = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/created_data/SANTI_Step5.1_DA_MCP_24h.csv")

fig, ax = plt.subplots()
ax.plot(np.linspace(1,24,24), MCP_5_1.Column1)
ax.set_xlabel("Time of the day (h)")
ax.set_ylabel("MCP ($)")
