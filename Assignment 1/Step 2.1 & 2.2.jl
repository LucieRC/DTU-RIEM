#### CHANGE THE DIRECTORY OF THESE 3 CSVs ####

#Step 2.1 and 2.2

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames

model_step2 = Model(Gurobi.Optimizer)

## Reading data for wind
data_wind = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/mean_24h_zone1.csv", DataFrame)
data_wind2 = data_wind[1:43,2]

# Reading the data for demand 
data_demand = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/hourly_demands.csv", DataFrame, header=false)
data_demand2 = data_demand[1:24,2]
data_load = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/percentage_load.csv", DataFrame, header=false)
data_load2 = data_load[1:17,2]/100

## Sets and parameters
demands_scale = 1:17
demands = collect(demands_scale)
suppliers_scale = 1:18
suppliers = collect(suppliers_scale)
hours_scale = 1:24
hours = collect(hours_scale)
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11]
offer_price_suppliers = [0 0 0 0 0 0 13.32 13.32 20.7 20.93 26.11 10.52 10.52 6.02 5.47 7 10.52 10.89]
max_load_demands = data_load2*data_demand2'
max_power_production_wind_farm = [500 500 300 300 200 200]
charge_coeff = round.(data_wind2[1:24], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
max_power_generators = hcat(part1,part2)' 
electrolyzers = collect(1:2)

## Variables
@variable(model_step2, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step2, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(model_step2, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

## Objective
@objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)
- sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) for h in hours))

## Constraints
@constraint(model_step2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step2, cst_generators[s in suppliers, h in hours], power_generators[s,h] <= max_power_generators[s,h])
@constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_wind[e,h] for e in electrolyzers) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(model_step2, cst_electrolyzer_prod[e in electrolyzers], sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(model_step2, cst_max_electro_capacity[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2)
@constraint(model_step2, cst_max_electro_power[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= power_generators[e,h])

optimize!(model_step2)

# println("")
# println("MCP:")
# MCP = abs.(dual.(cst_equilibrium))
# println(MCP)

# println("")
# println("SW:")
# SW = sum(sum(bid_price[d]*load_demands[d,h] for d in demands) - sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) for h in hours)
# println(value.(SW))

# println("")
# println("Profit:")
# Profit = value.(sum(sum(power_generators[s,h]*(MCP[h]-offer_price_suppliers[s]) for s in suppliers) for h in hours))


# # For the Step4, we want:
# # DA_MCP_24h = abs.(dual.(cst_equilibrium))
# CSV.write("created_data/Step2.2_DA_MCP_24h.csv", Tables.table(MCP))
# DA_production_suppliers_24h = value.(power_generators)
# CSV.write("created_data/Step2.2_DA_production_suppliers_24h.csv", Tables.table(DA_production_suppliers_24h))
# DA_demands_24h = value.(load_demands)
# CSV.write("created_data/Step2.2_DA_demands_24h.csv", Tables.table(DA_demands_24h))
# # DA_thetas = value.(theta)
# # CSV.write("created_data/Step4.2.1_nodal_DA_thetas_24h.csv", Tables.table(DA_thetas))
# DA_electro = value.(power_to_electro_from_wind)
# CSV.write("created_data/Step2.2_DA_electro_24h.csv", Tables.table(DA_electro))