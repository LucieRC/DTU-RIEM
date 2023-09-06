#### RESERVE MARKET

model_step5 = Model(Gurobi.Optimizer)

# Catch the up/downwards reserve requirements
data_demand = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/hourly_demands.csv", DataFrame, header=false)

# Suppliers
suppliers_nodes_max_gen = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/suppliers_nodes_max_gen.csv", DataFrame, delim=" ")

generators = collect(1:12)
electrolyzers = collect(1:2)
hours = collect(1:24)


upward_r_requirements = 0.2*data_demand.Column2
downward_r_requirements = 0.15*data_demand.Column2

# 25% 
# Generation units
generating_units_details = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/generating_units_without_units.csv", DataFrame)
max_generators = suppliers_nodes_max_gen.P_max_i'
# prices_generators 
max_electrolyzers = [250, 250]
flex_generators = [0 0 0 0 0 0 0.3 0.3 0.5 0.5 0.6 0.2 0.2 0.1 0.1 0 0.2 0.2]
flex_electrolyzers = 0.8

# max_r_generators = flex.*max_generators
max_r_up_generators = generating_units_details.R_plus_i
max_r_down_generators = generating_units_details.R_minus_i
max_r_up_electrolyzers = flex_electrolyzers*max_electrolyzers' 
max_r_down_electrolyzers = flex_electrolyzers*max_electrolyzers'

# Cost up/downward reserves
C_g_up = generating_units_details.C_plus_i
C_e_up = [1,1]
C_g_down = generating_units_details.C_minus_i
C_e_down = [1,1]

@variable(model_step5, r_g_up[g in generators, h in hours] >= 0)
@variable(model_step5, r_e_up[e in electrolyzers, h in hours] >= 0)
@variable(model_step5, r_g_down[g in generators, h in hours] >= 0)
@variable(model_step5, r_e_down[e in electrolyzers, h in hours] >= 0)

@objective(model_step5, Min, sum(
    sum(C_g_up[g]*r_g_up[g,h] for g in generators) 
    + sum(C_e_up[e]*r_e_up[e,h] for e in electrolyzers)
    + sum(C_g_down[g]*r_g_down[g,h] for g in generators)
    + sum(C_e_down[e]*r_e_down[e,h] for e in electrolyzers) for h in hours))


@constraint(model_step5, cst_system_down[h in hours], sum(r_g_up[g,h] for g in generators) + sum(r_e_up[e,h] for e in electrolyzers) == upward_r_requirements[h])
@constraint(model_step5, cst_system_up[h in hours], sum(r_g_down[g,h] for g in generators) + sum(r_e_down[e,h] for e in electrolyzers) == downward_r_requirements[h])

@constraint(model_step5, cst_g_up[g in generators, h in hours], 0 <= r_g_up[g,h] <= max_r_up_generators[g])
@constraint(model_step5, cst_g_down[g in generators, h in hours], 0 <= r_g_down[g,h] <= max_r_down_generators[g])
@constraint(model_step5, cst_e_up[e in electrolyzers, h in hours], 0 <= r_e_up[e,h] <= max_r_up_electrolyzers[e])
@constraint(model_step5, cst_e_down[e in electrolyzers, h in hours], 0 <= r_e_down[e,h] <= max_r_down_electrolyzers[e])

optimize!(model_step5)



#### DAY-AHEAD MARKET
