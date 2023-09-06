#### PLEASE CHANGE THE DIRECTORY OF THESE 4 CSVs ####

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames

model_step5_US = Model(Gurobi.Optimizer)

## Reading data for wind
data_wind = CSV.read("C:/Users/mscuc/Downloads/renewables_in_electricity_markets-master/inputs/mean_24h_zone1.csv", DataFrame)
data_wind2 = data_wind[1:43,2]

# Reading the data for demand 
data_demand = CSV.read("C:/Users/mscuc/Downloads/renewables_in_electricity_markets-master/inputs/hourly_demands.csv", DataFrame, header=false)
data_demand2 = data_demand[1:24,2]
data_load = CSV.read("C:/Users/mscuc/Downloads/renewables_in_electricity_markets-master/inputs/percentage_load.csv", DataFrame, header=false)
data_load2 = data_load[1:17,2]/100

upward_r_requirements = 0.2*data_demand.Column2
downward_r_requirements = 0.15*data_demand.Column2

# Generation units
generating_units_details = CSV.read("C:/Users/mscuc/Downloads/renewables_in_electricity_markets-master/inputs/generating_units_without_units.csv", DataFrame)
max_generators = suppliers_nodes_max_gen.P_max_i'
# prices_generators 
max_electrolyzers = [250, 250]
flex_electrolyzers = 0.5

# max_r_generators = flex.*max_generators
max_r_up_generators = vcat([0 0 0 0 0 0]', generating_units_details.R_plus_i)
max_r_down_generators = vcat([0 0 0 0 0 0]', generating_units_details.R_minus_i)
max_r_up_electrolyzers = flex_electrolyzers*max_electrolyzers' 
max_r_down_electrolyzers = flex_electrolyzers*max_electrolyzers'

# Cost up/downward reserves
C_g_up = vcat([0 0 0 0 0 0]', generating_units_details.C_plus_i)'
C_e_up = C_e_down = [1, 1] 
C_g_down = vcat([0 0 0 0 0 0]', generating_units_details.C_minus_i)'

## Sets and parameters
demands_scale = 1:17
demands = collect(demands_scale)
suppliers_scale = 1:18
generators = suppliers = collect(suppliers_scale)
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
@variable(model_step5_US, load_demands[demands, hours_scale] >= 0)
@variable(model_step5_US, power_generators[suppliers, hours_scale] >= 0)
@variable(model_step5_US, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

@variable(model_step5_US, r_g_up[suppliers_scale, hours_scale] >= 0)
@variable(model_step5_US, r_e_up[e in electrolyzers, h in hours] >= 0)
@variable(model_step5_US, r_g_down[suppliers_scale, hours_scale] >= 0)
@variable(model_step5_US, r_e_down[e in electrolyzers, h in hours] >= 0)

## Objective
@objective(model_step5_US, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands) - sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) 
    - sum(C_g_up[g]*r_g_up[g,h] for g in generators) 
    - sum(C_e_up[e]*r_e_up[e,h] for e in electrolyzers)
    - sum(C_g_down[g]*r_g_down[g,h] for g in generators)
    - sum(C_e_down[e]*r_e_down[e,h] for e in electrolyzers) for h in hours))

## Constraints
@constraint(model_step5_US, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step5_US, cst_generators1[s in suppliers, h in hours], r_g_down[s,h] <= power_generators[s,h])
@constraint(model_step5_US, cst_generators2[s in suppliers, h in hours], power_generators[s,h] <= max_power_generators[s,h] + r_g_up[s,h])
@constraint(model_step5_US, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_wind[e,h] for e in electrolyzers) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(model_step5_US, cst_electrolyzer_prod[e in electrolyzers], sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(model_step5_US, cst_max_electro_capacity1[e in electrolyzers, h in hours], r_e_up[e,h] <= power_to_electro_from_wind[e,h])
@constraint(model_step5_US, cst_max_electro_capacity2[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2 - r_e_down[e,h])
@constraint(model_step5_US, cst_max_electro_power[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= power_generators[e,h])

@constraint(model_step5_US, cst_system_down[h in hours], sum(r_g_up[g,h] for g in generators) + sum(r_e_up[e,h] for e in electrolyzers) == upward_r_requirements[h])
@constraint(model_step5_US, cst_system_up[h in hours], sum(r_g_down[g,h] for g in generators) + sum(r_e_down[e,h] for e in electrolyzers) == downward_r_requirements[h])

@constraint(model_step5_US, cst_g_up[g in generators, h in hours], 0 <= r_g_up[g,h] <= max_r_up_generators[g])
@constraint(model_step5_US, cst_g_down[g in generators, h in hours], 0 <= r_g_down[g,h] <= max_r_down_generators[g])
@constraint(model_step5_US, cst_e_up[e in electrolyzers, h in hours], 0 <= r_e_up[e,h] <= max_r_up_electrolyzers[e])
@constraint(model_step5_US, cst_e_down[e in electrolyzers, h in hours], 0 <= r_e_down[e,h] <= max_r_down_electrolyzers[e])

optimize!(model_step5_US)

Demand = value.(load_demands)
Supply = value.(power_generators)
Electro = value.(power_to_electro_from_wind)

Val_r_g_up = value.(r_g_up)
Val_r_g_down = value.(r_g_down)
Val_r_e_up = value.(r_e_up)
Val_r_e_down = value.(r_e_down)

println("")
println("MCP:")
MCP = println(abs.(dual.(cst_equilibrium)))

println("")
println("Social Welfare:")
SW = println(value.(sum(bid_price[d]*load_demands[d,:] for d in demands) - sum(offer_price_suppliers[s]*power_generators[s,:] for s in suppliers)))