#Assignment 2 Step 2.1
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, Plots

model_step_2_1 = Model(Gurobi.Optimizer)


# Demand 
load_location = CSV.read("C:/Users/Gabriel Fernandes/Desktop/Personal/_DTU/46755 Renewables in Electricity Markets/Julia Workspace/Assignment 2/Inputs/2demand_load_location_distrib.csv", DataFrame, delim=",")
# Transmission lines
transmission_lines = CSV.read("C:/Users/Gabriel Fernandes/Desktop/Personal/_DTU/46755 Renewables in Electricity Markets/Julia Workspace/Assignment 2/Inputs/2transmission_lines_with_susceptance.csv", DataFrame, delim=",")
# Generation units
generating_units_details = CSV.read("C:/Users/Gabriel Fernandes/Desktop/Personal/_DTU/46755 Renewables in Electricity Markets/Julia Workspace/Assignment 2/Inputs/2generating_units_without_units.csv", DataFrame)
# Suppliers
suppliers_nodes_max_gen = CSV.read("C:/Users/Gabriel Fernandes/Desktop/Personal/_DTU/46755 Renewables in Electricity Markets/Julia Workspace/Assignment 2/Inputs/2suppliers_nodes_max_gen.csv", DataFrame, delim=",")

## Sets and parameters

nb_demands = 4
nb_generators = 8

D_price = [26.5 24.7 23.1 22.5]
D_quantity = [200 400 300 250]

#wind farm output is 75% nominal capacity
generator_capacities = [155 100 155 197 337.5 350 210 80]
generator_costs = [15.2 23.4 15.2 19.1 0 5 20.1 24.7]

#nb_hours = 24
nb_nodes = 6
nb_transmission_lines = 8
demands_scale = 1:nb_demands
demands = collect(demands_scale)
suppliers_scale = 1:nb_generators
suppliers = collect(suppliers_scale)
nodes_scale = 1:nb_nodes
nodes = collect(nodes_scale)
transmission_lines_scale = 1:nb_transmission_lines
transmissions = collect(transmission_lines_scale)

offer_price_suppliers = vec(generator_costs) #generator_costs 8-element vector - bid prices of generators
nodes_gen_units = generating_units_details[:,"Node"] #8-element vector (node where unit is located in total there are 6 nodes and 8 gen units) 
max_power_suppliers = vec(generator_capacities) #8-element vector quantities offered by the 8 suppliers

offer_price_demads = vec(D_price) #4-elenebt vector of demand bids
max_load_demands = vec(D_quantity) #4-element vector of demand loads
nodes_load_demands = load_location[:,"Node"] #4-element vector of nodes where demands are located

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
    connected_gen_units = suppliers_nodes_max_gen[suppliers_nodes_max_gen[:,"Node"].==node, "Unit"]
    connected_demands = load_location[load_location[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

function build_descriptions_for_nodes()
    connected_gen_units = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in nodes_scale
        (connected_gen_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_gen_units[node] = connected_gen_node
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
    return(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()

## Variables
@variable(model_step_2_1, load_demands[demands_scale] >= 0)
@variable(model_step_2_1, power_suppliers[suppliers_scale] >= 0)
@variable(model_step_2_1, theta[nodes_scale])

## Objective
@objective(model_step_2_1, Max, sum(bid_price[d]*load_demands[d] for d in demands)
- sum(offer_price_suppliers[s]*power_suppliers[s] for s in suppliers))

# Constraints
@constraint(model_step_2_1, cst_demands[d in demands], load_demands[d] <= load_location[d , "Quantity"])
@constraint(model_step_2_1, cst_suppliers[s in suppliers], power_suppliers[s] <= max_power_suppliers[s])
@constraint(model_step_2_1, cst_one_node_to_zero, theta[1]==0)

for n in nodes
    for m in get_connected_nodes(n)
        @constraint(model_step_2_1,     
            -get_capacity_line(n,m)*1000 <= get_susceptance_line(n,m)*(theta[n] - theta[m]) <= get_capacity_line(n,m)*1000)
    end
end

@constraint(model_step_2_1, cst_nodes[n in nodes],
    - sum(power_suppliers[s] for s in connected_gen_units[n])
    + sum(load_demands[d] for d in connected_demands[n])
    + sum(get_susceptance_line(n,m)*(theta[n] - theta[m]) for m in get_connected_nodes(n)) == 0)

optimize!(model_step_2_1)

node_1 = dual.(cst_nodes)[1]
node_2 = dual.(cst_nodes)[2]
node_3 = dual.(cst_nodes)[3]
node_4 = dual.(cst_nodes)[4]
node_5 = dual.(cst_nodes)[5]
node_6 = dual.(cst_nodes)[6]

