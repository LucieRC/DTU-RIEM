using Pkg
# Pkg.add("Cbc")
# Pkg.add("CSV")
# Pkg.add("DataFrames")
# Pkg.add("DataFramesMeta")
using Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, DataFramesMeta

model_step3_zonal = Model(Gurobi.Optimizer)

## Wind
data_wind = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/mean_24h_zone1.csv", DataFrame)

# Demand 
load_profile = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/load_profile.csv", DataFrame, delim=" ")
load_profile_hours = load_profile[:,"System_demand"]
percent_load_location = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/demand_load_location_distrib.csv", DataFrame, delim=" ")
percent_load_location2 = percent_load_location[1:17,3]/100

# Transmission lines
transmission_lines = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/transmission_lines.csv", DataFrame, delim=" ")

# Generation units
generating_units_details = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/generating_units_without_units.csv", DataFrame)

# Suppliers
suppliers_nodes_max_gen = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/suppliers_nodes_max_gen.csv", DataFrame, delim=" ")

## Sets and parameters
nb_demands = 17
nb_fossil = 12
nb_wind_farms = 6
nb_hours = 24
nb_nodes = 24
nb_transmission_lines = 34
nb_zones = 3
demands_scale = 1:nb_demands
demands = collect(demands_scale)
suppliers_scale = 1:nb_fossil+nb_wind_farms
suppliers = collect(suppliers_scale)
hours_scale = 1:nb_hours
hours = collect(hours_scale)
zones_scale = 1:nb_zones
# bid_price = rand(10:50,17)
bid_price = [26.4 23.3 22.5 19.9 17.4 16.6 15 14 14 13.5 13.2 12.5 12 11.7 11 11 11] #rand(10:50,17)
zones_list = [1,2,3]
nodes_scale = 1:nb_nodes
nodes = collect(nodes_scale)
transmission_lines_scale = 1:nb_transmission_lines
zones_scale = 1:nb_zones
transmissions = collect(transmission_lines_scale)
zones = collect(zones_scale)
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
electrolyzers = collect(1:2)
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000 


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

# function get_description_node(node)
#     connected_suppliers = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"] # Int64[] if none
#     connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
#     connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
#     return(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
# end
function get_description_node(node)
    connected_electrolyzers = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].<3]
    connected_wind = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].<7]
    connected_conventional = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"][suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"].>6] # Int64[] if none
    connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_electrolyzers, connected_wind, connected_conventional, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

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
# end
# build_descriptions_for_nodes()
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
    # 1- get nodes in zone1
    nodes_z1 = [node for (node,zone) in nodes_to_zones if zone==zone1]
    # 2- get nodes in zone2
    nodes_z2 = [node for (node,zone) in nodes_to_zones if zone==zone2]
    # 3- go through the t_lines data and select the inter-zones t_lines
    t_lines_z1_z2 = @subset(transmission_lines, in(nodes_z1).(:From), in(nodes_z2).(:To))
    pt_between_zones = sum(t_lines_z1_z2.Capacity)
    return(pt_between_zones)
end

function is_s_in_zone(s,z)

end

function is_d_in_zone(d,z)

end

function is_e_in_zone(e,z)
    for n in nodes
        if n in [node for (node,zone) in nodes_to_zones if zone==z]
            if e in [connected_wind[n],connected_conventional[n]]
                return true
            end
        end
    end
    return false
end

function list_suppliers_in_zones()
    suppliers_in_zones = [[],[],[]]
    for unit_idx in suppliers_nodes_max_gen.Unit
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

max_power_trades_between_zones = zeros(Float64,nb_zones,nb_zones)
max_power_trades_between_zones[1,2] = get_power_trade_between_zones(1, 2)
max_power_trades_between_zones[2,3] = get_power_trade_between_zones(2, 3)
max_power_trades_between_zones[2,1] = get_power_trade_between_zones(1, 2)
max_power_trades_between_zones[3,2] = get_power_trade_between_zones(2, 3)
#1to2, 1to3, 2to3

## Variables
@variable(model_step3_zonal, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step3_zonal, power_suppliers[suppliers_scale, hours_scale] >= 0)
@variable(model_step3_zonal, transmitted[zones_scale, zones_scale, hours_scale])
@variable(model_step3_zonal, power_to_electro_from_wind[electrolyzers, hours_scale] >= 0) #power from the wind the electrolyzer is installed on
#the convention for the transmitted power is as follows:
# - from 1 to 2 (positive)
# - from 1 to 3 (positive)
# - from 2 to 3 (positive)

## Objective
@objective(model_step3_zonal, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands)   
    - sum(offer_price_suppliers[s]*power_suppliers[s,h] for s in suppliers) for h in hours))

