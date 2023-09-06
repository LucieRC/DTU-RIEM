using Gurobi, JuMP, CSV, DataFrames

model_assign1 = Model(Gurobi.Optimizer)



## Sets and parameters
nb_demands = 17
nb_generators = 12
nb_wind_farms = 6
nb_hours = 24
# bid_price = fill(27, 17)'
bid_price = rand(10:50,nb_hours,nb_demands)
offer_prices_generators = [13.32 13.32 20.7 20.93 26.11 10.52 10.52 6.02 5.47 0 10.52 10.89] #(12) this is not going to change
max_load_demands = [84 75 139 58 55 106 97 132 135 150 205 150 245 77 258 141 100] #(17) this is not  
max_power_generators = [152 152 350 591 60 155 155 400 400 300 310 350] #(12)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
charge_coeff = round.(data_wind2[1:24], sigdigits=2)

## Variables
@variable(model_assign1, load_demands[1:nb_demands] >= 0)
@variable(model_assign1, power_generators[1:nb_generators] >= 0)

## Objective
@objective(model_assign1, Max, sum(bid_price[d]*load_demands[d] for d=1:nb_demands) - sum(offer_prices_generators[g]*power_generators[g] for g=1:nb_generators))

# Constraints
@constraint(model_assign1, demands[i=1:nb_demands], load_demands[i] <= max_load_demands[i])
@constraint(model_assign1, generators[i=1:nb_generators], power_generators[i] <= max_power_generators[i])
@constraint(model_assign1, equilibrium, sum(load_demands[i] for i=1:nb_demands) - sum(power_generators[j] for j=1:nb_generators) - sum(max_power_production_wind_farm[k]*charge_coeff for k=1:nb_wind_farms) == 0)

optimize!(model_assign1)

println("Optimal Solutions:")
println("Bid price = ", bid_price)
println("p_d = ", value.(load_demands))
println("p_g = ", value.(power_generators))



