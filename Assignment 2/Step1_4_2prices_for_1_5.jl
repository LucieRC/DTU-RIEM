# Step 1.4 - 2 price

function compute_bal_part(system, price_DA, price_bal, delta_more, delta_less, t, w)
    return system[t,w]*(price_bal[t,w]*delta_more[t,w] - 1*price_DA[t,w]*delta_less[t,w]) + (1-system[t,w])*(1*price_DA[t,w]*delta_more[t,w] - price_bal[t,w]*delta_less[t,w])
end


function step_1_4_2p(beta, alpha, in_sample_scen, prob, P_nom, p_real, price_DA, system, price_bal)
    
    model = Model(Gurobi.Optimizer)

    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:in_sample_scen])
    @variable(model, delta_more[t in 1:24, w in 1:in_sample_scen] >= 0)
    @variable(model, delta_less[t in 1:24, w in 1:in_sample_scen] >= 0)
    @variable(model, zeta)
    @variable(model, eta[w in 1:in_sample_scen] >= 0)

    @objective(model, Max, prob * sum(sum(price_DA[t,w]*p_DA[t] + compute_bal_part(system, price_DA, price_bal, delta_more, delta_less, t, w) for w in 1:in_sample_scen) for t in 1:24) 
                                + beta*(zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)))   
                                
    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:in_sample_scen], delta[t,w] == p_real[t,w] - p_DA[t])
    @constraint(model, cst3[t in 1:24, w in 1:in_sample_scen], delta[t,w] == delta_more[t,w] - delta_less[t,w])
    @constraint(model, cst4[t in 1:24, w in 1:in_sample_scen], delta_more[t,w] <= P_nom)
    @constraint(model, cst5[t in 1:24, w in 1:in_sample_scen], delta_less[t,w] <= P_nom)
    @constraint(model, cst6[w in 1:in_sample_scen], -sum(price_DA[t,w]*p_DA[t] + compute_bal_part(system, price_DA, price_bal, delta_more, delta_less, t, w) for t in 1:24) + zeta - eta[w] <= 0)

    optimize!(model)


    DA_revenue = zeros(24,600)
    bal_revenue = zeros(24,600)
    # for t in 1:24, w in 1:in_sample_scen
    #     DA_revenue[t,w] = value.(p_DA[t].*price_DA[t,w])
    #     bal_revenue[t,w] = value.(compute_bal_part(system, price_DA, price_bal, delta_more, delta_less, t, w))
    # end 
    for t in 1:24, w in 1:600
        DA_revenue[t,w] = value.(p_DA[t].*price_DA[t,w])
        if system[t,w] == 1
            if value.(p_real[t,w]-p_DA[t]) >= 0
                bal_revenue[t,w] = value.(price_bal[t,w].*(p_real[t,w]-p_DA[t]))
            end
            if value.(p_real[t,w]-p_DA[t]) < 0
                bal_revenue[t,w] = value.(price_DA[t,w].*(p_real[t,w]-p_DA[t]))
            end
        end
        if system[t,w] == 0
            if value.(p_real[t,w]-p_DA[t]) >= 0
                bal_revenue[t,w] = value.(price_DA[t,w].*(p_real[t,w]-p_DA[t]))
            end
            if value.(p_real[t,w]-p_DA[t]) < 0
                bal_revenue[t,w] = value.(price_bal[t,w].*(p_real[t,w]-p_DA[t]))
            end
        end
    end

    return (DA_revenue[:,1:in_sample_scen], DA_revenue[:,in_sample_scen+1:600], bal_revenue[:,1:in_sample_scen], bal_revenue[:,in_sample_scen+1:600]) 
end
