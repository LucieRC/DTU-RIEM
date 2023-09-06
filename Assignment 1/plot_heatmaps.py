import seaborn as sns
import pandas as pd
import matplotlib.pyplot as plt

# HEATMAP
nodes = list(range(1,25))
data = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/created_data/LUCIE_18.03_Step3_nodal_DA_MCP_24h.csv")
data["nodes"] = nodes
data = data.set_index("nodes")

sns.set(rc={"figure.figsize":(10, 8)})
sns.heatmap(data, annot=True) 

# CLASSICAL PLOT NODE PER NODE
hours = list(range(1,25))

fig, ax = plt.subplots()
for row in range(24):
    ax.plot(hours, data.iloc[row,:], label=f"Node {row+1}")
ax.set_xlabel("Time of the day (h)")
ax.set_ylabel("Market clearing price ($)")
ax.set_xlim(1,24)
ax.legend()

# CLASSICAL PLOT NODE PER ZONE
hours = list(range(1,25))
data = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/created_data/LUCIE_18.03_Step3_zonal_DA_MCP_24h.csv")

fig, ax = plt.subplots()
for zone in range(3):
    ax.plot(hours, data.iloc[zone,:], label=f"Zone {zone+1}")
ax.set_xlabel("Time of the day (h)")
ax.set_ylabel("Market clearing price ($)")
ax.set_xlim(1,24)
ax.legend()