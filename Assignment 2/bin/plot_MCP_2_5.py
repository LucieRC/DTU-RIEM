import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

MCP_step_2_5 = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/GitHub/DTU-RIEM/Assignment 2/outputs/step_2_5_MCP_node_hour.csv")
MCP_step_2_5

fig, ax = plt.subplots(figsize=(4,3))
for i in range(6):
    ax.plot(MCP_step_2_5.iloc[i]) #list(range(24)), 