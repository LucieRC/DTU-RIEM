
# IMPORTS
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, Plots
#cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/GitHub/DTU-RIEM/Assignment 2")

#model.params.NonConvex = 2

# INPUTS
# Demand 
data_demand = CSV.read("inputs/2demand_load_location_distrib.csv", DataFrame, delim=",")
# Transmission lines
data_tlines = CSV.read("inputs/2transmission_lines_with_susceptance.csv", DataFrame, delim=",")
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
M = [4000, 150, 3500, 20000]
P_max_k = [200 400 300 250]
P_max_i = [155 100 155 197]
P_max_j = [337.5 350 210 80]
C_i = [15.2 23.4 15.2 19.1]
C_j = [0 5 20.1 24.7]
alpha_bid = [26.5 24.7 23.1 22.5]
D_max = [200 400 300 250]


# MODEL
model = Model(Gurobi.Optimizer)

@variable(model, alpha_offer_i[i in 1:4] >= 0)
@variable(model, alpha_offer_j[j in 1:4] >= 0)
@variable(model, d[k in 1:4])
@variable(model, p_i[i in 1:4])
@variable(model, p_j[i in 1:4])

@variable(model, mu_down_k[k in 1:4] >= 0)
@variable(model, mu_up_k[k in 1:4] >= 0)
@variable(model, mu_down_i[i in 1:4] >= 0)
@variable(model, mu_up_i[i in 1:4] >= 0)
@variable(model, mu_down_j[j in 1:4] >= 0)
@variable(model, mu_up_j[j in 1:4] >= 0)

@variable(model, eta_down_n_m[n in 1:6, m in 1:6] >= 0)
@variable(model, eta_up_n_m[n in 1:6, m in 1:6] >= 0)

@variable(model, lambda[n in 1:6])
@variable(model, theta[n in 1:6])
@variable(model, gamma)

@variable(model, psi_1[k in 1:4], Bin) 
@variable(model, psi_2[k in 1:4], Bin) 
@variable(model, psi_3[i in 1:4], Bin) 
@variable(model, psi_4[i in 1:4], Bin) 
@variable(model, psi_5[j in 1:4], Bin) 
@variable(model, psi_6[j in 1:4], Bin) 
@variable(model, psi_7[n in 1:6, m in 1:6], Bin) 
@variable(model, psi_8[n in 1:6, m in 1:6], Bin) 

@objective(model, Max,  - sum(p_i[i]*C_i[i] for i in 1:4)  
                        + sum(alpha_bid[k]*d[k] for k in 1:4)   
                        - sum(C_j[j]*p_j[j] for j in 1:4)
                        - sum(mu_up_k[k]*D_max[k] for k in 1:4)     
                        - sum(mu_up_j[j]*P_max_j[j] for j in 1:4)   
                        - sum((eta_down_n_m[n,m] + eta_up_n_m[n,m])*get_capacity_line(n,m) for n in 1:6 for m in get_connected_nodes(n)))
# @objective(model, Max, sum(mu_up_k[k]*D_max[k] for k in 1:4)     
#                         - sum(mu_up_i[i]*P_max_i[i] for i in 1:4)
#                         - sum(mu_up_j[j]*P_max_j[j] for j in 1:4)   
#                         - sum((eta_down_n_m[n,m] + eta_up_n_m[n,m])*get_capacity_line(n,m)*1000 for n in 1:6 for m in get_connected_nodes(n)))


@constraint(model, opti_cond1[k in 1:4], -alpha_bid[k] + mu_up_k[k] - mu_down_k[k] + lambda[demands_to_nodes[[k]]] == 0)
@constraint(model, opti_cond2[i in 1:4], alpha_offer_i[i] + mu_up_i[i] - mu_down_i[i] - lambda[strategic_to_nodes[[i]]] == 0)
@constraint(model, opti_cond3[j in 1:4], C_j[j] + mu_up_j[j] - mu_down_j[j] - lambda[non_strategic_to_nodes[[j+4]]] == 0)

