# Step 1.1

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random

#Import the parameters from the CSVs, please change the directory
p_Real_raw = CSV.read("inputs/inputs_wind.csv", DataFrame, delim=",")
price_raw = CSV.read("inputs/inputs_price.csv", DataFrame, delim=",")
system_raw = CSV.read("inputs/inputs_system.csv", DataFrame, delim=",")

#Re-order the parameters so the scenarios are random
Random.seed!(69)
scenarioOrdered = randperm(600)

#Create the scenarios
p_Real = p_Real_raw[:, scenarioOrdered]
price_DA = price_raw[:, scenarioOrdered]
system = system_raw[:, scenarioOrdered]
price_Bal = zeros(24,600)

#Fill the balancing price based on the system
for w in 1:600
    for t in 1:24
        if system[t,w] == 1
            price_Bal[t,w] = 0.9*price_DA[t,w]
        end
        if system[t,w] == 0
            price_Bal[t,w] = 1.2*price_DA[t,w]
        end
    end
end

#Basic stuff for the model
inSample = 200
outOfSample = 400
prob = 1/inSample
P_nom = 150

model = Model(Gurobi.Optimizer)

@variable(model, p_DA[t in 1:24] >= 0)
@variable(model, delta[t in 1:24, w in 1:inSample])

@objective(model, Max, sum(prob * sum(price_DA[t,w]*p_DA[t] + price_Bal[t,w]*delta[t,w] for w in 1:inSample) for t in 1:24))

@constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
@constraint(model, cst2[t in 1:24, w in 1:inSample], delta[t,w] == p_Real[t,w] - p_DA[t])

optimize!(model)

#Put the values of interest in a CSV
# value.(reshape(p_DA, 24, 1))
# value.(delta)
# p_Real = Matrix(p_Real)
# system = Matrix(system)
# profit = [sum(price_DA[t,w]*p_DA[t] + price_Bal[t,w]*delta[t,w] for t in 1:24) for w in 1:inSample]'
            
# data = vcat(fill("p_DA", (1, 600)),
#             hcat(value.(reshape(p_DA, 24, 1)), zeros(24, 599)),
#             fill("delta", (1, 600)),
#             hcat(value.(delta), zeros(24, 400)),
#             fill("p_Real", (1, 600)),
#             p_Real,
#             fill("system", (1, 600)),
#             system,
#             fill("profit", (1, 600)),
#             hcat(value.(reshape(profit, 1, 200)), zeros(1, 400)))

# CSV.write("step_1_1.csv", Tables.table(data))

#Our model goes all-or-nothing for the schedule. This binary decision comes from the binary system state of being in excess or deficit. 
#In one price scheme, the wind farm can earn more money just by trying to guess what direction the imbalance will be in the system. 
#This is something we have discussed deeply in the lectures: 
#1. In the case where the system will be in deficit (BP > DAP): The wind farm should not schedule anything because it can sell whatever it produces at a
#   higher price in the balancing market.
#2. In the case where the system will be in excess (BP < DAP): The wind farm should schedule the max capacity because it will receive the max revenue at 
#   the DA market. Then if it produces less than what was scheduled, it can re-purchase the delta at a lower price in the balancing market.
#This behaviour is exactly why the two price scheme got implemented in some balancing markets. 
