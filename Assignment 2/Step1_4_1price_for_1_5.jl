using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random, Statistics


function step_1_4_1p(beta, alpha, in_sample_scen, prob, P_nom, p_real, price_DA, system, price_bal)
    model = Model(Gurobi.Optimizer)

    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:in_sample_scen])
    @variable(model, zeta)
    @variable(model, eta[w in 1:in_sample_scen] >= 0)
    @objective(model, Max, (1-beta) * sum(prob * sum(price_DA[t,w].*p_DA[t] + price_bal[t,w].*delta[t,w] for w in 1:in_sample_scen) for t in 1:24) 
                                + beta * (zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)))
    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:in_sample_scen], delta[t,w] == p_real[t,w] - p_DA[t])
    @constraint(model, cst3[w in 1:in_sample_scen], -sum(price_DA[t,w]*p_DA[t] + price_bal[t,w]*delta[t,w] for t in 1:24) + zeta - eta[w] <= 0)
    
    optimize!(model)

    DA_revenue = zeros(24,600)
    bal_revenue = zeros(24,600)
    for t in 1:24, w in 1:600
        DA_revenue[t,w] = value.(p_DA[t].*price_DA[t,w])
        bal_revenue[t,w] = value.(price_bal[t,w]*(p_real[t,w]-p_DA[t]))
    end 

    return(DA_revenue[:,1:in_sample_scen], DA_revenue[:,in_sample_scen+1:600], bal_revenue[:,1:in_sample_scen], bal_revenue[:,in_sample_scen+1:600])
end

