using Gurobi, JuMP, Pkg, Cbc

step1 = Model(Gurobi.Optimizer)

## Variables
@variable(step1, load_demands[1:nb_demands] >= 0)
@variable(step1, power_generators[1:nb_generators] >= 0)

## Objective
@objective(step1, Max, sum(bid_price[d]*load_demands[d] for d=1:nb_demands) - sum(offer_prices_generators[g]*power_generators[g] for g=1:nb_generators))

# Constraints
@constraint(step1, demands[i=1:nb_demands], load_demands[i] <= max_load_demands[i])
@constraint(step1, generators[i=1:nb_generators], power_generators[i] <= max_power_generators[i])
@constraint(step1, equilibrium, sum(load_demands[i] for i=1:nb_demands) - sum(power_generators[j] for j=1:nb_generators) == 0)

optimize!(step1)

profit_suppliers = [(abs(dual(equilibrium)) - offer_prices_generators[i])*value.(power_generators)[i] for i=1:nb_generators]'
utility_demand = [(bid_price[i] - abs(dual(equilibrium)))*value.(load_demands)[i] for i=1:nb_demands]'


println("Optimal Solutions:")
println("Bid price = ", bid_price)
println("Power demands = ", value.(load_demands))
println("Power produced by the suppliers = ", value.(power_generators))
println("Sum power demands = ", sum(value.(load_demands)))
println("Sum power produced by the suppliers = ", sum(value.(power_generators)))
println("Social welfare: ", objective_value(step1))
println("Market-clearing price: ", abs(dual(equilibrium)))
println("Profit suppliers: ", profit_suppliers)
println("Utility demands: ", utility_demand)
