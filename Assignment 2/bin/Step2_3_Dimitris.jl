#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
@time begin

#**************************************************
#Get Data
include("ass2_step_2_data.jl")

#**************************************************

# Generator Set
G = 8
# Strategic producer:
S = 4
# Non-Strategic producer:
O = 4
# Demand set
D = 4
# Node set
N = 6
# Sucseptance
B = 50
# Big M 
M = [500, 10, 250, 12, 400, 25, 5000, 20000]

#**************************************************
# MODEL
Step_2_3 = Model(Gurobi.Optimizer)

#**************************************************

#Variables
@variables Step_2_3 begin
    alpha_s_offer[s=1:S] >=0
    ps[s=1:S] >=0
    po[o=1:O] >=0
    pd[d=1:D] >=0
    theta[n=1:N]
    lambda[n=1:N] >=0
    mu_d_cap[d=1:D] >=0
    mu_d_undercap[d=1:D] >=0
    mu_s_cap[s=1:S] >= 0
    mu_s_undercap[s=1:S] >=0
    mu_o_cap[o=1:O] >=0
    mu_o_undercap[o=1:O] >=0 
    rho_cap[n=1:N, m=1:N] >= 0 
    rho_undercap[n=1:N, m=1:N] >= 0 
    gamma
    psi_d_cap[d=1:D], Bin 
    psi_d_undercap[d=1:D], Bin
    psi_s_cap[s=1:S], Bin
    psi_s_undercap[s=1:S], Bin
    psi_o_cap[o=1:O], Bin
    psi_o_undercap[o=1:O], Bin
    psi_n_m_cap[n=1:N, m=1:N], Bin
    psi_n_m_undercap[n=1:N, m=1:N], Bin
end 

#**************************************************
# Objective function

@objective(Step_2_3, Max,
- sum(ps[s] * strat_gen_cost[s] for s=1:S) # Total cost of strategic generator production
+ sum(demand_bid[d] * pd[d] for d=1:D) # Total demand value
- sum(non_strat_gen_cost[o] * po[o] for o=1:O) # Total cost of non-strategic generator production
- sum(mu_d_cap[d] * demand_cons[d] for d=1:D) 
- sum(mu_o_cap[o] * non_strat_gen_cap[o] for o = 1:O)
- sum(rho_undercap[n,m] * transm_capacity_2_3[n,m] for n=1:N, m in connected_nodes(n)[2])
- sum(rho_cap[n,m] * transm_capacity_2_3[n,m] for n=1:N, m in connected_nodes(n)[2])
)

#**************************************************
# Constraints 

@constraint(Step_2_3, [s=1:S], alpha_s_offer[s] >= strat_gen_cost[s])

@constraint(Step_2_3, [d=1:D], - demand_bid[d] + mu_d_cap[d] - mu_d_undercap[d] 
            + lambda[node_demands(d)] == 0)  # Dual of demand capacity constraint

@constraint(Step_2_3, [s=1:S], alpha_s_offer[s] + mu_s_cap[s] - mu_s_undercap[s] 
            - lambda[node_strat_gen(s)] == 0) # Dual of strategic capacity constraint

@constraint(Step_2_3, [o=1:O], non_strat_gen_cost[o] + mu_o_cap[o] - mu_o_undercap[o] 
            - lambda[node_non_strat_gen(o)] == 0) # Dual of non-strategic capacity constraint

@constraint(Step_2_3, [n=1:N],
            sum(B * (lambda[n] - lambda[m]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_cap[n,m] - rho_cap[m,n]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_undercap[n,m] - rho_undercap[m,n]) for m in connected_nodes(n)[2]) 
            + gamma == 0
            )

@constraint(Step_2_3, theta[1] == 0)

@constraint(Step_2_3, [n=1:N],
                sum(pd[d] for d in node_dem[n])
                + sum(B * (theta[n] - theta[m]) for m in connected_nodes(n)[2])
                - sum(B * (theta[m] - theta[n]) for m in connected_nodes(n)[1]) 
                - sum(ps[s] for s in strat_node_gen[n])
                - sum(po[o] for o in non_strat_node_gen[n]) == 0
)

@constraint(Step_2_3, [d=1:D], 0 <= demand_cons[d] - pd[d]) # Demand capacity constraint
@constraint(Step_2_3, [d=1:D], demand_cons[d] - pd[d] <= psi_d_cap[d] * M[1]) 
@constraint(Step_2_3, [d=1:D], mu_d_cap[d] <= (1-psi_d_cap[d]) * M[2]) 
@constraint(Step_2_3, [d=1:D], pd[d] <= psi_d_undercap[d] * M[1])
@constraint(Step_2_3, [d=1:D], mu_d_undercap[d] <= (1-psi_d_undercap[d]) * M[2]) 

