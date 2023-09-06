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

# Demand 
load_profile = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/load_profile.csv", DataFrame, delim=" ")
load_profile_hours = load_profile[:,"System_demand"]
percent_load_location = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/demand_load_location_distrib.csv", DataFrame, delim=" ")
percent_load_location2 = percent_load_location[1:17,3]/100
# Transmission lines
transmission_lines = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/transmission_lines_with_susceptance.csv", DataFrame, delim=",")
# Generation units
generating_units_details = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/generating_units_without_units.csv", DataFrame)
# Suppliers
suppliers_nodes_max_gen = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/suppliers_nodes_max_gen.csv", DataFrame, delim=" ")



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
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000

# bid_price = rand(10:50,17)
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11]
offer_price_suppliers = [0 0 0 0 0 0 13.32 13.32 20.7 20.93 26.11 10.52 10.52 6.02 5.47 0 10.52 10.89] #(12)
# demand_coeff = 
max_load_demands = data_load2*data_demand2' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
# power_electrolyzer = max_power_production_wind_farm/2
charge_coeff = round.(data_wind2[1:24], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
max_power_generators = hcat(part1,part2)' #(12)

## Sets and parameters
nb_demands = 17
nb_fossil = 12
nb_wind_farms = 6
nb_hours = 24
nb_nodes = 24
nb_transmission_lines = 34
demands_scale = 1:nb_demands
demands = collect(demands_scale)
suppliers_scale = 1:nb_fossil+nb_wind_farms
suppliers = collect(suppliers_scale)
hours_scale = 1:nb_hours
hours = collect(hours_scale)
bid_price = rand(10:50,17)
nodes_scale = 1:nb_nodes
nodes = collect(nodes_scale)
transmission_lines_scale = 1:nb_transmission_lines
transmissions = collect(transmission_lines_scale)
offer_price_wind = suppliers_nodes_max_gen[1:nb_wind_farms,"Offer_price"]
offer_price_gen_units = generating_units_details[:,"Ci"]
offer_price_suppliers = [offer_price_wind ; offer_price_gen_units]
nodes_gen_units = generating_units_details[:,"Node"]
# demand_coeff = 
max_load_demands = percent_load_location2*load_profile_hours' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = suppliers_nodes_max_gen[1:nb_wind_farms,"P_max_i"]'
charge_coeff = round.(data_wind[1:24,"mean_charge"], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*suppliers_nodes_max_gen[nb_wind_farms+1:nb_fossil+nb_wind_farms,"P_max_i"]'
max_power_suppliers = hcat(part1,part2)' #(12)
# Now I have to encode per node
# location_wind_farms = [3 5 16 21 7 23] #they go to the end of the generating_units file 


is_there_electro = [1 1 0 0 0 0]
bid_prices_electro = [30 30 0 0 0 0]
# nb_electro

function get_the_connected_t_lines(node)
    """
    This function is helpfull to respect the transmission lines sign convention
    inputs: node of interest
    returns: smaller/bigger nodes t lines connected to it
    """
    smaller_nodes_t_lines = transmission_lines[transmission_lines[:,"To"].==node, "Idx"]
    bigger_nodes_t_lines = transmission_lines[transmission_lines[:,"From"].==node, "Idx"]
    return(smaller_nodes_t_lines, bigger_nodes_t_lines)
end

function get_connected_nodes(node)
    connected_nodes = transmission_lines[transmission_lines[:,"To"].==node, "From"]
    connected_nodes = vcat(connected_nodes,transmission_lines[transmission_lines[:,"From"].==node, "To"])
    return(connected_nodes)
end

function get_susceptance_line(node_n,node_m)
    #We have to try and grab one side or the other
    sus_list = []
    try
        sus_list = append!(sus_list, transmission_lines[transmission_lines[:,"From"].==node_n,:][transmission_lines[transmission_lines[:,"From"].==node_n,:][:,"To"].==node_m,:].Susceptance[1])
    catch
    end
    try
        sus_list = append!(sus_list, transmission_lines[transmission_lines[:,"From"].==node_m,:][transmission_lines[transmission_lines[:,"From"].==node_m,:][:,"To"].==node_n,:].Susceptance[1]) 
    catch
    end
    return(sus_list[1])
end

function get_capacity_line(node_n,node_m)
    capa_list = []
    try
        capa_list = append!(capa_list, transmission_lines[transmission_lines[:,"From"].==node_n,:][transmission_lines[transmission_lines[:,"From"].==node_n,:][:,"To"].==node_m,:].Capacity[1])
    catch
    end
    try
        capa_list = append!(capa_list, transmission_lines[transmission_lines[:,"From"].==node_m,:][transmission_lines[transmission_lines[:,"From"].==node_m,:][:,"To"].==node_n,:].Capacity[1])
    catch
    end    
    return(capa_list[1])
end


# UPDATED DESCRIPTION
# function get_description_node(node)
#     connected_suppliers = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"] # Int64[] if none
#     connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
#     connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
#     return(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
# end
function get_description_node(node)
    connected_wind = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].<7]
    connected_conventional = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].>6] # Int64[] if none
    connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end


