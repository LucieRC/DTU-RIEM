# Step 1.5

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random
cd("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/GitHub/DTU-RIEM/Assignment 2")
include("Step1_1_for_1_5.jl")
include("Step1_2_for_1_5.jl")
include("Step1_4_1price_for_1_5.jl")
include("Step1_4_2prices_for_1_5.jl")

# Inputs
p_real_raw = CSV.read("inputs/inputs_wind.csv", DataFrame, delim=",")
price_raw = CSV.read("inputs/inputs_price.csv", DataFrame, delim=",")
system_raw = CSV.read("inputs/inputs_system.csv", DataFrame, delim=",")

# Parameters
inSample = 200
prob = 1/inSample
P_nom = 150
alpha = 0.9
beta = 0.001

# Compute the errors
function compute_errors(in,out)
    return (mean(in)-mean(out))/mean(in)*100
end

#Fill the revenue based on the scenarios
DA_bal_revenues_step1 = DataFrame(in_DA = Float64[], in_bal = Float64[], out_DA = Float64[], out_bal = Float64[], DA_error = Float64[], bal_error = Float64[])
DA_bal_revenues_step2 = DataFrame(in_DA = Float64[], in_bal = Float64[], out_DA = Float64[], out_bal = Float64[], DA_error = Float64[], bal_error = Float64[])
DA_bal_revenues_step4_1p = DataFrame(in_DA = Float64[], in_bal = Float64[], out_DA = Float64[], out_bal = Float64[], DA_error = Float64[], bal_error = Float64[])
DA_bal_revenues_step4_2p = DataFrame(in_DA = Float64[], in_bal = Float64[], out_DA = Float64[], out_bal = Float64[], DA_error = Float64[], bal_error = Float64[])


for i in 1:10
    # Re-ordering of the parameters (so that the scenarios are random)
    Random.seed!(i)
    scenarioOrdered = randperm(600)

    # Creation of the scenarios
    p_real = p_real_raw[:, scenarioOrdered]
    price_DA = price_raw[:, scenarioOrdered]
    system = system_raw[:, scenarioOrdered]
    price_bal = zeros(24,600)

    #Fill the balancing price based on the system
    for w in 1:600, t in 1:24
        if system[t,w] == 1
            price_bal[t,w] = 0.9*price_DA[t,w]
        end
        if system[t,w] == 0
            price_bal[t,w] = 1.2*price_DA[t,w]
        end
    end

    # Run the models and extract the balancing prices
    in_DA_rev_step1, out_DA_rev_step1, in_bal_rev_step1, out_bal_rev_step1 = step_1_1(inSample, prob, P_nom, p_real, price_DA, system, price_bal)
    in_DA_rev_step2, out_DA_rev_step2, in_bal_rev_step2, out_bal_rev_step2 = step_1_2(inSample, prob, P_nom, p_real, price_DA, system, price_bal)
    in_DA_rev_step4_1p, out_DA_rev_step4_1p, in_bal_rev_step4_1p, out_bal_rev_step4_1p = step_1_4_1p(beta, alpha, inSample, prob, P_nom, p_real, price_DA, system, price_bal)
    in_DA_rev_step4_2p, out_DA_rev_step4_2p, in_bal_rev_step4_2p, out_bal_rev_step4_2p = step_1_4_2p(beta, alpha, inSample, prob, P_nom, p_real, price_DA, system, price_bal)

    DA_error_step1 = compute_errors(in_DA_rev_step1, out_DA_rev_step1)
    bal_error_step1 = compute_errors(in_bal_rev_step1, out_bal_rev_step1)
    DA_error_step2 = compute_errors(in_DA_rev_step2, out_DA_rev_step2)
    bal_error_step2 = compute_errors(in_bal_rev_step2, out_bal_rev_step2)
    DA_error_step4_1p = compute_errors(in_DA_rev_step4_1p, out_DA_rev_step4_1p)
    bal_error_step4_1p = compute_errors(in_bal_rev_step4_1p, out_bal_rev_step4_1p)
    DA_error_step4_2p = compute_errors(in_DA_rev_step4_2p, out_DA_rev_step4_2p)
    bal_error_step4_2p = compute_errors(in_bal_rev_step4_2p, out_bal_rev_step4_2p)

    push!(DA_bal_revenues_step1, [mean(in_DA_rev_step1) mean(in_bal_rev_step1) mean(out_DA_rev_step1) mean(out_bal_rev_step1) DA_error_step1 bal_error_step1])
    push!(DA_bal_revenues_step2, [mean(in_DA_rev_step2) mean(in_bal_rev_step2) mean(out_DA_rev_step2) mean(out_bal_rev_step2) DA_error_step2 bal_error_step2])
    push!(DA_bal_revenues_step4_1p, [mean(in_DA_rev_step4_1p) mean(in_bal_rev_step4_1p) mean(out_DA_rev_step4_1p) mean(out_bal_rev_step4_1p) DA_error_step4_1p bal_error_step4_1p])
    push!(DA_bal_revenues_step4_2p, [mean(in_DA_rev_step4_2p) mean(in_bal_rev_step4_2p) mean(out_DA_rev_step4_2p) mean(out_bal_rev_step4_2p) DA_error_step4_2p bal_error_step4_2p])
end

CSV.write("outputs/step_1_6_step1_avg_profits_200in_10repets.csv", DA_bal_revenues_step1)
CSV.write("outputs/step_1_6_step2_avg_profits_200in_10repets.csv", DA_bal_revenues_step2)
CSV.write("outputs/step_1_6_step4_1p_avg_profits_200in_10repets.csv", DA_bal_revenues_step4_1p)
CSV.write("outputs/step_1_6_step4_2p_avg_profits_200in_10repets.csv", DA_bal_revenues_step4_2p)
