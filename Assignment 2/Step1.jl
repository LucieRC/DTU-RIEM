# Step 1

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random

P_real_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_wind.csv", DataFrame, delim=",")
price_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_price.csv", DataFrame, delim=",")
system_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_system.csv", DataFrame, delim=",")

Random.seed!(69)
scenarioOrdered = randperm(600)

p_real = P_real_raw[:, scenarioOrdered]
price_DA = price_raw[:, scenarioOrdered]
system = system_raw[:, scenarioOrdered]


seenScenarios = 200
unseenScenarios = 400
prob = 1/seenScenarios
P_nom = 150

model = Model(Gurobi.Optimizer)

@variable(model, p_DA[t in 1:24] >= 0)
@variable(model, delta[t in 1:24, w in 1:seenScenarios])
@variable(model, delta_more[t in 1:24, w in 1:seenScenarios] >= 0)
@variable(model, delta_less[t in 1:24, w in 1:seenScenarios] >= 0)

@objective(model, Max, sum(prob * sum(price_DA[t,w]*(p_DA[t] + 0.9*delta_more[t,w] - 1.2*delta_less[t,w]) for w in 1:seenScenarios) for t in 1:24))

@constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
@constraint(model, cst2[t in 1:24, w in 1:seenScenarios], delta[t,w] == P_real[t,w] - p_DA[t])
@constraint(model, cst3[t in 1:24, w in 1:seenScenarios], delta[t,w] == delta_more[t,w] - delta_less[t,w])
@constraint(model, cst4[t in 1:24, w in 1:seenScenarios], delta_more[t,w] <= delta[t,w])

optimize!(model)

# value.(p_DA)
# value.(delta)
# value.(delta_more)
# value.(delta_less)