@constraint(Step_2_3, [s=1:S], 0 <= strat_gen_cap[s] - ps[s]) # Strategic producer capacity constraint
@constraint(Step_2_3, [s=1:S], strat_gen_cap[s] - ps[s] <= psi_s_cap[s] * M[3]) 
@constraint(Step_2_3, [s=1:S], mu_s_cap[s] <= (1-psi_s_cap[s]) * M[4]) 
@constraint(Step_2_3, [s=1:S], ps[s] <= psi_s_undercap[s] * M[3])
@constraint(Step_2_3, [s=1:S], mu_s_undercap[s] <= (1-psi_s_undercap[s]) * M[4]) 

@constraint(Step_2_3, [o=1:O], 0 <= non_strat_gen_cap[o] - po[o]) # Non-stratgic producer capacity constraint
@constraint(Step_2_3, [o=1:O], non_strat_gen_cap[o] - po[o] <= psi_o_cap[o] * M[5]) 
@constraint(Step_2_3, [o=1:O], mu_o_cap[o] <= (1-psi_o_cap[o]) * M[6]) 
@constraint(Step_2_3, [o=1:O], po[o] <= psi_o_undercap[o] * M[5])
@constraint(Step_2_3, [o=1:O], mu_o_undercap[o] <= (1-psi_o_undercap[o]) * M[6]) 

for n=1:N, m=1:N   
    if transm_capacity_2_3[n,m] != 0
        @constraint(Step_2_3,
        0 <= transm_capacity_2_3[n,m] - B * (theta[n] - theta[m])) # transmission capacity constraint
        @constraint(Step_2_3,
        transm_capacity_2_3[n,m] - B * (theta[n] - theta[m]) <= psi_n_m_cap[n,m] .* M[7])
        @constraint(Step_2_3,
        rho_cap[n,m] <= (1 .- psi_n_m_cap[n,m]) .* M[8])
    end
end


for n=1:N, m=1:N   
    if transm_capacity_2_3[n,m] != 0
        @constraint(Step_2_3,
        0 <= transm_capacity_2_3[n,m] + B * (theta[n] - theta[m]))
        @constraint(Step_2_3,
        transm_capacity_2_3[n,m] + B * (theta[n] - theta[m]) <= psi_n_m_undercap[n,m] .* M[7])
        @constraint(Step_2_3,
        rho_undercap[n,m] <= (1 .- psi_n_m_undercap[n,m]) .* M[8])
    end
end

#************************************************************************
# Solve
solution = optimize!(Step_2_3)
end
#**************************************************

# Print results
if termination_status(Step_2_3) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Objective value: ", objective_value(Step_2_3))

    # Market clearing price
    mc_price = zeros(N)
    mc_price = value.(lambda[:])
    for n= 1:N
        println("Market clearing price for node n$n ", mc_price[n])
    end 
    
    # strategic offer price
    str_offer_price = value.(alpha_s_offer[:])

    # sttategic offer schedule
    str_offer_schedule = value.(ps[:])

    # profit of strategic producers
    str_profit = zeros(S)
    for s = 1:S
        str_profit[s] = str_offer_schedule[s] * (mc_price[node_strat_gen(s)] - strat_gen_cost[s])
    end 
    
    # print
    for s = 1:S
        println("Strategic offer price for generator S$s: ", 
        str_offer_price[s], ", schedule ", str_offer_schedule[s], ", profit ", str_profit[s])
    end 

    # non-strategic offer schedule
    non_str_offer_schedule = value.(po[:])
    for o = 1:O
        println("Non strategic offer schedule for generator O$o: ", non_str_offer_schedule[o])
    end

    # Social welfare
    social_welfare = sum(demand_bid[d] * value.(pd[d]) for d in 1:D)
                    - sum(strat_gen_cost[s] * str_offer_schedule[s] for s in 1:S)
                    - sum(non_strat_gen_cost[o] * non_str_offer_schedule[o] for o in 1:O)
    println("Social welfare: ", social_welfare)

    # print power flow from node n to node m
    for n=1:N
        for m=1:N
            if transm_capacity_2_3[n,m] != 0
                println("Transmission n$n, m$m: ", B*(value.(theta[n]) - value.(theta[m])))
            end
        end
    end

else 
    println("No optimal solution found")
end