#### IMPORTS
using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames



#### DATA
## Reading data for wind
data_wind = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/mean_24h_zone1.csv", DataFrame)
data_wind2 = data_wind[1:43,2]

# Reading the data for demand 
data_demand = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/hourly_demands.csv", DataFrame, header=false)
data_demand2 = data_demand[1:24,2]
data_load = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/percentage_load.csv", DataFrame, header=false)
data_load2 = data_load[1:17,2]/100
## Wind
data_wind = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/mean_24h_zone1.csv", DataFrame)
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
nb_demands = 17
nb_fossil = 12
nb_wind_farms = 6
nb_generators = nb_fossil + nb_wind_farms
max_load_demands = [84 75 139 58 55 106 97 132 135 150 205 150 245 77 258 141 100] #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
charge_coeff = 0.8 #vector of charge for the whole 24h
max_power_generators_step1 = hcat(0.8*max_power_production_wind_farm,[152 152 350 591 60 155 155 400 400 300 310 350]) #(12)
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
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11]
offer_price_suppliers = [0 0 0 0 0 0 13.32 13.32 20.7 20.93 26.11 10.52 10.52 6.02 5.47 7 10.52 10.89] #(12)
# demand_coeff = 
max_load_demands = data_load2*data_demand2' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
power_electrolyzer = max_power_production_wind_farm/2
charge_coeff = round.(data_wind2[1:24], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
max_power_generators = hcat(part1,part2)' #(12)

electrolyzers = collect(1:2)
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
charge_coeff = round.(data_wind2[1:24], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
max_power_generators = hcat(part1,part2)' #(12)
is_there_electro = [1 1 0 0 0 0]
bid_prices_electro = [30 30 0 0 0 0]

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
electrolyzers = collect(1:2)
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11] #rand(10:50,17)
nodes_scale = 1:nb_nodes
nodes = collect(nodes_scale)
transmission_lines_scale = 1:nb_transmission_lines
transmissions = collect(transmission_lines_scale)
offer_price_wind = suppliers_nodes_max_gen[1:nb_wind_farms,"Offer_price"]
offer_price_gen_units = generating_units_details[:,"Ci"]
offer_price_suppliers = [offer_price_wind ; offer_price_gen_units]
nodes_gen_units = generating_units_details[:,"Node"]
max_load_demands = percent_load_location2*load_profile_hours' #(17)
max_power_production_wind_farm = suppliers_nodes_max_gen[1:nb_wind_farms,"P_max_i"]'
charge_coeff = round.(data_wind[1:24,"mean_charge"], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*suppliers_nodes_max_gen[nb_wind_farms+1:nb_fossil+nb_wind_farms,"P_max_i"]'
max_power_suppliers = hcat(part1,part2)' #(12)
# Load load_curtailment
cost_curtailment = 500

nodes_to_zones = Dict(1 => 1, 
 2 => 1,  
 3 => 2,
 4 => 1,
 5 => 1,
 6 => 1,
 7 => 1,
 8 => 1,
 9 => 1,
 10 => 1,
 11 => 2,
 12 => 2,
 13 => 2,
 14 => 2,
 15 => 2,
 16 => 3,
 17 => 3,
 18 => 3,
 19 => 3,
 20 => 3,
 21 => 3,
 22 => 3,
 23 => 3,
 24 => 2)



 #### FUNCTIONS
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

function get_description_node(node)
    connected_electrolyzers = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].<3]
    connected_wind = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].<7]
    connected_conventional = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].>6] # Int64[] if none
    connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_electrolyzers, connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

