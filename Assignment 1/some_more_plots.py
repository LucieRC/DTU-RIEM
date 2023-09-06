import matplotlib.pyplot as plt
import pandas as pd


MCP_24h_with_no_h2_price = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/created_data/MCP_24h_with_h2_no_price.csv")



transmission_lines = pd.read_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/transmission_lines.csv", sep=" ")
transmission_lines["Susceptance"] = 1/transmission_lines["Reactance"]
transmission_lines.to_csv("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/transmission_lines_with_susceptance.csv")
