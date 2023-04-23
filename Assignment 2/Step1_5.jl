# Step 1.5

using Pkg, Gurobi, JuMP, Cbc, CSV, DataFrames, Random

#Import the parameters from the CSVs, please change the directory
p_real_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_wind.csv", DataFrame, delim=",")
price_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_price.csv", DataFrame, delim=",")
system_raw = CSV.read("C:/Users/mscuc/Downloads/inputs_system.csv", DataFrame, delim=",")

#Re-order the parameters so the scenarios are random
Random.seed!(69)
scenarioOrdered = randperm(600)

#Create the scenarios
p_real = p_real_raw[:, scenarioOrdered]
price_DA = price_raw[:, scenarioOrdered]
system = system_raw[:, scenarioOrdered]
price_Bal_1 = zeros(24,600)

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

p_DA_1 = [150.0, 150.0, 0.0, 0.0, 150.0, 150.0, 0.0, 0.0, 0.0, 0.0, 150.0, 150.0, 0.0, 0.0, 150.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 150.0, 150.0]
p_DA_2 = [123.419; 114.804; 39.6; 0.0; 129.224; 150.0; 49.971; 89.156; 85.833; 0.0; 116.04; 106.538; 97.474; 84.22; 123.923; 47.13; 69.891; 137.155; 41.162; 86.235; 46.686; 0.0; 150.0; 129.868]
p_DA_4 = 

#Fill the revenue based on the scenarios
DA_revenue_1 = zeros(1,600)
DA_revenue_2 = zeros(24, 600)
Bal_revenue_1 = zeros(24, 600)
Bal_revenue_2 = zeros(24, 600)
for w in 1:600
    for t in 1:24
        DA_revenue_1[w] = sum(p_DA_1[t]*price_DA[t,w] for t in 1:24)
        DA_revenue_2[t,w] = p_DA_2[t]*price_DA[t,w]
        # DA_revenue_4[t,w] = p_DA_4[t]*price_DA[t,w]
        Bal_revenue_1[t,w] = price_Bal[t,w]*(p_real[t,w]-p_DA_1[t])
        if system[t,w] == 1
            if p_real[t,w]-p_DA_2[t] >=0
                Bal_revenue_2[t,w] = price_Bal[t,w]*(p_real[t,w]-p_DA_2[t])
            end
            if p_real[t,w]-p_DA_2[t] < 0
                Bal_revenue_2[t,w] = price_DA[t,w]*(p_real[t,w]-p_DA_2[t])
            end
        end
        if system == 0
            if p_real[t,w]-p_DA_2[t] >=0
                Bal_revenue_2[t,w] = price_DA[t,w]*(p_real[t,w]-p_DA_2[t])
            end
            if p_real[t,w]-p_DA_2[t] < 0
                Bal_revenue_2[t,w] = price_Bal[t,w]*(p_real[t,w]-p_DA_2[t])
            end
        end
    end
end

DA_revenue_1_error = (mean(DA_revenue_1[1:200])-mean(DA_revenue_1[201:600]))/mean(DA_revenue_1[1:200])*100

#Put the values of interest in a CSV
data = vcat(fill("p_DA_1", (1, 600)),
            hcat(p_DA_1, zeros(24, 599)),
            fill("p_DA_2", (1, 600)),
            hcat(p_DA_2, zeros(24, 599)),
            fill("p_real", (1, 600)),
            Matrix(p_real),
            fill("DA_revenue_1", (1,600)),
            Matrix(DA_revenue_1),
            fill("DA_revenue_2", (1,600)),
            Matrix(DA_revenue_2),
            fill("Bal_revenue_1", (1,600)),
            Matrix(Bal_revenue_1),
            fill("Bal_revenue_2", (1,600)),
            Matrix(Bal_revenue_2),
            )

CSV.write("step_1_5.csv", Tables.table(data))