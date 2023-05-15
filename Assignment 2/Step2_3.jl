# IMPORTS
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, Plots

# include("Step2_2_v3.jl")
# optimize!(m2_2)
# power_flow_2_4 = value.(get_susceptance_line(2,4)*(theta[2] - theta[4]))
# power_flow_3_6 = value.(get_susceptance_line(3,6)*(theta[3] - theta[6]))


# power_flow_2_4 = 50
# power_flow_3_6 = 50
# INPUTS
# Demand 
data_demand = CSV.read("inputs/2demand_load_location_distrib.csv", DataFrame, delim=",")
# Transmission lines
data_tlines = CSV.read("inputs/step2_3_data_tlines.csv", DataFrame, delim=",")
# Generators
data_generators = CSV.read("inputs/2suppliers_nodes_max_gen.csv", DataFrame, delim=",")
# Generators details
data_generators_details = CSV.read("inputs/2generating_units_without_units.csv", DataFrame)



# FUNCTIONS
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
    strategic_supply = data_generators[data_generators[:,"Strategic"].== true, :]
    non_strategic_supply = data_generators[data_generators[:,"Strategic"].== false, :]
    connected_strategic = strategic_supply[strategic_supply[:,"Node"].==node, "Unit"]
    connected_non_strategic = non_strategic_supply[non_strategic_supply[:,"Node"].==node, "Unit"]
    connected_demands = data_demand[data_demand[:,"Node"].==node,"Load"] # Int64[] if none
    connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines = get_the_connected_t_lines(node)
    return(connected_strategic, connected_non_strategic, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end

function build_descriptions_for_nodes()
    connected_strategic = Dict()
    connected_non_strategic = Dict()
    connected_demands = Dict() #Array{Float64}(undef, nb_nodes)
    connected_smaller_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    connected_bigger_nodes_t_lines = Dict() #Array{Float64}(undef, nb_nodes)
    for node in 1:6
        (connected_strategic_node, connected_non_strategic_node, connected_demands_node, connected_smaller_nodes_t_lines_node, connected_bigger_nodes_t_lines_node) = get_description_node(node)
        connected_strategic[node] = connected_strategic_node
        connected_non_strategic[node] = connected_non_strategic_node
        connected_demands[node] = connected_demands_node # append!(connected_suppliers,connected_suppliers_node)
        connected_smaller_nodes_t_lines[node] = connected_smaller_nodes_t_lines_node
        connected_bigger_nodes_t_lines[node] = connected_bigger_nodes_t_lines_node
    end
    return(connected_strategic, connected_non_strategic, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines)
end
(connected_strategic, connected_non_strategic, connected_demands, connected_smaller_nodes_t_lines, connected_bigger_nodes_t_lines) = build_descriptions_for_nodes()
 
strategic_to_nodes = Dict(value => key for (key, value) in connected_strategic)
non_strategic_to_nodes = Dict(value => key for (key, value) in connected_non_strategic)
demands_to_nodes = Dict(value => key for (key, value) in connected_demands)


# SETS AND PARAMETERS
M = [500, 10, 250, 10, 400, 100, 5000, 10000]
P_max_k = data_demand[:,"Quantity"]
P_max_i = data_generators[1:4,"P_max_i"]
P_max_j = data_generators[5:8,"P_max_i"]
C_i = data_generators[1:4,"Offer_price"]
C_j = data_generators[5:8,"Offer_price"]
alpha_bid = data_demand[:,"Bid_price"]
D_max = data_demand[:,"Quantity"]


# m2_3
m2_3 = Model(Gurobi.Optimizer)

@variable(m2_3, alpha_offer[i in 1:4] >= 0)
# @variable(m2_3, alpha_offer_j[j in 1:4] >= 0)
@variable(m2_3, d[k in 1:4] >= 0)
@variable(m2_3, p_i[i in 1:4] >= 0)
@variable(m2_3, p_j[i in 1:4] >= 0)

@variable(m2_3, mu_down_k[k in 1:4] >= 0)
@variable(m2_3, mu_up_k[k in 1:4] >= 0)
@variable(m2_3, mu_down_i[i in 1:4] >= 0)
@variable(m2_3, mu_up_i[i in 1:4] >= 0)
@variable(m2_3, mu_down_j[j in 1:4] >= 0)
@variable(m2_3, mu_up_j[j in 1:4] >= 0)

@variable(m2_3, eta_down_n_m[n in 1:6, m in 1:6] >= 0)
@variable(m2_3, eta_up_n_m[n in 1:6, m in 1:6] >= 0)

@variable(m2_3, lambda[n in 1:6])
@variable(m2_3, theta[n in 1:6])
@variable(m2_3, gamma)

@variable(m2_3, psi_1[k in 1:4], Bin) 
@variable(m2_3, psi_2[k in 1:4], Bin) 
@variable(m2_3, psi_3[i in 1:4], Bin) 
@variable(m2_3, psi_4[i in 1:4], Bin) 
@variable(m2_3, psi_5[j in 1:4], Bin) 
@variable(m2_3, psi_6[j in 1:4], Bin) 
@variable(m2_3, psi_7[n in 1:6, m in 1:6], Bin) 
@variable(m2_3, psi_8[n in 1:6, m in 1:6], Bin) 

@objective(m2_3, Max,  - sum(p_i[i]*C_i[i] for i in 1:4)  
                        + sum(alpha_bid[k]*d[k] for k in 1:4)   
                        - sum(C_j[j]*p_j[j] for j in 1:4)
                        - sum(mu_up_k[k]*D_max[k] for k in 1:4)     
                        - sum(mu_up_j[j]*P_max_j[j] for j in 1:4)   
                        - sum((eta_down_n_m[n,m] + eta_up_n_m[n,m])*get_capacity_line(n,m) for n in 1:6 for m in get_connected_nodes(n)))


@constraint(m2_3, min_offer_price[i in 1:4], alpha_offer[i] >= C_i[i])


@constraint(m2_3, opti_cond1[k in 1:4], -alpha_bid[k] + mu_up_k[k] - mu_down_k[k] + lambda[demands_to_nodes[[k]]] == 0)
@constraint(m2_3, opti_cond2[i in 1:4], alpha_offer[i] + mu_up_i[i] - mu_down_i[i] - lambda[strategic_to_nodes[[i]]] == 0)
@constraint(m2_3, opti_cond3[j in 1:4], C_j[j] + mu_up_j[j] - mu_down_j[j] - lambda[non_strategic_to_nodes[[j+4]]] == 0)

for n in 1:6
    m_list = get_connected_nodes(n)
    @constraint(m2_3, sum(get_susceptance_line(n,m)*(lambda[n] 
                                            - lambda[m] 
                                            + eta_up_n_m[n,m] 
                                            - eta_down_n_m[n,m]
                                            - eta_up_n_m[m,n] 
                                            + eta_down_n_m[m,n]
                                            ) for m in m_list) + gamma == 0) #- eta_up_n_m[m,n] - eta_down_n_m[m,n]
end 

@constraint(m2_3, equality_cst1[n in 1:6], sum(d[k] for k in connected_demands[n])  
                                + sum(get_susceptance_line(n,m)*(theta[n] - theta[m]) for m in get_connected_nodes(n)) 
                                - sum(get_susceptance_line(n,m)*(theta[m] - theta[n]) for m in get_connected_nodes(n)) 
                                - sum(p_i[i] for i in connected_strategic[n]) 
                                - sum(p_j[j] for j in connected_non_strategic[n].-4) == 0)
@constraint(m2_3, equality_cst2, theta[1] == 0)

@constraint(m2_3, compl_cst1_1[k in 1:4], 0 <= (P_max_k[k] - d[k]))
@constraint(m2_3, compl_cst1_3[k in 1:4], (P_max_k[k] - d[k]) <= psi_1[k]*M[1])
@constraint(m2_3, compl_cst1_4[k in 1:4], mu_up_k[k] <= (1-psi_1[k])*M[2])

@constraint(m2_3, compl_cst2_3[k in 1:4], d[k] <= psi_2[k]*M[1])
@constraint(m2_3, compl_cst2_4[k in 1:4], mu_down_k[k] <= (1-psi_2[k])*M[2])

@constraint(m2_3, compl_cst3_1[i in 1:4], 0 <= (P_max_i[i] - p_i[i]))
@constraint(m2_3, compl_cst3_3[i in 1:4], (P_max_i[i] - p_i[i]) <= psi_3[i]*M[3])
@constraint(m2_3, compl_cst3_4[i in 1:4], mu_up_i[i] <= (1-psi_3[i])*M[4])

@constraint(m2_3, compl_cst4_3[i in 1:4], p_i[i] <= psi_4[i]*M[3])
@constraint(m2_3, compl_cst4_4[i in 1:4], mu_down_i[i] <= (1-psi_4[i])*M[4])

@constraint(m2_3, compl_cst5_1[j in 1:4], 0 <= (P_max_j[j]-p_j[j]))
@constraint(m2_3, compl_cst5_3[j in 1:4], (P_max_j[j]-p_j[j]) <= psi_5[j]*M[5])
@constraint(m2_3, compl_cst5_4[j in 1:4], mu_up_j[j] <= (1-psi_5[j])*M[6])

@constraint(m2_3, compl_cst6_3[j in 1:4], p_j[j] <= psi_6[j]*M[5])
@constraint(m2_3, compl_cst6_4[j in 1:4], mu_down_j[j] <= (1-psi_6[j])*M[6])

for n in 1:6, m in get_connected_nodes(n)
    @constraint(m2_3, 0 <= (get_capacity_line(n,m) + get_susceptance_line(n,m)*(theta[n] - theta[m])))
    @constraint(m2_3, (get_capacity_line(n,m) + get_susceptance_line(n,m)*(theta[n] - theta[m])) <= psi_7[n,m]*M[7])
    @constraint(m2_3, eta_up_n_m[n,m] <= (1-psi_7[n,m])*M[8])
end 

for n in 1:6, m in get_connected_nodes(n)
    @constraint(m2_3, 0 <= (get_capacity_line(n,m) - get_susceptance_line(n,m)*(theta[n] - theta[m])))
    @constraint(m2_3, (get_capacity_line(n,m) - get_susceptance_line(n,m)*(theta[n] - theta[m])) <= psi_8[n,m]*M[7])
    @constraint(m2_3, eta_down_n_m[n,m] <= (1-psi_8[n,m])*M[8])
end 

# @constraint(m2_3, fix_2_4_flow, get_susceptance_line(2,4)*(theta[2] - theta[4]) == power_flow_2_4)
# @constraint(m2_3, fix_3_6_flow, get_susceptance_line(3,6)*(theta[3] - theta[6]) == power_flow_3_6)

optimize!(m2_3)

# value.(alpha_offer_i[1:4])

# MCP_node_hour = value.(reshape([lambda[n] for n in 1:6], 6, 1))
# CSV.write("outputs/step_2_3_MCP_node_hour.csv", Tables.table(MCP_node_hour))


# value.(lambda)


# println("")
# println("alpha_offer_i = ", value.(alpha_offer_i))
# println("d(demands) = ", value.(d))
# println("mu_up_k = ", value.(mu_up_k))
# println("mu_down_k = ", value.(mu_down_k))
# println("p_i = ", value.(p_i))
# println("mu_up_i = ", value.(mu_up_i))
# println("mu_down_i = ", value.(mu_down_i))
# println("p_j = ", value.(p_j))
# println("mu_up_j = ", value.(mu_up_j))
# println("mu_down_j = ", value.(mu_down_j))
# println("eta_down_n_m = ", value.(eta_down_n_m))


# sum(p_i[i]*(lambda[n]) for i in 1:4)


# value.(p_i)
# value.([lambda[strategic_to_nodes[[i]]] for i in 1:4])
# value.(alpha_offer)

total_profit = 0
for i in 1:4
    total_profit += value.(p_i[i]*(lambda[i]-C_i[i]))
end
total_profit

value.(alpha_offer)