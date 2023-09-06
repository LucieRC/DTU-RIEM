using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames
Pkg.add("Distributions")
using Distributions

cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes")


step4_1 = Model(Gurobi.Optimizer)

# Transmission lines
transmission_lines = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/Assignment_codes/inputs/transmission_lines_with_susceptance.csv", DataFrame, delim=",")

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


# Results of DA model
DA_MCP_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_MCP_24h.csv", DataFrame, delim=","))
DA_production_suppliers_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_production_suppliers_24h.csv", DataFrame, delim=","))
DA_demands_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_demands_24h.csv", DataFrame, delim=","))
DA_thetas_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_thetas_24h.csv", DataFrame, delim=","))
DA_electro_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_electro_24h.csv", DataFrame, delim=",")[1:2,1:24])

## Sets and parameters
nb_demands = 17
nb_fossil = 12
nb_wind_farms = 6
nb_hours = 24
nb_nodes = 24
nb_transmission_lines = 34
demands_scale = 1:nb_demands
demands = collect(demands_scale)
electrolyzers = 1:2
suppliers_scale = 1:nb_fossil+nb_wind_farms
winds = collect(1:nb_wind_farms)
suppliers = collect(suppliers_scale)
hours_scale = 1:nb_hours
hours = collect(hours_scale)
conventional_generators = collect(7:18)
nodes_scale = 1:nb_nodes
nodes = collect(nodes_scale)
transmission_lines_scale = 1:nb_transmission_lines
transmissions = collect(transmission_lines_scale)
offer_price_wind = suppliers_nodes_max_gen[1:nb_wind_farms,"Offer_price"]
offer_price_gen_units = generating_units_details[:,"Ci"]
offer_price_suppliers = [offer_price_wind ; offer_price_gen_units]
nodes_gen_units = generating_units_details[:,"Node"]
demand_coeff = 
max_load_demands = percent_load_location2*load_profile_hours' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = suppliers_nodes_max_gen[1:nb_wind_farms,"P_max_i"]'
charge_coeff = round.(data_wind[1:24,"mean_charge"], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*suppliers_nodes_max_gen[nb_wind_farms+1:nb_fossil+nb_wind_farms,"P_max_i"]'
max_power_suppliers = hcat(part1,part2)' #(12)

# Electrolyzers parameters
electro = collect(1:2)
h2_per_MW = 18 #kg per 1MW
total_h2_production = 30000
price_per_h2_kg = 3
max_power_production_wind_farm = [500, 500, 300, 300, 200, 200]
max_electrolyzers = [250 250]

# Load load_curtailment
cost_curtailment = 500

# New parameters
down_cost_electro = 0.85*DA_MCP_24h
up_cost_electro = 1.1*DA_MCP_24h
forecast_std_error = zeros(6,nb_hours)
for w in winds, hour in hours
    forecast_std_error[w,hour] = 0.1*DA_production_suppliers_24h[w,hour] #carefull -> per hour
end

# Forecast errors generation
forecast_eps = zeros(nb_wind_farms,nb_hours)
for w in winds, hour in hours
    forecast_eps[w,hour] = rand(Normal(0, forecast_std_error[w,hour]))
end

# Build the lower/upper bounds for the production according to the conventional units and the DA results
# down_bound_prod = repeat([250],2,24) - DA_electro_24h #12-elt vector
min_matrix = repeat([250.0],2,24)
for e in 1:2, h in 1:24
    if DA_production_suppliers_24h[e,h] < min_matrix[e,h]
        min_matrix[e,h] = DA_production_suppliers_24h[e,h]
    end
end
down_bound_prod = min_matrix - DA_electro_24h #12-elt vector
up_bound_prod = DA_electro_24h


function get_the_connected_t_lines(node)
    """
    This function is helpfull to respect the transmission lines sign convention
    inputs: node of interest
    returns: smaller/bigger nodes t lines connected to it
    """
    smaller_nodes_t_lines = transmission_lines[transmission_lines[:,"To"].==node, "From"]
    bigger_nodes_t_lines = transmission_lines[transmission_lines[:,"From"].==node, "To"]
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
        sus_list = append!(sus_list, transmission_lines[transmission_lines[:,"From"].==node_n,:][transmission_lines[transmission_lines[:,"From"].==node_n,:][:,"To"].==node_m,:].Susceptance)
    catch
    end
    try
        sus_list = append!(sus_list, transmission_lines[transmission_lines[:,"From"].==node_m,:][transmission_lines[transmission_lines[:,"From"].==node_m,:][:,"To"].==node_n,:].Susceptance) 
    catch
    end
    return(sus_list[1])
end

function get_capacity_line(node_n,node_m)
    capa_list = []
    try
        capa_list = append!(capa_list, transmission_lines[transmission_lines[:,"From"].==node_n,:][transmission_lines[transmission_lines[:,"From"].==node_n,:][:,"To"].==node_m,:].Capacity)
    catch
    end
    try
        capa_list = append!(capa_list, transmission_lines[transmission_lines[:,"From"].==node_m,:][transmission_lines[transmission_lines[:,"From"].==node_m,:][:,"To"].==node_n,:].Capacity)
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
# @constraint(step4_1, total_variation[h in hours], sum(wind_spillage) - sum(load_curtailment) + sum(down) - sum(up) == before - after)
# @constraint(step4_1, cst_theta[n in nodes, h in hours], -pi <= DA_thetas_24h[n,h] + delta_theta[n,h] <= pi)
# @constraint(model_step2, cst_one_node_to_zero[h in hours],  DA_thetas_24h[n,h] + delta_theta[24,h] == 0)
# @constraint(model_step2, cst_electro_or_curtailment[n in nodes, h in hours], up_prod - down_bound_prod <= sum(load_curtailment[d,h] for d in demands))
# @constraint()

# for n in nodes, m in get_connected_nodes(n)
#     @constraint(step4_1, [h in hours],     
#         -get_capacity_line(n,m) <= get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) <= get_capacity_line(n,m))
# end

# for n in nodes, m in get_connected_nodes(n)
#     @constraint(step4_1, [h in hours],    
#         sum(DA_electro_24h[e,h] + down_prod[e,h] - up_prod[e,h] for e in connected_electrolyzers[n])   
#         - sum(DA_production_suppliers_24h[s,h] for s in [connected_wind[n]; connected_conventional[n]])  
#         + sum((DA_demands_24h[d,h] - load_curtailment[d,h]) for d in connected_demands[n])     
#         + sum(forecast_eps[w,h] for w in connected_wind[n])
#         + sum(get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h]))) == 0)
# end
@constraint(step4_1, market_equilibrium[n in nodes, h in hours],    
    sum(DA_electro_24h[e,h] + down_prod[e,h] - up_prod[e,h] for e in connected_electrolyzers[n])   
    - sum(DA_production_suppliers_24h[w,h] - wind_spillage[w,h] for w in connected_wind[n])
    - sum(DA_production_suppliers_24h[c,h] for c in connected_conventional[n])  
    + sum((DA_demands_24h[d,h] - load_curtailment[d,h]) for d in connected_demands[n])     
    + sum(forecast_eps[w,h] for w in connected_wind[n])
    + sum(get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) for m in get_connected_nodes(n)) == 0)


# @constraint(step4_1, market_eq[n in nodes, h in hours],
#     sum(down_prod[e,h] - up_prod[e,h] for e in connected_electrolyzers[n])     
#     + sum(forecast_eps[w,h] for w in connected_wind[n]) == 0 )
#     # + sum(get_susceptance_line(n,m)*(delta_theta[n,h] - delta_theta[m,h]) for m in get_connected_nodes(n)) == 0)

optimize!(step4_1)

# DA_MCP_24h = abs.(dual.(market_equilibrium))
CSV.write("created_data/Step4_1/wind_spillage.csv", Tables.table(value.(wind_spillage)))
CSV.write("created_data/Step4_1/DA_electro_24h.csv", Tables.table(value.(DA_electro_24h)))
CSV.write("created_data/Step4_1/down_prod.csv", Tables.table(value.(down_prod)))
CSV.write("created_data/Step4_1/up_prod.csv", Tables.table(value.(up_prod)))
CSV.write("created_data/Step4_1/load_curtailment.csv", Tables.table(value.(load_curtailment)))
