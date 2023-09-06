# Pkg.add("Cbc")
# Pkg.add("CSV")
# Pkg.add("DataFrames")
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames
Pkg.add("Distributions")
using Distributions

cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes")


model_step4 = Model(Gurobi.Optimizer)

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
# Results of DA model
DA_MCP_24h = CSV.read("created_data/Step3_nodal_DA_MCP_24h.csv", DataFrame, delim=",")
DA_production_suppliers_24h = CSV.read("created_data/Step3_nodal_DA_production_suppliers_24h.csv", DataFrame, delim=",")
DA_demands_24h = CSV.read("created_data/Step3_nodal_DA_demands_24h.csv", DataFrame, delim=",")
DA_thetas_24h = CSV.read("created_data/Step3_nodal_DA_thetas_24h.csv", DataFrame, delim=",")

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
conventional_generators = collect(1:12)
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
max_conventional_units = generating_units_details.P_max_i 


# New parameters
down_cost_conventional_generator = 0.1*DA_MCP_24h
up_cost_conventional_generator = 0.15*DA_MCP_24h
forecast_std_error = zeros(1,24)
for hour in hours
    forecast_std_error[hour] = 0.1/6*sum(DA_production_suppliers_24h[1:6,hour]) #carefull -> per hour
end

# Forecast errors generation
forecast_eps = zeros(1,24)
for hour in hours
    forecast_eps[hour] = rand(Normal(0, forecast_std_error[hour]))
end

# Build the lower/upper bounds for the production according to the conventional units and the DA results
down_bound_prod = DA_production_supplierxs_24h #12-elt vector
up_bound_prod = max_conventional_units - DA_production_suppliers_24h

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
    return(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_suppliers, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()

## Variables
@variable(model_step4, down_prod[c in conventional_generators, h in hours] >= 0)
@variable(model_step4, up_prod[c in conventional_generators, h in hours] >= 0)
@variable(model_step4, delta_theta[n in nodes, h in hours] >= 0)

## Objective
@objective(model_step4, Min, sum(up_cost_conventional_generator[h]*up_prod[c,h] - down_cost_conventional_generator[h]*down_prod[c,h] for c in conventional_generators for h in hours))

# Constraints
@constraint(model_step4, cst_demands[c in conventional_generators, h in hours], down_prod[c,h] <= down_bound_prod[c,h])
@constraint(model_step4, cst_suppliers[c in conventional_generators, h in hours], up_prod[c,h] <= up_bound_prod[c,h])

for n in nodes
    for m in get_connected_nodes(n)
        print(n,m)
        @constraint(model_step4, [h in hours],     
            -get_capacity_line(n,m) <= get_susceptance_line(n,m)*((theta[n,h]+delta_theta[n,h]) - (theta[m,h]+delta_theta[m,h])) <= get_capacity_line(n,m))
    end
end

@constraint(model_step4, market_equilibrium[n in nodes, h in hours],    
    sum(up_prod[c,h] - down_prod[c,h] for c in conventional_generators)     
    - sum(DA_production_suppliers_24h[s,h] for s in suppliers)  
    + sum(DA_demands_24h[d,h] for d in demands)     
    + forecast_eps[h]   
    + sum(get_susceptance_line(n,m)*((theta[n,h]+delta_theta[n,h]) - (theta[m,h]+delta_theta[m,h])) for m in get_connected_nodes(n)) == 0)

optimize!(model_step4)
