# Step 1.2

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random, Statistics

pwd()
cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/GitHub/DTU-RIEM/Assignment 2")

#Import the parameters from the CSVs, please change the directory
p_real_raw = CSV.read("inputs/inputs_wind.csv", DataFrame, delim=",")
price_raw = CSV.read("inputs/inputs_price.csv", DataFrame, delim=",")
system_raw = CSV.read("inputs/inputs_system.csv", DataFrame, delim=",")

#Re-order the parameters so the scenarios are random
Random.seed!(69)
scenarioOrdered = randperm(600)

#Create the scenarios
p_real = p_real_raw[:, scenarioOrdered]
price_DA = price_raw[:, scenarioOrdered]
system = system_raw[:, scenarioOrdered]
price_Bal = zeros(24,600)


#Basic stuff for the model
in_sample_scen = 200
out_sample_scen = 400
prob = 1/in_sample_scen
P_nom = 150

beta = 0.001

function run_1_price_risk(alpha)
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

    model = Model(Gurobi.Optimizer)
    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:in_sample_scen])
    @variable(model, zeta)
    @variable(model, eta[w in 1:in_sample_scen] >= 0)
    @objective(model, Max, sum(prob * sum(price_DA[t,w]*p_DA[t] + price_Bal[t,w]*delta[t,w] for w in 1:in_sample_scen) for t in 1:24) 
                                + beta*(zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)))
    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:in_sample_scen], delta[t,w] == p_real[t,w] - p_DA[t])
    @constraint(model, cst3[w in 1:in_sample_scen], -sum(price_DA[t,w]*p_DA[t] + price_Bal[t,w]*delta[t,w] for t in 1:24) + zeta - eta[w] <= 0)
    optimize!(model)
    
    return(value(zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)), objective_value(model)) 
end

to_store = ["alpha" "CVar" "obj_function"]


alpha = 0.0001*collect(0:10)
for count in range(1,10)
    risk, obj = run_1_price_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.001*collect(0:10)
for count in range(1,10)
    risk, obj = run_1_price_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.01*collect(0:10)
for count in range(1,10)
    risk, obj = run_1_price_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.1*collect(0:10)
for count in range(1,10)
    risk, obj = run_1_price_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end


CSV.write("outputs/step_1_4_1price_beta0.001.csv", Tables.table(to_store))