for n in 1:6
    m_list = get_connected_nodes(n)
    @constraint(model, sum(get_susceptance_line(n,m)*(lambda[n] - lambda[m] + eta_up_n_m[n,m] + eta_down_n_m[n,m])  for m in m_list) + gamma == 0) #- eta_up_n_m[m,n]  - eta_down_n_m[m,n])
end 

@constraint(model, equality_cst1[n in 1:6], sum(d[k] for k in connected_demands[n]) + sum((theta[n] - theta[m]) for m in get_connected_nodes(n)) - sum((theta[m] - theta[n]) for m in get_connected_nodes(n)) - sum(p_i[i] for i in connected_strategic[n]) - sum(p_j[j] for j in connected_non_strategic[n].-4) == 0)
@constraint(model, equality_cst2, theta[1] == 0)

@constraint(model, compl_cst1_1[k in 1:4], 0 <= (P_max_k[k] - d[k]))
@constraint(model, compl_cst1_3[k in 1:4], (P_max_k[k] - d[k]) <= psi_1[k]*M[1])
@constraint(model, compl_cst1_4[k in 1:4], mu_up_k[k] <= (1-psi_1[k])*M[1])

@constraint(model, compl_cst2_1[k in 1:4], 0 <= d[k])
@constraint(model, compl_cst2_3[k in 1:4], d[k] <= psi_2[k]*M[1])
@constraint(model, compl_cst2_4[k in 1:4], mu_down_k[k] <= (1-psi_2[k])*M[1])

@constraint(model, compl_cst3_1[i in 1:4], 0 <= (P_max_i[i] - p_i[i]))
@constraint(model, compl_cst3_3[i in 1:4], (P_max_i[i] - p_i[i]) <= psi_3[i]*M[2])
@constraint(model, compl_cst3_4[i in 1:4], mu_up_i[i] <= (1-psi_3[i])*M[2])

@constraint(model, compl_cst4_1[i in 1:4], 0 <= p_i[i])
@constraint(model, compl_cst4_3[i in 1:4], p_i[i] <= psi_4[i]*M[2])
@constraint(model, compl_cst4_4[i in 1:4], mu_down_i[i] <= (1-psi_4[i])*M[2])

@constraint(model, compl_cst5_1[j in 1:4], 0 <= (P_max_j[j]-p_j[j]))
@constraint(model, compl_cst5_3[j in 1:4], (P_max_j[j]-p_j[j]) <= psi_5[j]*M[3])
@constraint(model, compl_cst5_4[j in 1:4], mu_up_j[j] <= (1-psi_5[j])*M[3])

@constraint(model, compl_cst6_1[j in 1:4], 0 <= p_j[j])
@constraint(model, compl_cst6_3[j in 1:4], p_j[j] <= psi_6[j]*M[3])
@constraint(model, compl_cst6_4[j in 1:4], mu_down_j[j] <= (1-psi_6[j])*M[3])

for n in 1:6, m in get_connected_nodes(n)
    @constraint(model, 0 <= (get_capacity_line(n,m) + (theta[n] - theta[m])))
    @constraint(model, (get_capacity_line(n,m) + (theta[n] - theta[m])) <= psi_7[n,m]*M[4])
    @constraint(model, eta_down_n_m[n,m] <= (1-psi_7[n,m])*M[4])
end 

for n in 1:6, m in get_connected_nodes(n)
    @constraint(model, 0 <= (get_capacity_line(n,m) - (theta[n] - theta[m])))
    @constraint(model, (get_capacity_line(n,m) - (theta[n] - theta[m])) <= psi_8[n,m]*M[4])
    @constraint(model, eta_up_n_m[n,m] <= (1-psi_8[n,m])*M[4])
end 


optimize!(model)

# value.(alpha_offer_i[1:4])