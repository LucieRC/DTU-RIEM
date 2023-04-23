# Step 1.1

function step_1_1(inSample, prob, P_nom, p_real, price_DA, system, price_bal)
    model = Model(Gurobi.Optimizer)

    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:inSample])

    @objective(model, Max, sum(prob * sum(price_DA[t,w].*p_DA[t] + price_bal[t,w].*delta[t,w] for w in 1:inSample) for t in 1:24))

    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:inSample], delta[t,w] == p_real[t,w] - p_DA[t])

    optimize!(model)

    DA_revenue = zeros(24,600)
    bal_revenue = zeros(24,600)
    for t in 1:24, w in 1:600
        DA_revenue[t,w] = value.(p_DA[t].*price_DA[t,w])
        bal_revenue[t,w] = value.(price_bal[t,w]*(p_real[t,w]-p_DA[t]))
    end 

    return (DA_revenue[:,1:inSample], DA_revenue[:,inSample+1:600], bal_revenue[:,1:inSample], bal_revenue[:,inSample+1:600])
end