function build_descriptions_for_nodes()
    connected_electrolyzers = Dict()
    connected_wind = Dict()
    connected_conventional = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in nodes_scale
        (connected_electrolyzers_node, connected_wind_node, connected_conventional_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_electrolyzers[node] = connected_electrolyzers_node
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_wind[node] = connected_wind_node
        connected_conventional[node] = connected_conventional_node
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
    return(connected_electrolyzers, connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_electrolyzers, connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()

function get_power_trade_between_zones(zone1, zone2)
    """Zone1 should be lower than Zone2 necessaraly for the naming convention 
    Carefull here the convention for the t_lines isn't the same as for the nodal model"""
    if zone1 == zone2
        return 0
    else
    # 1- get nodes in zone1
    nodes_z1 = [node for (node,zone) in nodes_to_zones if zone==zone1]
    # 2- get nodes in zone2
    nodes_z2 = [node for (node,zone) in nodes_to_zones if zone==zone2]
    # 3- go through the t_lines data and select the inter-zones t_lines
    t_lines_z1_z2 = @subset(transmission_lines, in(nodes_z1).(:From), in(nodes_z2).(:To))
    pt_between_zones = sum(t_lines_z1_z2.Capacity)
    return pt_between_zones
    end
end

function list_suppliers_in_zones()
    suppliers_in_zones = [[],[],[]]
    for unit_idx in suppliers_nodes_max_gen.Unit #all the suppliers indexes
        node = suppliers_nodes_max_gen[suppliers_nodes_max_gen.Unit.==unit_idx,"Node"][1] 
        zone = nodes_to_zones[node]
        append!(suppliers_in_zones[zone], unit_idx)
    end
    return suppliers_in_zones
end
suppliers_in_zones = list_suppliers_in_zones()

function list_demands_in_zones()
    demands_in_zones = [[],[],[]]
    for demand_idx in percent_load_location.Load
        node = percent_load_location[percent_load_location.Load.==demand_idx,"Node"][1]
        zone = nodes_to_zones[node]
        append!(demands_in_zones[zone], demand_idx)
    end
    return demands_in_zones
end
demands_in_zones = list_demands_in_zones()



#### STEP 1
step1 = Model(Gurobi.Optimizer)

## Variables
@variable(step1, load_demands[1:nb_demands] >= 0)
@variable(step1, power_generators[1:nb_generators] >= 0)

## Objective
@objective(step1, Max, sum(bid_price[d]*load_demands[d] for d=1:nb_demands) - sum(offer_prices_generators[g]*power_generators[g] for g=1:nb_generators))

# Constraints
@constraint(step1, demands[i=1:nb_demands], load_demands[i] <= max_load_demands[i])
@constraint(step1, generators[i=1:nb_generators], power_generators[i] <= max_power_generators_step1[i])
@constraint(step1, equilibrium, sum(load_demands[i] for i=1:nb_demands) - sum(power_generators[j] for j=1:nb_generators) == 0)

optimize!(step1)







#### STEP 2.2
## Variables
@variable(step2_2, load_demands[demands_scale, hours_scale] >= 0)
@variable(step2_2, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(step2_2, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

## Objective
@objective(step2_2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)
- sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) for h in hours))

## Constraints
@constraint(step2_2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(step2_2, cst_generators[s in suppliers, h in hours], power_generators[s,h] <= max_power_generators[s,h])
@constraint(step2_2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_wind[e,h] for e in electrolyzers) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(step2_2, cst_electrolyzer_prod[e in electrolyzers], sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(step2_2, cst_max_electro_capacity[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2)
@constraint(step2_2, cst_max_electro_power[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= power_generators[e,h])

optimize!(step2_2)


#### STEP 2.3
## Variables
@variable(step2_3, load_demands[demands_scale, hours_scale] >= 0)
@variable(step2_3, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(step2_3, power_to_electro_from_wind[wind_scale, hours_scale] >= 0)
@variable(step2_3, power_to_electro_from_grid[wind_scale, hours_scale] >= 0) 

## Objective
@objective(step2_3, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
    - sum(offer_price_suppliers[w]*(power_generators[w,h] - power_to_electro_from_wind[w,h]) for w in wind)   
    - sum(offer_price_suppliers[s]*power_generators[s,h] for s in collect(7:18)) 
    + sum(power_to_electro_from_wind[w,h] + power_to_electro_from_grid[w,h] for w in wind)*h2_per_MW*price_per_h2_kg for h in hours))

# Constraints
@constraint(step2_3, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(step2_3, cst_generators[s in suppliers, h in hours], power_generators[s,h] <= max_power_generators[s,h])
@constraint(step2_3, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_grid[w,h] for w in wind) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(step2_3, cst_electrolyzer_prod[w in wind_scale], sum(power_to_electro_from_wind[w,h]+power_to_electro_from_grid[w,h] for h in hours_scale)*h2_per_MW >= is_there_electro[w]*total_h2_production)
@constraint(step2_3, cst_max_electro_power[w in wind, h in hours], power_to_electro_from_wind[w,h] <= power_generators[w,h])
@constraint(step2_3, cst_zeros_when_no_electro3[h in hours], power_to_electro_from_grid[3,h] == 0)
@constraint(step2_3, cst_zeros_when_no_electro4[h in hours], power_to_electro_from_grid[4,h] == 0)
@constraint(step2_3, cst_zeros_when_no_electro5[h in hours], power_to_electro_from_grid[5,h] == 0)
@constraint(step2_3, cst_zeros_when_no_electro6[h in hours], power_to_electro_from_grid[6,h] == 0)

optimize!(step2_3)



#### STEP 3.1
## Variables
@variable(step3_1, load_demands[demands_scale, hours_scale] >= 0)
@variable(step3_1, power_suppliers[suppliers_scale, hours_scale] >= 0)
@variable(step3_1, theta[nodes_scale, hours_scale])
@variable(step3_1, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

## Objective
@objective(step3_1, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)
- sum(offer_price_suppliers[s]*power_suppliers[s,h] for s in suppliers) for h in hours))

# Constraints
@constraint(step3_1, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(step3_1, cst_suppliers[s in suppliers, h in hours], power_suppliers[s,h] <= max_power_suppliers[s,h])
@constraint(step3_1, cst_electrolyzer_prod[e in electrolyzers],    
    sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(step3_1, cst_max_electro_power1[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= power_suppliers[e,h])
@constraint(step3_1, cst_max_electro_power2[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2)
@constraint(step3_1, cst_one_node_to_zero[h in hours], theta[24,h]==0)
for n in nodes
    for m in get_connected_nodes(n)
        @constraint(step3_1, [h in hours],     
            -get_capacity_line(n,m) <= get_susceptance_line(n,m)*(theta[n,h] - theta[m,h]) <= get_capacity_line(n,m))
    end
end
@constraint(step3_1, cst_nodes[n in nodes, h in hours],
    - sum(power_suppliers[s,h] for s in [connected_conventional[n];connected_wind[n]])
    + sum(load_demands[d,h] for d in connected_demands[n])
    + sum(power_to_electro_from_wind[e,h] for e in connected_electrolyzers[n])
    + sum(get_susceptance_line(n,m)*(theta[n,h] - theta[m,h]) for m in get_connected_nodes(n)) == 0)

optimize!(step3_1)


#### STEP 3.2
max_power_trades_between_zones = zeros(Float64,nb_zones,nb_zones)
max_power_trades_between_zones[1,2] = get_power_trade_between_zones(1, 2)#*0.15
max_power_trades_between_zones[2,3] = get_power_trade_between_zones(2, 3)#*0.15
max_power_trades_between_zones[2,1] = get_power_trade_between_zones(1, 2)#*0.15
max_power_trades_between_zones[3,2] = get_power_trade_between_zones(2, 3)#*0.15

## Variables
@variable(step3_2, load_demands[demands_scale, hours_scale] >= 0)
@variable(step3_2, power_suppliers[suppliers_scale, hours_scale] >= 0)
@variable(step3_2, transmitted[zones_scale, zones_scale, hours_scale])
@variable(step3_2, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

## Objective
@objective(step3_2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
    - sum(offer_price_suppliers[s]*power_suppliers[s,h] for s in suppliers) for h in hours))

# Constraints
@constraint(step3_2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(step3_2, cst_suppliers[s in suppliers, h in hours], power_suppliers[s,h] <= max_power_suppliers[s,h])
@constraint(step3_2, cst_electrolyzer_prod[e in electrolyzers],    
    sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(step3_2, cst_max_electro_power1[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= power_suppliers[e,h])
@constraint(step3_2, cst_max_electro_power2[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2)
@constraint(step3_2, cst_equality_transmitted[z1 in zones, z2 in zones, h in hours], transmitted[z1,z2,h] == -transmitted[z2,z1,h])
@constraint(step3_2, cst_max_capacities[z1 in zones, z2 in zones, h in hours], -max_power_trades_between_zones[z1,z2] <= transmitted[z1,z2,h] <= max_power_trades_between_zones[z1,z2])

@constraint(step3_2, cst_zones[z in zones, h in hours],    
    - sum(power_suppliers[s,h] for s in suppliers_in_zones[z])
    + sum(load_demands[d,h] for d in demands_in_zones[z])
    + ((1 in suppliers_in_zones[z]) ? power_to_electro_from_wind[1,h] : 0)
    + ((2 in suppliers_in_zones[z]) ? power_to_electro_from_wind[2,h] : 0) 
    - sum(transmitted[other_z,z,h] for other_z in [zones_list[i] for i in zones if i != z])
    + sum(transmitted[z,other_z,h] for other_z in [zones_list[i] for i in zones if i != z]) == 0)

optimize!(step3_2)


#### STEP 4.1
# Results of DA model
DA_MCP_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_MCP_24h.csv", DataFrame, delim=","))
DA_production_suppliers_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_production_suppliers_24h.csv", DataFrame, delim=","))
DA_demands_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_demands_24h.csv", DataFrame, delim=","))
DA_thetas_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_thetas_24h.csv", DataFrame, delim=","))
DA_electro_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_electro_24h.csv", DataFrame, delim=",")[1:2,1:24])

# New parameters
cost_curtailment = 500
down_cost_electro = 0.85*DA_MCP_24h
up_cost_electro = 1.1*DA_MCP_24h

forecast_std_error = zeros(6,nb_hours)
for w in winds, hour in hours
    forecast_std_error[w,hour] = 0.1*DA_production_suppliers_24h[w,hour] #carefull -> per hour
end
forecast_eps = zeros(nb_wind_farms,nb_hours)
for w in winds, hour in hours
    forecast_eps[w,hour] = rand(Normal(0, forecast_std_error[w,hour]))
end
min_matrix = repeat([250.0],2,24)
for e in 1:2, h in 1:24
    if DA_production_suppliers_24h[e,h] < min_matrix[e,h]
        min_matrix[e,h] = DA_production_suppliers_24h[e,h]
    end
end
down_bound_prod = min_matrix - DA_electro_24h
up_bound_prod = DA_electro_24h

step4_1 = Model(Gurobi.Optimizer)

## Variables
@variable(step4_1, down_prod[e in electro, h in hours] >= 0)
@variable(step4_1, up_prod[e in electro, h in hours] >= 0)
@variable(step4_1, delta_theta[n in nodes, h in hours])
@variable(step4_1, wind_spillage[w in winds, h in hours] >= 0)
@variable(step4_1, load_curtailment[d in demands, h in hours] >= 0)

## Objective
@objective(step4_1, Min, sum(sum((up_cost_electro[e,h]*up_prod[e,h] - down_cost_electro[e,h]*down_prod[e,h]) for e in electrolyzers)    
    + cost_curtailment*sum(load_curtailment[d,h] for d in demands) for h in hours))

# Constraints
@constraint(step4_1, cst_down_prod[e in electro, h in hours], down_prod[e,h] <= down_bound_prod[e,h]) # + sum(wind_spillage[w,h] for w in winds)
@constraint(step4_1, cst_up_prod[e in electro, h in hours], up_prod[e,h] <= up_bound_prod[e,h]) #+ sum(load_curtailment[d,h] for d in demands) 
@constraint(step4_1, cst_load_curt[d in demands, h in hours], load_curtailment[d,h] <= DA_demands_24h[d,h])
@constraint(step4_1, cst_wind_spillage[w in winds, h in hours], wind_spillage[w,h] <= DA_production_suppliers_24h[w,h])
@constraint(step4_1, cst_electrolyzer_prod[e in electrolyzers],
    sum((DA_electro_24h[e,h] + down_prod[e,h] - up_prod[e,h]) for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(step4_1, market_equilibrium[n in nodes, h in hours],    
    sum(DA_electro_24h[e,h] + down_prod[e,h] - up_prod[e,h] for e in connected_electrolyzers[n])   
    - sum(DA_production_suppliers_24h[w,h] - wind_spillage[w,h] for w in connected_wind[n])
    - sum(DA_production_suppliers_24h[c,h] for c in connected_conventional[n])  
    + sum((DA_demands_24h[d,h] - load_curtailment[d,h]) for d in connected_demands[n])     
    + sum(forecast_eps[w,h] for w in connected_wind[n])
    + sum(get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) for m in get_connected_nodes(n)) == 0)

optimize!(step4_1)






#### STEP 4.2
chosen_hour = 12
failed_conventional = 3
# Results of DA model
DA_MCP_24h = Matrix(CSV.read("created_data/Step2.2_DA_MCP_24h.csv", DataFrame, delim=","))
DA_production_suppliers_24h = Matrix(CSV.read("created_data/Step2.2_DA_production_suppliers_24h.csv", DataFrame, delim=","))
DA_demands_24h = Matrix(CSV.read("created_data/Step2.2_DA_demands_24h.csv", DataFrame, delim=","))
DA_electro_24h = Matrix(CSV.read("created_data/Step2.2_DA_electro_24h.csv", DataFrame, delim=",")[1:2,1:24])
DA_conventional_24h = DA_production_suppliers_24h[7:18,:]
DA_wind_24h = DA_production_suppliers_24h[1:6,:]
production_cost_conventional = suppliers_nodes_max_gen[nb_wind_farms+1:18,"Offer_price"]/2
conventional = collect(1:12) # Conventional units informations
max_conventionals = max_power_suppliers[7:18,chosen_hour] # Max power conventional generators
down_cost_conventional = DA_MCP_24h[chosen_hour] .+ 0.15*production_cost_conventional
up_cost_conventional = DA_MCP_24h[chosen_hour] .+ 0.12*production_cost_conventional
forecast_std_error = zeros(6,nb_hours)
for w in winds, hour in hours
    forecast_std_error[w,hour] = 0.1/nb_wind_farms*sum(DA_production_suppliers_24h[w,hour]) #carefull -> per hour
end
forecast_eps = zeros(nb_wind_farms,nb_hours)
for w in winds, hour in hours
    forecast_eps[w,hour] = rand(Normal(0, forecast_std_error[w,hour]))
end

up_bound_prod = max_conventionals .- DA_conventional_24h[:,chosen_hour] #12-elt vector
down_bound_prod = DA_conventional_24h[:,chosen_hour]

step4_2 = Model(Gurobi.Optimizer)

## Variables
@variable(step4_2, down_prod[c in conventional] >= 0)
@variable(step4_2, up_prod[c in conventional] >= 0)
@variable(step4_2, load_curtailment[d in demands] >= 0)
@variable(step4_2, wind_spillage[w in winds] >= 0)

## Objective
@objective(step4_2, Min, sum(sum((up_cost_conventional[c]*up_prod[c] - down_cost_conventional[c]*down_prod[c]) for c in conventional)    
    + cost_curtailment*sum(load_curtailment[d] for d in demands)))

# Constraints
@constraint(step4_2, cst_down_prod[c in conventional], down_prod[c] <= down_bound_prod[c])
@constraint(step4_2, cst_up_prod[c in conventional], up_prod[c] <= up_bound_prod[c])
@constraint(step4_2, cst_conventional_outage1, down_prod[failed_conventional] == 0)
@constraint(step4_2, cst_conventional_outage2, up_prod[failed_conventional] == 0)
@constraint(step4_2, market_equ,    
    sum(DA_electro_24h[e,chosen_hour] for e in electro)   
    + sum((DA_demands_24h[d,chosen_hour] - load_curtailment[d]) for d in demands)
    - sum(DA_conventional_24h[c,chosen_hour] + down_prod[c] - up_prod[c] for c in conventional)  
    + DA_conventional_24h[failed_conventional,chosen_hour]     
    - sum(DA_wind_24h[w,chosen_hour] + forecast_eps[w,chosen_hour] for w in winds) == 0)

optimize!(step4_2)





#### STEP 5.1
upward_r_requirements = 0.2*data_demand.Column2
downward_r_requirements = 0.15*data_demand.Column2
flex_electrolyzers = 0.5
max_r_up_generators = generating_units_details.R_plus_i
max_r_down_generators = generating_units_details.R_minus_i
max_r_up_electrolyzers = flex_electrolyzers*max_electrolyzers' 
max_r_down_electrolyzers = flex_electrolyzers*max_electrolyzers'
C_g_up = generating_units_details.C_plus_i'
C_g_down = generating_units_details.C_minus_i'
C_e_up = C_e_down = [1,1]'

# Varibles
@variable(step5_1, r_g_up[g in generators, h in hours] >= 0)
@variable(step5_1, r_e_up[e in electrolyzers, h in hours] >= 0)
@variable(step5_1, r_g_down[g in generators, h in hours] >= 0)
@variable(step5_1, r_e_down[e in electrolyzers, h in hours] >= 0)

# Objective
@objective(step5_1, Min, sum(
    sum(C_g_up[g]*r_g_up[g,h] for g in generators) 
    + sum(C_e_up[e]*r_e_up[e,h] for e in electrolyzers)
    + sum(C_g_down[g]*r_g_down[g,h] for g in generators)
    + sum(C_e_down[e]*r_e_down[e,h] for e in electrolyzers) for h in hours))

# Constraints
@constraint(step5_1, cst_system_up[h in hours], sum(r_g_up[g,h] for g in generators) + sum(r_e_up[e,h] for e in electrolyzers) == upward_r_requirements[h])
@constraint(step5_1, cst_system_down[h in hours], sum(r_g_down[g,h] for g in generators) + sum(r_e_down[e,h] for e in electrolyzers) == downward_r_requirements[h])
@constraint(step5_1, cst_g_up[g in generators, h in hours], 0 <= r_g_up[g,h] <= max_r_up_generators[g])
@constraint(step5_1, cst_g_down[g in generators, h in hours], 0 <= r_g_down[g,h] <= max_r_down_generators[g])
@constraint(step5_1, cst_e_up[e in electrolyzers, h in hours], 0 <= r_e_up[e,h] <= max_r_up_electrolyzers[e])
@constraint(step5_1, cst_e_down[e in electrolyzers, h in hours], 0 <= r_e_down[e,h] <= max_r_down_electrolyzers[e])

optimize!(step5_1)

#### DAY AHEAD MARKET
model_step5_DA = Model(Gurobi.Optimizer)
r_g_up_a = value.(r_g_up)
r_g_up_a = Matrix(r_g_up_a)
r_g_up_a = vcat(zeros(6, size(r_g_up_a, 2)), r_g_up_a)
r_g_down_a = value.(r_g_down)
r_g_down_a = Matrix(r_g_down_a)
r_g_down_a = vcat(zeros(6, size(r_g_down_a, 2)), r_g_down_a)
r_e_up_a = value.(r_e_up)
r_e_up_a = Matrix(r_e_up_a)
r_e_down_a = value.(r_e_down) 
r_e_down_a = Matrix(r_e_down_a)

## Variables
@variable(model_step5_DA, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step5_DA, power_generators[suppliers_scale, hours_scale] >= 0)
@variable(model_step5_DA, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

## Objective
@objective(model_step5_DA, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)
- sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) for h in hours))

## Constraints
@constraint(model_step5_DA, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step5_DA, cst_generators[s in suppliers, h in hours], r_g_down_a[s,h] <= power_generators[s,h] <= max_power_generators[s,h] + r_g_up_a[s,h])
@constraint(model_step5_DA, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_wind[e,h] for e in electrolyzers) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(model_step5_DA, cst_electrolyzer_prod[e in electrolyzers], sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(model_step5_DA, cst_max_electro_capacity[e in electrolyzers, h in hours], r_e_up_a[e,h] <= power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2 - r_e_down_a[e,h])
@constraint(model_step5_DA, cst_max_electro_power[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= power_generators[e,h])

optimize!(model_step5_DA)








#### STEP 5.2
step5_2 = Model(Gurobi.Optimizer)
upward_r_requirements = 0.2*data_demand.Column2
downward_r_requirements = 0.15*data_demand.Column2
max_electrolyzers = [250, 250]
flex_electrolyzers = 0.5
max_r_up_generators = vcat([0 0 0 0 0 0]', generating_units_details.R_plus_i)
max_r_down_generators = vcat([0 0 0 0 0 0]', generating_units_details.R_minus_i)
max_r_up_electrolyzers = flex_electrolyzers*max_electrolyzers' 
max_r_down_electrolyzers = flex_electrolyzers*max_electrolyzers'
C_g_up = vcat([0 0 0 0 0 0]', generating_units_details.C_plus_i)'
C_e_up = C_e_down = [1, 1] 
C_g_down = vcat([0 0 0 0 0 0]', generating_units_details.C_minus_i)'

## Variables
@variable(step5_2, load_demands[demands, hours_scale] >= 0)
@variable(step5_2, power_generators[suppliers, hours_scale] >= 0)
@variable(step5_2, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on

@variable(step5_2, r_g_up[suppliers_scale, hours_scale] >= 0)
@variable(step5_2, r_e_up[e in electrolyzers, h in hours] >= 0)
@variable(step5_2, r_g_down[suppliers_scale, hours_scale] >= 0)
@variable(step5_2, r_e_down[e in electrolyzers, h in hours] >= 0)

## Objective
@objective(step5_2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands) - sum(offer_price_suppliers[s]*power_generators[s,h] for s in suppliers) 
    - sum(C_g_up[g]*r_g_up[g,h] for g in generators) 
    - sum(C_e_up[e]*r_e_up[e,h] for e in electrolyzers)
    - sum(C_g_down[g]*r_g_down[g,h] for g in generators)
    - sum(C_e_down[e]*r_e_down[e,h] for e in electrolyzers) for h in hours))

## Constraints
@constraint(step5_2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(step5_2, cst_generators1[s in suppliers, h in hours], r_g_down[s,h] <= power_generators[s,h])
@constraint(step5_2, cst_generators2[s in suppliers, h in hours], power_generators[s,h] <= max_power_generators[s,h] + r_g_up[s,h])
@constraint(step5_2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) + sum(power_to_electro_from_wind[e,h] for e in electrolyzers) - sum(power_generators[s,h] for s in suppliers) == 0)
@constraint(step5_2, cst_electrolyzer_prod[e in electrolyzers], sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(step5_2, cst_max_electro_capacity1[e in electrolyzers, h in hours], r_e_up[e,h] <= power_to_electro_from_wind[e,h])
@constraint(step5_2, cst_max_electro_capacity2[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2 - r_e_down[e,h])
@constraint(step5_2, cst_max_electro_power[e in electrolyzers, h in hours], power_to_electro_from_wind[e,h] <= power_generators[e,h])
@constraint(step5_2, cst_system_down[h in hours], sum(r_g_up[g,h] for g in generators) + sum(r_e_up[e,h] for e in electrolyzers) == upward_r_requirements[h])
@constraint(step5_2, cst_system_up[h in hours], sum(r_g_down[g,h] for g in generators) + sum(r_e_down[e,h] for e in electrolyzers) == downward_r_requirements[h])
@constraint(step5_2, cst_g_up[g in generators, h in hours], 0 <= r_g_up[g,h] <= max_r_up_generators[g])
@constraint(step5_2, cst_g_down[g in generators, h in hours], 0 <= r_g_down[g,h] <= max_r_down_generators[g])
@constraint(step5_2, cst_e_up[e in electrolyzers, h in hours], 0 <= r_e_up[e,h] <= max_r_up_electrolyzers[e])
@constraint(step5_2, cst_e_down[e in electrolyzers, h in hours], 0 <= r_e_down[e,h] <= max_r_down_electrolyzers[e])

optimize!(step5_2)