function get_connected_nodes(node)
    connected_nodes = transmission_lines[transmission_lines[:,"To"].==node, "From"]
    connected_nodes = vcat(connected_nodes,transmission_lines[transmission_lines[:,"From"].==node, "To"])
    return(connected_nodes)
end



model = Model(Gurobi.Optimizer)

@variable(model, alpha_offer[i in 1:4] >= 0)
@variable(model, d[k in 1:4])
@variable(model, p_i[i in 1:4])
@variable(model, p_minus_i[i in 1:4])

@variable(model, mu_down_k[k in 1:4] >= 0)
@variable(model, mu_up_k[k in 1:4] >= 0)
@variable(model, mu_down_i[i in 1:4] >= 0)
@variable(model, mu_up_i[i in 1:4] >= 0)
@variable(model, mu_down_minus_i[i in 1:4] >= 0)
@variable(model, mu_up_minus_i[i in 1:4] >= 0)
@variable(model, mu_down_nm[n in 1:6, m in 1:6] >= 0)
@variable(model, mu_up_nm[n in 1:6, m in 1:6] >= 0)
@variable(model, lambda)
@variable(model, psi_1[k in 1:4] >= 0)
@variable(model, psi_2[k in 1:4] >= 0)
@variable(model, psi_3[i in 1:4] >= 0)
@variable(model, psi_4[i in 1:4] >= 0)
@variable(model, psi_5[j in 1:4] >= 0)
@variable(model, psi_6[j in 1:4] >= 0)

@objective(model, Max, sum(p_i[i]*(lambda[n]-C[i]) for i in 1:4 for n in 1:6))

@constraint(model, opti_cond1[k in 1:4], -alpha_bid[k] + mu_up_k[k] - mu_down_k[k] + lambda[n] == 0)
@constraint(model, opti_cond2[i in 1:4], C[i] + mu_up_i[i] - mu_down_i[i] + lambda[n] == 0)
@constraint(model, opti_cond3[j in 1:4], C[j] + mu_up_minus_i[j] - mu_down_minus_i[i] - lambda[n] == 0)
# @constraint(model, opti_cond4[n in 1:6], sum( for m in ))
for n in nodes
    m_list = get_connected_nodes(n)
    @constraint(model, sum(get_susceptance_line(n,m)*(theta[n] - theta[m] + mu_) for m in m_list))
end 

@constraint(model, equality_cst1[n in 1:6], sum(d[k] for k in connected_demands(n)) + sum(get_susceptance_line(n,m)*(theta[n] - theta[m]) for m in get_connected_nodes(n)) - sum(p_i[i] for i in connected_strategic[n]) - sum(p_minus_i[j] for j in connected_non_strategic[n]) == 0)
@constraint(model, equality_cst2, theta[1] == 0)


@constraint(model, compl_cst1_1[k in 1:4], 0 <= (P_up_k[k] - d[k]))
@constraint(model, compl_cst1_2[k in 1:4], mu_up_k[k] >= 0)
@constraint(model, compl_cst1_3[k in 1:4], (P_up_k[k] - d[k]) <= psi_1[k]*M)
@constraint(model, compl_cst1_4[k in 1:4], mu_up_k[k] <= (1-psi_1[k]*M))
@constraint(model, compl_cst1_5[k in 1:4], 0 <= psi_1[k] <= 1)

@constraint(model, compl_cst2_1[k in 1:4], 0 <= d[k])
@constraint(model, compl_cst2_2[k in 1:4], mu_down_k[k] >= 0)
@constraint(model, compl_cst2_3[k in 1:4], d[k] <= psi_2[k]*M)
@constraint(model, compl_cst2_4[k in 1:4], mu_down_k[k] <= (1-psi_2[k])*M)
@constraint(model, compl_cst2_5[k in 1:4], 0 <= psi_2[k] <= 1)

@constraint(model, compl_cst3_1[i in 1:4], 0 <= (P_up_i[i] - p_i[i]))
@constraint(model, compl_cst3_2[i in 1:4], mu_up_i[i] >= 0)
@constraint(model, compl_cst3_3[i in 1:4], (P_up_i[i] - p_i[i]) <= psi_3[i]*M)
@constraint(model, compl_cst3_4[i in 1:4], mu_up_i[i] <= (1-psi_3[i]*M))
@constraint(model, compl_cst3_5[i in 1:4], 0 <= psi_3[i])

@constraint(model, compl_cst4_1[i in 1:4], 0 <= p_i[i])
@constraint(model, compl_cst4_2[i in 1:4], mu_down_i[i] >= 0)
@constraint(model, compl_cst4_3[i in 1:4], p_i[i] <= psi_4[i]*M)
@constraint(model, compl_cst4_4[i in 1:4], mu_down_i[i] <= (1-psi_4[i]*M))
@constraint(model, compl_cst4_5[i in 1:4], 0 <= psi_4[i] <= 1)

@constraint(model, compl_cst5_1[j in 1:4], 0 <= (P_up[j]-p_minus_i[j]))
@constraint(model, compl_cst5_2[j in 1:4], mu_up_minus_i[j] >= 0)
@constraint(model, compl_cst5_3[j in 1:4], (P_up[j]-p_minus_i[j]) <= psi_5[j]*M)
@constraint(model, compl_cst5_4[j in 1:4], mu_up_minus_i[j] <= (1-psi_5[j]*M))
@constraint(model, compl_cst5_5[j in 1:4], 0 <= psi_5[j] <= 1)

@constraint(model, compl_cst6_1[j in 1:4], 0 <= p_minus_i[j])
@constraint(model, compl_cst6_2[j in 1:4], mu_down_minus_i[j] >= 0)
@constraint(model, compl_cst6_3[j in 1:4], p_minus_i[j] <= psi_6[j]*M)
@constraint(model, compl_cst6_4[j in 1:4], mu_down_minus_i[j] <= (1-psi_6[j]*M))
@constraint(model, compl_cst6_5[j in 1:4], 0 <= psi_6[j] <= 1)

optimize!(model)