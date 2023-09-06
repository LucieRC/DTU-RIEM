using Gurobi
using JuMP

model_assign_test = Model(Gurobi.Optimizer)

## Sets and parameters
nb_demands = 1
nb_generators = 3
# bid_price = fill(27, 17)'
bid_price = [40]
offer_prices_generators = [0 20 30] #(12)
max_load_demands = [40] #(17)
max_power_generators = [20 50 100] #(12)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)


## Variables
@variable(model_assign_test, load_demands[1:nb_demands] >= 0)
@variable(model_assign_test, power_generators[1:nb_generators] >= 0)

## Objective
@objective(model_assign_test, Max, sum(bid_price[d]*load_demands[d] for d=1:nb_demands) - sum(offer_prices_generators[g]*power_generators[g] for g=1:nb_generators))

# Constraints
@constraint(model_assign_test, demands[i=1:nb_demands], load_demands[i] <= max_load_demands[i])
@constraint(model_assign_test, generators[i=1:nb_generators], power_generators[i] <= max_power_generators[i])
@constraint(model_assign_test, equilibrium, sum(load_demands[i] for i=1:nb_demands) - sum(power_generators[j] for j=1:nb_generators) == 0)

optimize!(model_assign_test)

println("Optimal Solutions:")
println("Bid price = ", bid_price)
println("p_d = ", value.(load_demands))
println("p_g = ", value.(power_generators))