# UPDATED DESCRIPTION
# function build_descriptions_for_nodes()
#     connected_suppliers = Dict()
#     connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
#     connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
#     connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
#     for node in nodes_scale
#         (connected_suppliers_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
#         connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
#         connected_suppliers[node] = connected_suppliers_node
#         connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
#         connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
#     end
#     return(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
# end
# (connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()
function build_descriptions_for_nodes()
    connected_wind = Dict()
    connected_conventional = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in nodes_scale
        (connected_wind_node, connected_conventional_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_wind[node] = connected_wind_node
        connected_conventional[node] = connected_conventional_node
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
    return(connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()



## Variables
@variable(model_step2, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step2, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(model_step2, power_to_electro_from_wind[wind_scale, hours_scale] >= 0) #power from the wind the electrolyzer is installed on
@variable(model_step2, power_to_electro_from_grid[wind_scale, hours_scale] >= 0) #additional power taken from the grid in case the wind power is not enough 
# @variable(model_step2, is_there_electro[wind_scale] >= 0, Bin)
@variable(model_step2, theta[nodes_scale, hours_scale] >= 0)


## Objective
@objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
    # + sum(bid_prices_electro[w]*power_to_electro_from_grid[w,h] for w in wind)  
    - sum(offer_price_suppliers[w]*power_generators[w,h] for w in wind)   
    - sum(offer_price_suppliers[s]*power_generators[s,h] for s in collect(7:18))    
    + sum(power_to_electro_from_wind[w,h] + power_to_electro_from_grid[w,h] for w in wind)*h2_per_MW*price_per_h2_kg for h in hours))

# Constraints
@constraint(model_step2, cst_demands[d in demands, h in hours],     
    load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step2, cst_generators[s in suppliers, h in hours],    
    power_generators[s,h] <= max_power_generators[s,h])
# @constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_grid[w,h] for w in wind) - sum(power_generators[s,h] for s in suppliers) == 0)
# @constraint(model_step2, cst_electrolyzer_prod[w in wind_scale], sum(is_there_electro[w]*(power_generators[w,h]<=power_electrolyzer[w,h] ? power_electrolyzer[w] : power_generators[w]/2) for h in hours_scale)*h2_per_MW >= is_there_electro[w]*total_h2_production)
@constraint(model_step2, cst_electrolyzer_prod[w in wind_scale],    
    sum(power_to_electro_from_wind[w,h]+power_to_electro_from_grid[w,h] for h in hours_scale)*h2_per_MW >= is_there_electro[w]*total_h2_production)
#we need to make it understand that is_there_electro
#that way, we have to be higher than 0 or higher than the real constraint
@constraint(model_step2, cst_max_electro_power[w in wind, h in hours],  
    power_to_electro_from_wind[w,h] <= power_generators[w,h])
# @constraint(model_step2, cst_nb_electro, sum(is_there_electro[w] for w in wind_scale) >= 2)
@constraint(model_step2, cst_zeros_when_no_electro3[h in hours],    
    power_to_electro_from_wind[3,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro4[h in hours],    
    power_to_electro_from_wind[4,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro5[h in hours],    
    power_to_electro_from_wind[5,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro6[h in hours],    
    power_to_electro_from_wind[6,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro3_2[h in hours],    
    power_to_electro_from_grid[3,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro4_2[h in hours],    
    power_to_electro_from_grid[4,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro5_2[h in hours],    
    power_to_electro_from_grid[5,h] == 0)
@constraint(model_step2, cst_zeros_when_no_electro6_2[h in hours],    
    power_to_electro_from_grid[6,h] == 0)

for n in nodes
    for m in get_connected_nodes(n)
        @constraint(model_step2, [h in hours],     
            -get_capacity_line(n,m) <= get_susceptance_line(n,m)*(theta[n,h] - theta[m,h]) <= get_capacity_line(n,m))
    end
end

@constraint(model_step2, cst_nodes[n in nodes, h in hours],    
    - sum(power_generators[g,h] for g in [connected_wind[n]; connected_conventional[n]])
        + sum(load_demands[d,h] for d in connected_demands[n])
            + sum(power_to_electro_from_wind[w,h] for w in connected_wind[n])
                + sum(power_to_electro_from_grid[w,h] for w in connected_wind[n])
                    + sum(get_susceptance_line(n,m)*(theta[n,h] - theta[m,h]) for m in get_connected_nodes(n)) == 0)

@constraint(model_step2, cst_theta_ref[h in hours], theta[24,h] == 0)

optimize!(model_step2)

# For the Step4, we want:
DA_MCP_24h = abs.(dual.(cst_equilibrium))
CSV.write("created_data/Step4_DA_MCP_24h.csv", Tables.table(DA_MCP_24h))
DA_production_suppliers_24h = value.(power_suppliers)
CSV.write("created_data/Step4_DA_production_suppliers_24h.csv", Tables.table(DA_production_suppliers_24h))
DA_demands_24h = value.(load_demands)
CSV.write("created_data/Step4_DA_demands_24h.csv", Tables.table(DA_demands_24h))
DA_thetas = value.(theta)
CSV.write("created_data/Step4_DA_thetas.csv", Tables.table(DA_thetas))
DA_electro = value.(power_to_electro_from_wind) + value.(power_to_electro_from_grid)
value.(power_to_electro_from_wind)
value.(power_to_electro_from_grid)



# println("Optimal Solutions:")
# println("Bid price = ", bid_price)
# println("p_d = ", value.(load_demands))

# value.(power_to_electro_from_grid)

# new demand
value.(load_demands) .+ vcat(value.(power_to_electro_from_grid), zeros(11,24))
# power_generators #18*24 matrix
# println("p_g = ", value.(power_generators))

# value.(power_to_electro_from_wind)

#new supply
value.(power_generators) .- vcat(value.(power_to_electro_from_wind), zeros(12,24))
# add 18-6 lines to power_to_electro_from_wind

value.(power_generators)
CSV.write("DA_production_suppliers_24h.csv", Tables.table(power_generators))
# [dual.(cst_equilibrium)[h] for h in hours]
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
CSV.write("MCP_24h_with_h2_no_price.csv", Tables.table(abs.(dual.(cst_equilibrium[hours]))))
# CSV.write("profit_suppliers.csv", Tables.table(profit_suppliers))



# println("Objective value: ", objective_value(model_step2))

# abs(dual(equilibrium))

# has_dual(demands)

