using Pkg, Gurobi, JuMP, DataFrames
Pkg.add("Cbc")
Pkg.add("CSV")
Pkg.add("DataFrames")
using Cbc, CSV, DataFrames

model_step2 = Model(Gurobi.Optimizer)

## Reading data for wind
data_wind = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/inputs/mean_24h_zone1.csv", DataFrame)
# data_wind2 = data_wind[1:43,2]

# Reading the data for demand 
load_profile = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/inputs/load_profile.csv", DataFrame, delim=" ")
load_profile_hours = load_profile[:,"System_demand"]
percent_load_location = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/inputs/demand_load_location_distrib.csv", DataFrame, delim=" ")
#percent_load_nodes = percent_load_location


# Reading the data for the transmission lines
transmission_lines = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/inputs/transmission_lines_both_sides.csv", DataFrame, delim=" ")

# Reading the data for the generation units
generating_units_details = CSV.read("C:/Users/Lucie/Documents/ECOLES/DTU/Renewables in electricity markets/Assignment 1/inputs/generating_units_without_units.csv", DataFrame)


## Sets and parameters
demands_scale = 1:17
demands = collect(demands_scale)
nb_fossil = 12
nb_wind_farms = 6
suppliers = collect(1:nb_fossil + nb_wind_farms)
suppliers_scale = 1:nb_fossil+nb_wind_farms
hours_scale = 1:24
hours = collect(hours_scale)
bid_price = rand(10:50,17)
nodes_scale = 1:24
nodes = collect(1:nodes_scale)
transmission_lines_scale = 1:size(transmission_lines)[1]*2 #(*2) to account for both sides of the ATC
transmissions = collect(transmission_lines_scale)
#the first 34 lines will account for the lines defined in the transmission_lines file 
offer_price_wind = [0 0 0 0 0 0]'
offer_price_gen_units = generating_units_details[:,"Ci"]
offer_price_suppliers = [offer_price_wind ; offer_price_gen_units]
nodes_gen_units = generating_units_details[:,"Node"]
# demand_coeff = 
# max_load_demands = percent_load_location2*load_profile2' #(17)
#power_production_wind_farm = [120.54 115.52 53.34 38.16 40 40] #(6)
max_power_production_wind_farm = [500 500 300 300 200 200]
charge_coeff = round.(data_wind[1:24,"mean_charge"], sigdigits=2) #vector of charge for the whole 24h
# part1 = charge_coeff*max_power_production_wind_farm
# part2 = ones(24,1)*[152 152 350 591 60 155 155 400 400 300 310 350]
# max_power_suppliers = hcat(part1,part2)' #(12)
# Now I have to encode per node
location_wind_farms = [3 5 16 21 7 23]
function create_matrix_max_nodes_hours()
    init_node_hour_max_suppliers_matrix = zeros(Float64, 24, 24)
    # add the wind farms at the nodes
    for idx_wind_farm in length(location_wind_farms)
        wind_location = location_wind_farms[idx_wind_farm]
        init_node_hour_max_suppliers_matrix[wind_location,:] += charge_coeff'*max_power_production_wind_farm[idx_wind_farm]
    end
    # add the generating units at the nodes
    nodes_gen_units = unique(generating_units_details[:,"Node"]) #because we have 15th and 23rd nodes with 2 generating units
    for idx_gen_units in length(nodes_gen_units)
        gen_unit_location = nodes_gen_units[idx_gen_units]
        init_node_hour_max_suppliers_matrix[gen_unit_location,:] += fill(generating_units_details[generating_units_details[:,"Node"].==gen_unit_location;"P_max_i"],24)'
    end
end

function create_matrix_max_t_line()
    init_matrix = zeros(Float64, 24, 24)
    for origin_node in nodes_scale
        destination_node_list = transmission_lines[transmission_lines[:,"From"].==origin_node,"To"]
        for destination_node in destination_node_list
            init_matrix[origin_node,destination_node] = transmission_lines[(transmission_lines[:,"From"].==origin_node) & (transmission_lines[:,"To"].==destination_node), "Capacity"]
        end
    end
end

