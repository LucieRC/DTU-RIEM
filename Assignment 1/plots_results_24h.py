import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

MCP_24h = np.array(pd.read_csv("../MCP_24h.csv"))
dmd_24 = np.array(pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/demands_24h.csv"))
supplies_24h = np.array(pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/supplies_24h.csv"))

fig, ax = plt.subplots()
ax.plot(np.linspace(0,23,24),MCP_24h)
ax.set_title()
ax.set_xlabel("Time (h)")
ax.set_ylabel("Market clearing price ($/MW)")


fig, ax = plt.subplots()
ax.plot(np.linspace(0,23,24),dmd_24)
ax.set_title()
ax.set_xlabel("Time (h)")
ax.set_ylabel("Demand")

total_demand_vector = []
for h in 0:23:
    total_demand_vector.append(sum(supplies_24h[d,h] for d in 1:18))

[sum(supplies_24h[d,h] for d in range(0,18)) for h in range(0,24)]
fig, ax = plt.subplots()
ax.plot(np.linspace(0,23,24),sum(supplies_24h[]))
ax.set_title()
ax.set_xlabel("Time (h)")
ax.set_ylabel("Demand")



