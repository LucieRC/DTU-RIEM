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

alpha = [0.85 0.9 0.95]
beta = 0.1*collect(0:10)
# vector = zeros(Float64, length(beta), 2)

function run_2_prices_risk(alpha, beta)
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

to_store = ["alpha" "beta" "CVar" "obj_function"]

for alp in alpha
    for count in range(1,length(beta))
        risk, obj = run_2_prices_risk(alp, beta[count])
        to_store = vcat(to_store, [alp beta[count] risk obj])
    end

    # beta = 0.001*collect(0:10)
    # for count in range(1,10)
    #     risk, obj = run_2_prices_risk(beta[count])
    #     to_store = vcat(to_store, [beta[count] risk obj])
    # end

    # beta = 0.01*collect(0:10)
    # for count in range(1,10)
    #     risk, obj = run_2_prices_risk(beta[count])
    #     to_store = vcat(to_store, [beta[count] risk obj])
    # end

    # beta = 0.1*collect(0:10)
    # for count in range(1,10)
    #     risk, obj = run_2_prices_risk(beta[count])
    #     to_store = vcat(to_store, [beta[count] risk obj])
    # end
end

CSV.write("outputs/step_1_4_2prices_withfactor.csv", Tables.table(to_store))


#Put the values of interest in a CSV
# p_DA = value.(reshape(p_DA, 24, 1))
# bal_price = zeros(AffExpr,24,200)
# for t in 1:24, w in 1:200
#     bal_price[t,w] = compute_bal_part(t,w)
# end
# profit = [sum(price_DA[t,w]*p_DA[t] + compute_bal_part(t,w) for t in 1:24) for w in 1:in_sample_scen]'

# data = vcat(fill("p_DA", (1, 600)),
#             hcat(p_DA, zeros(24, 599)),
#             fill("DA_price", (1,600)),
#             Matrix(price_DA),
#             fill("bal_price",(1,600)),
#             hcat(value.(bal_price), zeros(24, 400)),
#             fill("delta", (1, 600)),
#             hcat(value.(delta), zeros(24, 400)),
#             fill("delta_more", (1, 600)),
#             hcat(value.(delta_more), zeros(24, 400)),
#             fill("delta_less", (1, 600)),
#             hcat(value.(delta_less), zeros(24, 400)),
#             fill("p_real", (1, 600)),
#             Matrix(p_real),
#             fill("system", (1, 600)),
#             Matrix(system),
#             fill("profit", (1, 600)),
#             hcat(value.(reshape(profit, 1, 200)), zeros(1, 400)))

# CSV.write("step_1_2.csv", Tables.table(data))