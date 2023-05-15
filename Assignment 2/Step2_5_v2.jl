
# IMPORTS
using Pkg, Gurobi, JuMP, DataFrames, Cbc, CSV, DataFrames, Plots


# INPUTS
# Demand 
data_demand = CSV.read("inputs/2demand_load_location_distrib.csv", DataFrame, delim=",")
# Transmission lines
data_tlines = CSV.read("inputs/step2_2_data_tlines.csv", DataFrame, delim=",")
# Generators
data_generators = CSV.read("inputs/2suppliers_nodes_max_gen.csv", DataFrame, delim=",")
# Hourly data
hourly_data = CSV.read("inputs/hourly_data.csv", DataFrame)


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
# M = [500, 154, 500, 10000]
M = [500, 10, 250, 10, 400, 100, 3000, 10]
# P_max_k = data_demand[:,"Quantity"]
P_max_k_hourly = Matrix(hourly_data[:,2:5])'
P_max_i = data_generators[1:4,"P_max_i"]
P_max_i_hourly = repeat(P_max_i',outer=[24])'
P_max_j = data_generators[5:8,"P_max_i"]
P_max_j_hourly = repeat(P_max_j',outer=[24])'
P_max_j_hourly[1,:] = hourly_data[:,"capa_factor_O1"]*450
C_i = data_generators[1:4,"Offer_price"]
C_i
C_j = data_generators[5:8,"Offer_price"]
percent_load = 0.01*data_demand[:,"Percent_system_load"]
alpha_bid = hourly_data[:,"avg_bid_price"]
alpha_bid1 = 1.06*alpha_bid
alpha_bid2 = 0.98*alpha_bid
alpha_bid3 = 0.92*alpha_bid
alpha_bid4 = 0.9*alpha_bid
alpha_bid = [alpha_bid1 alpha_bid2 alpha_bid3 alpha_bid4]'
D_max = data_demand[:,"Quantity"]
ramp_limits = data_generators[:,"Ramp_limit"]


# MODEL
m2_5 = Model(Gurobi.Optimizer)


# VARIABLES
@variable(m2_5, alpha_offer[i in 1:4, t in 1:24] >= 0)
@variable(m2_5, d[k in 1:4, t in 1:24])
@variable(m2_5, p_i[i in 1:4, t in 1:24])
@variable(m2_5, p_j[j in 1:4, t in 1:24])

@variable(m2_5, mu_down_k[k in 1:4, t in 1:24] >= 0)
@variable(m2_5, mu_up_k[k in 1:4, t in 1:24] >= 0)
@variable(m2_5, mu_down_i[i in 1:4, t in 1:24] >= 0)
@variable(m2_5, mu_up_i[i in 1:4, t in 1:24] >= 0)
@variable(m2_5, mu_down_j[j in 1:4, t in 1:24] >= 0)
@variable(m2_5, mu_up_j[j in 1:4, t in 1:24] >= 0)

@variable(m2_5, eta_down_n_m[n in 1:6, m in 1:6, t in 1:24] >= 0)
@variable(m2_5, eta_up_n_m[n in 1:6, m in 1:6, t in 1:24] >= 0)

@variable(m2_5, lambda[n in 1:6, t in 1:24])
@variable(m2_5, theta[n in 1:6, t in 1:24])
@variable(m2_5, gamma[t in 1:24])

@variable(m2_5, psi_1[k in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_2[k in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_3[i in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_4[i in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_5[j in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_6[j in 1:4, t in 1:24], Bin) 
@variable(m2_5, psi_7[n in 1:6, m in 1:6, t in 1:24], Bin) 
@variable(m2_5, psi_8[n in 1:6, m in 1:6, t in 1:24], Bin) 


# OBJECTIVE
@objective(m2_5, Max,  sum(- sum(p_i[i,t]*C_i[i] for i in 1:4)  
                        + sum(alpha_bid[k,t]*d[k,t] for k in 1:4)   
                        - sum(C_j[j]*p_j[j,t] for j in 1:4)
                        - sum(mu_up_k[k,t]*D_max[k] for k in 1:4)     
                        - sum(mu_up_j[j,t]*P_max_j_hourly[j,t] for j in 1:4)   
                        - sum((eta_down_n_m[n,m,t] + eta_up_n_m[n,m,t])*get_capacity_line(n,m) for n in 1:6 for m in get_connected_nodes(n)) for t in 1:24))


# CONSTRAINTS
@constraint(m2_5, opti_cond1[k in 1:4, t in 1:24], -alpha_bid[k,t] + mu_up_k[k,t] - mu_down_k[k,t] + lambda[demands_to_nodes[[k]],t] == 0)
@constraint(m2_5, opti_cond2[i in 1:4, t in 1:24], alpha_offer[i,t] + mu_up_i[i,t] - mu_down_i[i] - lambda[strategic_to_nodes[[i]],t] == 0)
@constraint(m2_5, opti_cond3[j in 1:4, t in 1:24], C_j[j] + mu_up_j[j,t] - mu_down_j[j,t] - lambda[non_strategic_to_nodes[[j+4]],t] == 0)

for t in 1:24, n in 1:6
    m_list = get_connected_nodes(n)
    @constraint(m2_5, sum(get_susceptance_line(n,m)*(lambda[n,t] - lambda[m,t] + eta_up_n_m[n,m,t] + eta_down_n_m[n,m,t]) for m in m_list) + gamma[t] == 0) #- eta_up_n_m[m,n] - eta_down_n_m[m,n]
end 

@constraint(m2_5, equality_cst1[n in 1:6, t in 1:24], sum(d[k,t] for k in connected_demands[n]) + sum(get_susceptance_line(n,m)*(theta[n,t] - theta[m,t]) for m in get_connected_nodes(n)) - sum(get_susceptance_line(n,m)*(theta[m,t] - theta[n,t]) for m in get_connected_nodes(n)) - sum(p_i[i,t] for i in connected_strategic[n]) - sum(p_j[j,t] for j in connected_non_strategic[n].-4) == 0)
@constraint(m2_5, equality_cst2[t in 1:24], theta[1,t] == 0)

@constraint(m2_5, compl_cst1_1[k in 1:4, t in 1:24], 0 <= (P_max_k_hourly[k,t] - d[k,t]))
@constraint(m2_5, compl_cst1_3[k in 1:4, t in 1:24], (P_max_k_hourly[k,t] - d[k,t]) <= psi_1[k,t]*M[1])
@constraint(m2_5, compl_cst1_4[k in 1:4, t in 1:24], mu_up_k[k,t] <= (1-psi_1[k,t])*M[2])

@constraint(m2_5, compl_cst2_1[k in 1:4, t in 1:24], 0 <= d[k,t])
@constraint(m2_5, compl_cst2_3[k in 1:4, t in 1:24], d[k,t] <= psi_2[k,t]*M[1])
@constraint(m2_5, compl_cst2_4[k in 1:4, t in 1:24], mu_down_k[k,t] <= (1-psi_2[k,t])*M[2])

@constraint(m2_5, compl_cst3_1[i in 1:4, t in 1:24], 0 <= (P_max_i_hourly[i,t] - p_i[i,t]))
@constraint(m2_5, compl_cst3_3[i in 1:4, t in 1:24], (P_max_i_hourly[i,t] - p_i[i,t]) <= psi_3[i,t]*M[3])
@constraint(m2_5, compl_cst3_4[i in 1:4, t in 1:24], mu_up_i[i,t] <= (1-psi_3[i,t])*M[4])

@constraint(m2_5, compl_cst4_1[i in 1:4, t in 1:24], 0 <= p_i[i,t])
@constraint(m2_5, compl_cst4_3[i in 1:4, t in 1:24], p_i[i,t] <= psi_4[i,t]*M[3])
@constraint(m2_5, compl_cst4_4[i in 1:4, t in 1:24], mu_down_i[i] <= (1-psi_4[i,t])*M[4])

@constraint(m2_5, compl_cst5_1[j in 1:4, t in 1:24], 0 <= (P_max_j_hourly[j,t]-p_j[j,t]))
@constraint(m2_5, compl_cst5_3[j in 1:4, t in 1:24], (P_max_j_hourly[j,t]-p_j[j,t]) <= psi_5[j,t]*M[5])
@constraint(m2_5, compl_cst5_4[j in 1:4, t in 1:24], mu_up_j[j,t] <= (1-psi_5[j,t])*M[6])

@constraint(m2_5, compl_cst6_1[j in 1:4, t in 1:24], 0 <= p_j[j,t])
@constraint(m2_5, compl_cst6_3[j in 1:4, t in 1:24], p_j[j,t] <= psi_6[j,t]*M[5])
@constraint(m2_5, compl_cst6_4[j in 1:4, t in 1:24], mu_down_j[j,t] <= (1-psi_6[j,t])*M[6])

for t in 1:24, n in 1:6, m in get_connected_nodes(n)
    @constraint(m2_5, 0 <= (get_capacity_line(n,m) + get_susceptance_line(n,m)*(theta[n,t] - theta[m,t])))
    @constraint(m2_5, (get_capacity_line(n,m) + get_susceptance_line(n,m)*(theta[n,t] - theta[m,t])) <= psi_7[n,m,t]*M[7])
    @constraint(m2_5, eta_down_n_m[n,m,t] <= (1-psi_7[n,m,t])*M[8])
end 

for t in 1:24, n in 1:6, m in get_connected_nodes(n)
    @constraint(m2_5, 0 <= (get_capacity_line(n,m) - get_susceptance_line(n,m)*(theta[n,t] - theta[m,t])))
    @constraint(m2_5, (get_capacity_line(n,m) - get_susceptance_line(n,m)*(theta[n,t] - theta[m,t])) <= psi_8[n,m,t]*M[7])
    @constraint(m2_5, eta_up_n_m[n,m,t] <= (1-psi_8[n,m,t])*M[8])
end 

@constraint(m2_5, ramp_strategic[i in 1:4, t in 2:24], p_i[i,t] - p_i[i,t-1] <= ramp_limits[i])
@constraint(m2_5, ramp_non_strategic[j in 1:4, t in 2:24], p_j[j,t] - p_j[j,t-1] <= ramp_limits[j])

optimize!(m2_5)



# MCP_node_hour = value.(reshape([lambda[n,t] for n in 1:6 for t in 1:24], 24, 6))
# CSV.write("outputs/step_2_5_MCP_node_hour.csv", Tables.table(MCP_node_hour))

# value.(d)

# println("")
# println("alpha_offer_i = ", value.(alpha_offer))
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

# plot_MCP = plot(1:24,value.(lambda[1,:]),xlabel="Hour of the day",ylabel="Market clearing price",legend=false)
# savefig(plot_MCP,"step_2_5_MCP.png")


# plot(1:24,value.(alpha_offer[:,:]),xlabel="Hour of the day",ylabel="Strategic offer price",legend=false)

# Matrix(alpha_offer)