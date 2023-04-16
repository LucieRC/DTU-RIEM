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

# alpha = 0.95
# beta = 0.1*collect(0:10)
# vector = zeros(Float64, length(beta), 2)

function sensitivity_analysis_2prices(coef1, coef2)
    function compute_bal_part(t,w)
        return system[t,w]*(coef1*price_DA[t,w]*delta_more[t,w] - 1*price_DA[t,w]*delta_less[t,w]) + (1-system[t,w])*(1*price_DA[t,w]*delta_more[t,w] - coef2*price_DA[t,w]*delta_less[t,w])
    end

    model = Model(Gurobi.Optimizer)

    @variable(model, p_DA[t in 1:24] >= 0)
    @variable(model, delta[t in 1:24, w in 1:in_sample_scen])
    @variable(model, delta_more[t in 1:24, w in 1:in_sample_scen] >= 0)
    @variable(model, delta_less[t in 1:24, w in 1:in_sample_scen] >= 0)

    @objective(model, Max, sum(prob * sum(price_DA[t,w]*p_DA[t] + compute_bal_part(t,w)    
                                for w in 1:in_sample_scen) for t in 1:24))

    @constraint(model, cst1[t in 1:24], p_DA[t] <= P_nom)
    @constraint(model, cst2[t in 1:24, w in 1:in_sample_scen], delta[t,w] == p_real[t,w] - p_DA[t])
    @constraint(model, cst3[t in 1:24, w in 1:in_sample_scen], delta[t,w] == delta_more[t,w] - delta_less[t,w])
    @constraint(model, cst4[t in 1:24, w in 1:in_sample_scen], delta_more[t,w] <= P_nom)
    @constraint(model, cst5[t in 1:24, w in 1:in_sample_scen], delta_less[t,w] <= P_nom)

    optimize!(model)

    return(objective_value(model)) 
end


# FIRST SENSITIVITY ANALYSIS
coef2 = 1.2
to_store = ["coef1" "coef2" "obj_function"]
print(to_store)
for coef1 in 0.01*range(85,95)
    obj = sensitivity_analysis(coef1,coef2)
    to_store = vcat(to_store, [coef1 coef2 obj])
    print(to_store)
    # vector[count,:] = [risk, obj]
end
CSV.write("outputs/step_1_3_coef1.csv", Tables.table(to_store))

# SECOND SENSITIVITY ANALYSIS
coef1 = 0.9
to_store = ["coef1" "coef2" "obj_function"]
print(to_store)
for coef2 in 0.1*range(11,13,11)
    obj = sensitivity_analysis(coef1,coef2)
    to_store = vcat(to_store, [coef1 coef2 obj])
    print(to_store)
    # vector[count,:] = [risk, obj]
end
CSV.write("outputs/step_1_3_coef2.csv", Tables.table(to_store))