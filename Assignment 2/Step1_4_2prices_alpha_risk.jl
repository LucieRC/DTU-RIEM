# Step 1.2

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random, Statistics

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
# vector = zeros(Float64, length(beta), 2)

function run_2_prices_risk(alpha)
    function compute_bal_part(t,w)
        return system[t,w]*(.9*price_DA[t,w]*delta_more[t,w] - 1*price_DA[t,w]*delta_less[t,w]) + (1-system[t,w])*(1*price_DA[t,w]*delta_more[t,w] - 1.2*price_DA[t,w]*delta_less[t,w])
    end

    model = Model(Gurobi.Optimizer)

    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:in_sample_scen])
    @variable(model, delta_more[t in 1:24, w in 1:in_sample_scen] >= 0)
    @variable(model, delta_less[t in 1:24, w in 1:in_sample_scen] >= 0)
    @variable(model, zeta)
    @variable(model, eta[w in 1:in_sample_scen] >= 0)

    @objective(model, Max, prob * sum(sum(price_DA[t,w]*p_DA[t] + compute_bal_part(t,w) for w in 1:in_sample_scen) for t in 1:24) 
                                + beta*(zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)))   
                                
    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:in_sample_scen], delta[t,w] == p_real[t,w] - p_DA[t])
    @constraint(model, cst3[t in 1:24, w in 1:in_sample_scen], delta[t,w] == delta_more[t,w] - delta_less[t,w])
    @constraint(model, cst4[t in 1:24, w in 1:in_sample_scen], delta_more[t,w] <= P_nom)
    @constraint(model, cst5[t in 1:24, w in 1:in_sample_scen], delta_less[t,w] <= P_nom)
    @constraint(model, cst6[w in 1:in_sample_scen], -sum(price_DA[t,w]*p_DA[t] + compute_bal_part(t,w) for t in 1:24) + zeta - eta[w] <= 0)

    optimize!(model)
    return(value(zeta - 1/(1-alpha)*sum(prob*eta[w] for w in 1:in_sample_scen)), objective_value(model)) 
end



# for count in 1:length(beta)
#     risk, obj = run_2_prices_risk(beta[count])
#     vector[count,:] = [risk, obj]
# end

to_store = ["alpha" "CVar" "obj_function"]


alpha = 0.0001*collect(0:10)
for count in range(1,10)
    risk, obj = run_2_prices_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.001*collect(0:10)
for count in range(1,10)
    risk, obj = run_2_prices_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.01*collect(0:10)
for count in range(1,10)
    risk, obj = run_2_prices_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

alpha = 0.1*collect(0:10)
for count in range(1,10)
    risk, obj = run_2_prices_risk(alpha[count])
    to_store = vcat(to_store, [alpha[count] risk obj])
end

CSV.write("outputs/step_1_4_2prices_beta_fixed.csv", Tables.table(to_store))
