# Pkg.add("Cbc")
# Pkg.add("CSV")
# Pkg.add("DataFrames")
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames

model_step2 = Model(Gurobi.Optimizer)

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

function get_description_node(node)
    connected_suppliers = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"] # Int64[] if none
    connected_demands = percent_load_location[percent_load_location[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

function build_descriptions_for_nodes()
    connected_suppliers = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in nodes_scale
        (connected_suppliers_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_suppliers[node] = connected_suppliers_node
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
end
build_descriptions_for_nodes()

## Variables
@variable(model_step2, load_demands[demands_scale, hours_scale] >= 0)
@variable(model_step2, power_suppliers[suppliers_scale, hours_scale] >= 0)
@variable(model_step2, transmitted[transmission_lines_scale, hours_scale])

## Objective
@objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[d,h] for d in demands) - sum(offer_price_suppliers[s]*power_suppliers[s,h] for s in suppliers) for h in hours))

# Constraints
# demande_assouvie = load_demands[n,h]
# demande_effective = load_profile_hours[h]*percent_load_location[percent_load_location[:,"Node"].==n,"percent_of_system_load"]
@constraint(model_step2, cst_demands[d in demands, h in hours], load_demands[d,h] <= max_load_demands[d,h])
@constraint(model_step2, cst_suppliers[s in suppliers, h in hours], power_suppliers[s,h] <= max_power_suppliers[s,h])
# max_capacity_t_line_depart_node = sum(transmission_lines[transmission_lines[:,"From"].==t, "Capacity"])
@constraint(model_step2, transmission_capacity[t in transmissions, h in hours], -transmission_lines[transmission_lines[:,"Idx"].==t, "Capacity"][1] <= transmitted[t,h] <= transmission_lines[transmission_lines[:,"Idx"].==t, "Capacity"][1])
# @constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) - sum(power_suppliers[s,h] for s in suppliers) == 0)

@constraint(model_step2, cst_nodes[n in nodes, h in hours],    
    - sum(power_suppliers[s,h] for s in connected_suppliers[n])
        + sum(load_demands[d,h] for d in connected_demands[n])
            - sum(transmitted[t,h] for t in connected_smaller_nodes_t_lines[n])
                + sum(transmitted[t,h] for t in connected_bigger_nodes_t_lines[n]) == 0)

optimize!(model_step2)

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
# println("Social welfare: ", objective_value(model_step2))
# println("Market-clearing prices: ", abs.(dual.(cst_equilibrium[hours])))
# println("Profit suppliers: ", profit_suppliers)
# println("Utility demands: ", utility_demand)

# CSV.write("demands_24h.csv", Tables.table(value.(load_demands)))
# CSV.write("supplies_24h.csv", Tables.table(value.(power_suppliers)))
# CSV.write("MCP_24h.csv", Tables.table(abs.(dual.(cst_equilibrium[hours]))))
# CSV.write("profit_suppliers.csv", Tables.table(profit_suppliers))



# println("Objective value: ", objective_value(model_step2))

# abs(dual(equilibrium))

# has_dual(demands)

