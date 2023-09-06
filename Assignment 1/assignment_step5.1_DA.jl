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
nb_fossil = 12
nb_wind_farms = 6
wind_scale = 1:nb_wind_farms
wind = collect(wind_scale)
suppliers = collect(1:nb_fossil + nb_wind_farms)
suppliers_scale = 1:nb_fossil+nb_wind_farms
hours_scale = 1:24
hours = collect(hours_scale)
electro = collect(1:2)
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000
price_per_h2_kg = 3

# bid_price = rand(10:50,17)
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11]
offer_price_suppliers = [0 0 0 0 0 0 13.32 13.32 20.7 20.93 26.11 10.52 10.52 6.02 5.47 0 10.52 10.89] #(12)
# demand_coeff = 
max_load_demands = data_load2*data_demand2' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
power_electrolyzer = max_power_production_wind_farm/2
max_power_electrolyzers = [250 250]
charge_coeff = round.(data_wind2[1:24], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
max_power_generators = hcat(part1,part2)' #(12)
is_there_electro = [1 1 0 0 0 0]
bid_prices_electro = [30 30 0 0 0 0]



## Variables
@variable(model_step2, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step2, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(model_step2, power_to_electro_from_wind[wind_scale, hours_scale] >= 0) #power from the wind the electrolyzer is installed on
@variable(model_step2, power_to_electro_from_grid[wind_scale, hours_scale] >= 0) #additional power taken from the grid in case the wind power is not enough 
# @variable(model_step2, is_there_electro[wind_scale] >= 0, Bin)

## Objective
# @objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
# - sum(offer_price_suppliers[e]*(power_generators[e,h] - power_to_electro[e,h]) for e in electro)    
# - sum(offer_price_suppliers[s]*power_generators[s,h] for s in collect(3:18))    
# + sum(power_to_electro[e,h] for e in electro)*h2_per_MW*price_per_h2_kg for h in hours))
@objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
- sum(offer_price_suppliers[w]*(power_generators[w,h] - power_to_electro_from_wind[w,h]) for w in wind)   
- sum(offer_price_suppliers[s]*power_generators[s,h] for s in collect(7:18)) 
+ sum(power_to_electro_from_wind[w,h] + power_to_electro_from_grid[w,h] for w in wind)*h2_per_MW*price_per_h2_kg for h in hours))


# Constraints
@constraint(model_step2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step2, cst_generators[s in suppliers, h in hours], r_g_down[s,h] <= power_generators[s,h] <= max_power_generators[s,h] - r_g_up[s,h])
# @constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) - sum(offer_price_suppliers[e]*(power_generators[e,h] - power_to_electro[e,h]) for e in electro) - sum(offer_price_suppliers[s]*power_generators[s,h] for s in collect(3:18)) == 0) # modify
@constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_grid[w,h] for w in wind) - sum(power_generators[s,h] for s in suppliers) == 0)
# @constraint(model_step2, cst_electrolyzer_prod[w in wind], sum(is_there_electro[w]*(power_generators[w,h]<=power_electrolyzer[w,h] ? power_electrolyzer[w] : power_generators[w]/2) for h in hours_scale)*h2_per_MW >= is_there_electro[w]*total_h2_production)
# @constraint(model_step2, cst_electrolyzer_prod[e in electro], sum(power_to_electro[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(model_step2, cst_electrolyzer_prod[w in wind_scale], sum(power_to_electro_from_wind[w,h]+power_to_electro_from_grid[w,h] for h in hours_scale)*h2_per_MW >= is_there_electro[w]*total_h2_production)
#we need to make it understand that is_there_electro
#that way, we have to be higher than 0 or higher than the real constraint
#@constraint(model_step2, cst_max_electro_power[e in electro, h in hours], power_to_electro[e,h] <= power_generators[e,h])
@constraint(model_step2, cst_max_electro_power[w in wind, h in hours], power_to_electro_from_wind[w,h] <= power_generators[w,h])
# @constraint(model_step2, cst_nb_electro, sum(is_there_electro[w] for w in wind) >= 2)
@constraint(model_step2, cst_zeros_when_no_electro3[h in hours], power_to_electro_from_grid[3,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro4[h in hours], power_to_electro_from_grid[4,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro5[h in hours], power_to_electro_from_grid[5,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro6[h in hours], power_to_electro_from_grid[6,h] == 0)

@constraint(model_step2, cst_r_electro[e in electrolyzers, h in hours], r_e_down[e,h] <= power_to_electro_from_wind[e,h] + power_to_electro_from_grid[e,h] <= max_power_electrolyzers[e])

optimize!(model_step2)

# println("Optimal Solutions:")
# println("Bid price = ", bid_price)
# println("p_d = ", value.(load_demands))
# println("p_g = ", value.(power_generators))

# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h]) - offer_price_suppliers[s])*value.(power_generators)[s,h] for s in suppliers] for h in hours]'
# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h] - offer_price_suppliers[s])*value(power_generators[s,h]) for s in suppliers] for h in hours]
# utility_demand = [(bid_price[i] - abs(dual(cst_equilibrium)))*value.(load_demands)[i] for i in demands]'[8:12]

# println("Optimal Solutions:")
# # println("Bid price = ", bid_price)
# println("Power demands = ", value.(load_demands))
# println("Power produced by the suppliers = ", value.(power_generators))
# println("Sum power demands = ", sum(value.(load_demands)))
# println("Sum power produced by the suppliers = ", sum(value.(power_generators)))
# println("Social welfare: ", objective_value(model_step2))
# println("Market-clearing prices: ", abs.(dual.(cst_equilibrium[hours])))
# println("Profit suppliers: ", profit_suppliers)
# println("Utility demands: ", utility_demand)

# CSV.write("demands_24h.csv", Tables.table(value.(load_demands)))
# CSV.write("supplies_24h.csv", Tables.table(value.(power_generators)))
# CSV.write("MCP_24h.csv", Tables.table(abs.(dual.(cst_equilibrium[hours]))))
# CSV.write("profit_suppliers.csv", Tables.table(profit_suppliers))



# println("Objective value: ", objective_value(model_step2))

# abs(dual(equilibrium))

# has_dual(demands)

