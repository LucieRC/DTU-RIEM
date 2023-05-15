#Assignment 2 Step 2.1
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, Plots
cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/GitHub/DTU-RIEM/Assignment 2")


# INPUTS
# Demand 
data_demand = CSV.read("inputs/2demand_load_location_distrib.csv", DataFrame, delim=",")
# Transmission lines
data_tlines = CSV.read("inputs/step2_2_data_tlines.csv", DataFrame, delim=",")
# Generators
data_generators = CSV.read("inputs/2suppliers_nodes_max_gen.csv", DataFrame, delim=",")
# Hourly data
hourly_data = CSV.read("inputs/hourly_data.csv", DataFrame)


## Sets and parameters
alpha_bid = hourly_data[:,"avg_bid_price"]
alpha_bid1 = 1.06*alpha_bid
alpha_bid2 = 0.98*alpha_bid
alpha_bid3 = 0.92*alpha_bid
alpha_bid4 = 0.9*alpha_bid
alpha_bid = [alpha_bid1 alpha_bid2 alpha_bid3 alpha_bid4]'
P_max_k_hourly = Matrix(hourly_data[:,2:5])'
P_max = data_generators[1:8,"P_max_i"]
P_max_hourly = repeat(P_max',outer=[24])'
P_max_hourly[5,:] = hourly_data[:,"capa_factor_O1"]*450

offer_price_suppliers = data_generators[:,"Offer_price"]    #generator_costs 8-element vector - bid prices of generators
nodes_gen_units = data_generators[:,"Node"]                #8-element vector (node where unit is located in total there are 6 nodes and 8 gen units) 
max_power_suppliers = data_generators[:,"P_max_i"]          #8-element vector quantities offered by the 8 suppliers
nodes_load_demands = data_demand[:,"Node"]                        #4-element vector of nodes where demands are located

function get_the_connected_t_lines(node)
    """
    This function is helpfull to respect the transmission lines sign convention
    inputs: node of interest
    returns: smaller/bigger nodes t lines connected to it
    """
    smaller_nodes_t_lines = data_tlines[data_tlines[:,"To"].==node, "Idx"]
    bigger_nodes_t_lines = data_tlines[data_tlines[:,"From"].==node, "Idx"]
    return(smaller_nodes_t_lines, bigger_nodes_t_lines)
end

function get_connected_nodes(node)
    connected_nodes = data_tlines[data_tlines[:,"To"].==node, "From"]
    connected_nodes = vcat(connected_nodes,data_tlines[data_tlines[:,"From"].==node, "To"])
    return(connected_nodes)
end

function get_susceptance_line(node_n,node_m)
    #We have to try and grab one side or the other
    sus_list = []
    try
        sus_list = append!(sus_list, data_tlines[data_tlines[:,"From"].==node_n,:][data_tlines[data_tlines[:,"From"].==node_n,:][:,"To"].==node_m,:].Susceptance[1])
    catch
    end
    try
        sus_list = append!(sus_list, data_tlines[data_tlines[:,"From"].==node_m,:][data_tlines[data_tlines[:,"From"].==node_m,:][:,"To"].==node_n,:].Susceptance[1]) 
    catch
    end
    return(sus_list[1])
end

function get_capacity_line(node_n,node_m)
    capa_list = []
    try
        capa_list = append!(capa_list, data_tlines[data_tlines[:,"From"].==node_n,:][data_tlines[data_tlines[:,"From"].==node_n,:][:,"To"].==node_m,:].Capacity[1])
    catch
    end
    try
        capa_list = append!(capa_list, data_tlines[data_tlines[:,"From"].==node_m,:][data_tlines[data_tlines[:,"From"].==node_m,:][:,"To"].==node_n,:].Capacity[1])
    catch
    end    
    return(capa_list[1])
end

function get_description_node(node)
    connected_gen_units = data_generators[data_generators[:,"Node"].==node, "Unit"]
    connected_demands = data_demand[data_demand[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

function build_descriptions_for_nodes()
    connected_gen_units = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in 1:6
        (connected_gen_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_gen_units[node] = connected_gen_node
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
    return(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_gen_units, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()

model_2_5_ns = Model(Gurobi.Optimizer)

## Variables
@variable(model_2_5_ns, load_demands[d in 1:4, t in 1:24] >= 0)
@variable(model_2_5_ns, power_suppliers[s in 1:8, t in 1:24] >= 0)
@variable(model_2_5_ns, theta[n in 1:6, t in 1:24])

## Objective
@objective(model_2_5_ns, Max, sum(sum(alpha_bid[d,t]*load_demands[d,t] for d in 1:4)
                    - sum(offer_price_suppliers[s]*power_suppliers[s,t] for s in 1:8) for t in 1:24))

# Constraints
@constraint(model_2_5_ns, cst_demands[d in 1:4, t in 1:24], load_demands[d,t] <= P_max_k_hourly[d,t])
@constraint(model_2_5_ns, cst_suppliers[s in 1:8, t in 1:24], power_suppliers[s,t] <= P_max_hourly[s,t])
@constraint(model_2_5_ns, cst_one_node_to_zero[t in 1:24], theta[1,t]==0)

for t in 1:24, n in 1:6, m in get_connected_nodes(n)
    @constraint(model_2_5_ns,     
        -get_capacity_line(n,m) <= get_susceptance_line(n,m)*(theta[n,t] - theta[m,t]) <= get_capacity_line(n,m))
end


@constraint(model_2_5_ns, cst_nodes[n in 1:6, t in 1:24],
    - sum(power_suppliers[s,t] for s in connected_gen_units[n])
    + sum(load_demands[d,t] for d in connected_demands[n])
    + sum(get_susceptance_line(n,m)*(theta[n,t] - theta[m,t]) for m in get_connected_nodes(n)) == 0)

optimize!(model_2_5_ns)



# node_1 = dual.(cst_nodes)[1]    #MCP at node 1
# node_2 = dual.(cst_nodes)[2]
# node_3 = dual.(cst_nodes)[3]
# node_4 = dual.(cst_nodes)[4]
# node_5 = dual.(cst_nodes)[5]
# node_6 = dual.(cst_nodes)[6]

# sum(value.(power_suppliers))

# plot_MCP_2_5_ns = plot(1:24,value.(lambda[1,:]),xlabel="Hour of the day",ylabel="Strategic offer price",legend=false)
# savefig(plot_MCP_2_5_ns,"outputs/step_2_5_MCP_ns.png")


value.(cst_nodes)