## Variables
@variable(model_step2, load_demands[nodes_scale, hours_scale] >= 0)
@variable(model_step2, power_suppliers[nodes_scale, hours_scale] >= 0)
@variable(model_step2, transmitted[transmission_lines_scale, transmission_lines_scale, hours_scale] >= 0)

## Objective
@objective(model_step2, Max, sum(sum(bid_price[d]*load_demands[n,h] for n in nodes) - sum(offer_price_suppliers[s]*power_suppliers[n,h] for n in nodes) for h in hours))

# Constraints
# demande_assouvie = load_demands[n,h]
# demande_effective = load_profile_hours[h]*percent_load_location[percent_load_location[:,"Node"].==n,"percent_of_system_load"]
@constraint(model_step2, cst_demands[n in nodes, h in hours], load_demands[n,h] <= load_profile_hours[h]*percent_load_location[percent_load_location[:,"Node"].==n,"percent_of_system_load"])
@constraint(model_step2, cst_generators[n in nodes, h in hours], power_suppliers[n,h] <= max_power_suppliers[s,h])
# max_capacity_t_line_depart_node = sum(transmission_lines[transmission_lines[:,"From"].==t, "Capacity"])
@constraint(model_step2, transmission_capacity[t in transmissions, t in transmissions, h in hour], transmitted[t,h] <= sum(transmission_lines[transmission_lines[:,"From"].==t, "Capacity"]))
# @constraint(model_step2, cst_equilibrium[h in hours], sum(load_demands[d,h] for d in demands) - sum(power_suppliers[s,h] for s in suppliers) == 0)
for node in nodes_scale
    # access the demands, suppliers and transmission lines at this node
    # node_demands = percent_load_location[(percent_load_location.Node.==2),:]
    # node_demands = filter(:Node => n -> n == node, percent_load_location)
    # node_load = subset(percent_load_location, :Node => ByRow(==(node)))#; skipmissing=true)
    # node_hour_demand = percent_load_location[percent_load_location[:,"Node"] .== node, "percent_of_system_load"]
    # node_load = load_profile[load_profile[:,"Node"] .== node, "percent_of_system_load"]
    # node_suppliers
    # node_t_lines
    # node_hour_demand = load_profile[:,"System_demand"]*node_load
    # node_hour_supply = sum(generating_units_details[generating_units_details[:,"Node"] .== node, ])
    node_t_line = 
    c = @constraint(model_step2, sum(load_demands[d,h,node] for d in demands) - sum(power_suppliers[s,h,node] for s in suppliers) == 0)
    set_name(c, "cst_nodes_$(node)[h in hours]")
end

optimize!(model_step2)

# println("Optimal Solutions:")
# println("Bid price = ", bid_price)
# println("p_d = ", value.(load_demands))
# println("p_g = ", value.(power_suppliers))

# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h]) - offer_price_suppliers[s])*value.(power_suppliers)[s,h] for s in suppliers] for h in hours]'
# profit_suppliers = [[(abs.(dual.(cst_equilibrium))[h] - offer_price_suppliers[s])*value(power_suppliers[s,h]) for s in suppliers] for h in hours]
# utility_demand = [(bid_price[i] - abs(dual(cst_equilibrium)))*value.(load_demands)[i] for i in demands]'[8:12]

println("Optimal Solutions:")
# println("Bid price = ", bid_price)
println("Power demands = ", value.(load_demands))
println("Power produced by the suppliers = ", value.(power_suppliers))
println("Sum power demands = ", sum(value.(load_demands)))
println("Sum power produced by the suppliers = ", sum(value.(power_suppliers)))
println("Social welfare: ", objective_value(model_step2))
println("Market-clearing prices: ", abs.(dual.(cst_equilibrium[hours])))
println("Profit suppliers: ", profit_suppliers)
println("Utility demands: ", utility_demand)

CSV.write("demands_24h.csv", Tables.table(value.(load_demands)))
CSV.write("supplies_24h.csv", Tables.table(value.(power_suppliers)))
CSV.write("MCP_24h.csv", Tables.table(abs.(dual.(cst_equilibrium[hours]))))
CSV.write("profit_suppliers.csv", Tables.table(profit_suppliers))



# println("Objective value: ", objective_value(model_step2))

# abs(dual(equilibrium))

# has_dual(demands)