# Constraints
@constraint(model_step3_zonal, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step3_zonal, cst_suppliers[s in suppliers, h in hours], power_suppliers[s,h] <= max_power_suppliers[s,h])
# for z1 in zones
#     for z2 in zones
#         for h in hours
#             print(z1,z2,h)
#             @constraint(model_step3_zonal,-max_power_trades_between_zones[z1,z2] <= transmitted[z1,z2,h] <= max_power_trades_between_zones[z1,z2])
#         end
#     end
# end
            # @constraint(model_step3_zonal, transmission_capacity[z1 in zones, z2 in zones, h in hours], -max_power_trades_between_zones[z1,z2] <= transmitted[z1,z2,h] <= max_power_trades_between_zones[z1,z2])
# @constraint(model_step3_zonal, cst_zones[z in zones, h in hours],    
#     - sum(power_suppliers[s,h] for s in connected_suppliers[n] if n in [node for (node,zone) in nodes_to_zones if zone==z])
#         + sum(load_demands[d,h] for d in connected_demands[n] if n in [node for (node,zone) in nodes_to_zones if zone==z])
#             - sum(transmitted[other_z,z,h] for other_z in [zones_list[i] for i in 1:length(zones_list) if i != z])
#                 + sum(transmitted[z,other_z,h] for other_z in [zones_list[i] for i in 1:length(zones_list) if i != z]) == 0)
@constraint(model_step3_zonal, cst_electrolyzer_prod[e in electrolyzers],    
    sum(power_to_electro_from_wind[e,h] for h in hours_scale)*h2_per_MW >= total_h2_production)
@constraint(model_step3_zonal, cst_max_electro_power1[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= power_suppliers[e,h])
@constraint(model_step3_zonal, cst_max_electro_power2[e in electrolyzers, h in hours],  
    power_to_electro_from_wind[e,h] <= max_power_production_wind_farm[e]/2)
# @constraint(model_step3_zonal, cst_one_node_to_zero[h in hours], theta[24,h]==0)
# @constraint(model_step3_zonal, cst_zones[n in nodes, z in zones, h in hours],    
#     - sum(power_suppliers[s,h] for s in [connected_wind[n],connected_conventional[n]] if n in [node for (node,zone) in nodes_to_zones if zone==z])
#     + sum(load_demands[d,h] for d in connected_demands[n] if n in [node for (node,zone) in nodes_to_zones if zone==z])
#     + sum(power_to_electro_from_wind[e,h] for e in connected_electrolyzers[n] if n in [node for (node,zone) in nodes_to_zones if zone==z])
#     - sum(transmitted[other_z,z,h] for other_z in [zones_list[i] for i in 1:length(zones_list) if i != z])
#     + sum(transmitted[z,other_z,h] for other_z in [zones_list[i] for i in 1:length(zones_list) if i != z]) == 0)
@constraint(model_step3_zonal, cst_zones[z in zones, h in hours],    
    - sum(power_suppliers[s,h] for s in suppliers_in_zones[z])
    + sum(load_demands[d,h] for d in demands_in_zones[z])
    + ((1 in suppliers_in_zones[z]) ? power_to_electro_from_wind[1,h] : 0)
    + ((2 in suppliers_in_zones[z]) ? power_to_electro_from_wind[2,h] : 0)
    # + sum( if 1 in suppliers_in_zones[z])
    # + sum(power_to_electro_from_wind[2,h] if 2 in suppliers_in_zones[z])
    - sum(transmitted[other_z,z,h] for other_z in [zones_list[i] for i in zones if i != z])
    + sum(transmitted[z,other_z,h] for other_z in [zones_list[i] for i in zones if i != z]) == 0)

optimize!(model_step3_zonal)

DA_MCP_24h = abs.(dual.(cst_zones))

# println("Optimal Solutions:")
# println("Bid price = ", bid_price)
# println("p_d = ", value.(load_demands))
# println("p_g = ", value.(power_suppliers))

# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h]) - offer_price_suppliers[s])*value.(power_suppliers)[s,h] for s in suppliers] for h in hours]'
# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h] - offer_price_suppliers[s])*value(power_suppliers[s,h]) for s in suppliers] for h in hours]
# utility_demand = [(bid_price[i] - abs(dual(cst_equilibrium)))*value.(load_demands)[i] for i in demands]'[8:12]

# println("Optimal Solutions:")
# # println("Bid price = ", bid_price)
# println("Power demands = ", value.(load_demands))
# println("Power produced by the suppliers = ", value.(power_suppliers))
# println("Sum power demands = ", sum(value.(load_demands)))
# println("Sum power produced by the suppliers = ", sum(value.(power_suppliers)))
# println("Social welfare: ", objective_value(model_step3_zonal))
# println("Market-clearing prices: ", abs.(dual.(cst_equilibrium[hours])))
# println("Profit suppliers: ", profit_suppliers)
# println("Utility demands: ", utility_demand)

# CSV.write("demands_24h.csv", Tables.table(value.(load_demands)))
# CSV.write("supplies_24h.csv", Tables.table(value.(power_suppliers)))
# CSV.write("MCP_24h.csv", Tables.table(abs.(dual.(cst_equilibrium[hours]))))
# CSV.write("profit_suppliers.csv", Tables.table(profit_suppliers))



# println("Objective value: ", objective_value(model_step3_zonal))

# abs(dual(equilibrium))

# has_dual(demands)

