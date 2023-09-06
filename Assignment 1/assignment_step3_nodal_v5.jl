using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames

cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes")

step3_1 = Model(Gurobi.Optimizer)

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
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000


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
# @constraint(step3_1, theta_angle[n in nodes, h in hours], -pi <= theta[n,h] <= pi)
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

# For the Step4, we want:
DA_MCP_24h = abs.(dual.(cst_nodes))
CSV.write("created_data/LUCIE_18.03_Step3_nodal_DA_MCP_24h.csv", Tables.table(DA_MCP_24h))
DA_production_suppliers_24h = value.(power_suppliers)
CSV.write("created_data/LUCIE_18.03_Step3_nodal_DA_production_suppliers_24h.csv", Tables.table(DA_production_suppliers_24h))
DA_demands_24h = value.(load_demands)
CSV.write("created_data/LUCIE_18.03_Step3_nodal_DA_demands_24h.csv", Tables.table(DA_demands_24h))
DA_thetas = value.(theta)
CSV.write("created_data/LUCIE_18.03_Step3_nodal_DA_thetas_24h.csv", Tables.table(DA_thetas))
DA_electro = value.(power_to_electro_from_wind)
CSV.write("created_data/LUCIE_18.03_Step3_nodal_DA_electro_24h.csv", Tables.table(DA_electro))

