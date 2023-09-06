
step4_2 = Model(Gurobi.Optimizer)

chosen_hour = 12
failed_conventional = 3

# Results of DA model
DA_MCP_24h = Matrix(CSV.read("created_data/Step2.2_DA_MCP_24h.csv", DataFrame, delim=","))
DA_production_suppliers_24h = Matrix(CSV.read("created_data/Step2.2_DA_production_suppliers_24h.csv", DataFrame, delim=","))
DA_demands_24h = Matrix(CSV.read("created_data/Step2.2_DA_demands_24h.csv", DataFrame, delim=","))
DA_electro_24h = Matrix(CSV.read("created_data/Step2.2_DA_electro_24h.csv", DataFrame, delim=",")[1:2,1:24])
DA_conventional_24h = DA_production_suppliers_24h[7:18,:]
DA_wind_24h = DA_production_suppliers_24h[1:6,:]


# DA_MCP_1h = DA_MCP_24h[chosen_hour]
# DA_production_suppliers_1h = DA_production_suppliers_24h[:,chosen_hour]
# DA_demands_1h = DA_demands_24h[:,chosen_hour]
# DA_electro_1h = DA_electro_24h[:,chosen_hour]
# DA_conventional_1h = DA_conventional_24h[:,chosen_hour]
# DA_wind_1h = DA_wind_24h[:,chosen_hour]

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
# demand_coeff = 
max_load_demands = percent_load_location2*load_profile_hours' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = suppliers_nodes_max_gen[1:nb_wind_farms,"P_max_i"]'
charge_coeff = round.(data_wind[1:24,"mean_charge"], sigdigits=2) #vector of charge for the whole 24h
part1 = charge_coeff*max_power_production_wind_farm
part2 = ones(24,1)*suppliers_nodes_max_gen[nb_wind_farms+1:nb_fossil+nb_wind_farms,"P_max_i"]'
max_power_suppliers = hcat(part1,part2)' #(12)

# To be chosen on our own
production_cost_conventional = suppliers_nodes_max_gen[nb_wind_farms+1:18,"Offer_price"]/2

# Electrolyzers parameters
electro = collect(1:2)
# h2_per_MW = 18 #kg per 1MW
# total_h2_production = 30000
# price_per_h2_kg = 3
# max_power_production_wind_farm = [500, 500, 300, 300, 200, 200]
# max_electrolyzers = [250 250]

# Conventional units informations
conventional = collect(1:12)

# Load load_curtailment
cost_curtailment = 500

# Max power conventional generators
max_conventionals = max_power_suppliers[7:18,chosen_hour]

# New parameters
down_cost_conventional = DA_MCP_24h[chosen_hour] .+ 0.15*production_cost_conventional
up_cost_conventional = DA_MCP_24h[chosen_hour] .+ 0.12*production_cost_conventional
forecast_std_error = zeros(6,nb_hours)
for w in winds, hour in hours
    forecast_std_error[w,hour] = 0.1/nb_wind_farms*sum(DA_production_suppliers_24h[w,hour]) #carefull -> per hour
end
# Forecast errors generation
forecast_eps = zeros(nb_wind_farms,nb_hours)
for w in winds, hour in hours
    forecast_eps[w,hour] = rand(Normal(0, forecast_std_error[w,hour]))
end

# Build the lower/upper bounds for the production according to the conventional units and the DA results
up_bound_prod = max_conventionals .- DA_conventional_24h[:,chosen_hour] #12-elt vector
down_bound_prod = DA_conventional_24h[:,chosen_hour]


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

# for n in nodes
#     for m in get_connected_nodes(n)
#         @constraint(step4_2, [h in hours],     
#             -get_capacity_line(n,m) <= get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) <= get_capacity_line(n,m))
#     end
# end

# @constraint(step4_2, market_equilibrium[n in nodes, h in hours],    
#     sum(DA_electro_24h[e,h] for e in connected_electrolyzers[n])   
#     - sum(DA_conventional_24h[c,h] + down_prod[c,h] - up_prod[c,h] for c in connected_conventional[n].-6)  
#     + sum((DA_demands_24h[d,h] - load_curtailment[d,h]) for d in connected_demands[n])     
#     - sum(DA_wind_24h[w,h] + forecast_eps[w,h] for w in connected_wind[n]) == 0)
#     # + sum(get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) for m in get_connected_nodes(n)) == 0)

@constraint(step4_2, cst_conventional_outage1, down_prod[failed_conventional] == 0)
@constraint(step4_2, cst_conventional_outage2, up_prod[failed_conventional] == 0)

@constraint(step4_2, market_equ,    
    sum(DA_electro_24h[e,chosen_hour] for e in electro)   
    + sum((DA_demands_24h[d,chosen_hour] - load_curtailment[d]) for d in demands)
    - sum(DA_conventional_24h[c,chosen_hour] + down_prod[c] - up_prod[c] for c in conventional)  
    + DA_conventional_24h[failed_conventional,chosen_hour]     
    - sum(DA_wind_24h[w,chosen_hour] + forecast_eps[w,chosen_hour] for w in winds) == 0)
    # + sum(get_susceptance_line(n,m)*((DA_thetas_24h[n,h]+delta_theta[n,h]) - (DA_thetas_24h[m,h]+delta_theta[m,h])) for m in get_connected_nodes(n)) == 0)


optimize!(step4_2)

value.(market_equ)
