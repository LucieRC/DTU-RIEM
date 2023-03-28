""" INPUTS
"""






LAMBDA = pass #dim 2
PROBA = 1/600
P_nom = 150
P_real = pass #dim2

@variable(model, p_DA[t in 1:24] >= 0)
@variable(model, delta[w in 1:600, t in 1:24])
@variable(model, delta_more[w in 1:600, t in 1:24] >= 0)
@variable(model, delta_less[w in 1:600, t in 1:24] >= 0)


@objective(model, Max, sum(sum(PROBA*(LAMBDA[w,t]*(p_DA[t]+0.9*delta_more[w,t]-1.2*delta_less[w,t]) for w in 1:600) for t in 1:24))

@constraint(model, cst1[t], p_DA[t] <= P_nom)
@constraint(model, cst2[w,t], delta[w,t] == P_real[w,t] - p_DA[t])
@constraint(model, cst3[w,t], delta[w,t] == delta_more[w,t] - delta_less[w,t])