# Define Parameters for cost and capacity of conventional generators and wind farms
# Production capacity for conventional generators in MW
gen_cap = [155, 100, 155, 197, 337.5, 350, 210, 80]
# Production cost for one hour for conventional generators in $/MWh (constant)
gen_cost = [15.2, 23.4, 15.2, 19.1, 0, 5, 20.1, 24.7]

# Strategic and Non-Strategic generators
strat_gen_cap = gen_cap[1:4]
strat_gen_cost = gen_cost[1:4]
non_strat_gen_cap = gen_cap[5:8]
non_strat_gen_cost = gen_cost[5:8]

#**************************************************
# Define demand variables
# Demand consumption matrix for each hour and for each generator
demand_cons = [200, 400, 300, 250]

# Cost of bids matrix for each hour and for each generator
demand_bid = [26.5, 24.7, 23.1, 22.5]

#**************************************************

# Define node and transmission data in the 24-bus system
node_dem = [[], [], [1], [2], [3], [4]]

node_gen = [[1, 5], [2, 6], [3, 7], [], [8], [4]]
strat_node_gen = [[1], [2], [3], [], [], [4]]
non_strat_node_gen = [[1], [2], [3], [], [4], []]


# Capacity of transmission lines between each node in MW
transm_capacity =  [[0     2000  2000   0     0     0   ];
                    [2000  0     2000   2000  0     0   ];
                    [2000  2000  0      0     0     2000];
                    [0     2000  0      0     2000  2000];
                    [0     0     0      2000  0     2000];
                    [0     0     2000   2000  2000     0];
]

# 2.3 Capacity of "congested" transmission lines between each node in MW
transm_capacity_2_3 =  [[0     2000     2000    0       0     0     ];
                        [2000  0        2000    254.25  0     0     ];
                        [2000  2000     0       0       0     220.75];
                        [0     254.25   0       0       2000  2000  ];
                        [0     0        0       2000    0     2000  ];
                        [0     0        220.75  2000    2000  0     ];
]

# make a list of all connections in transm_capacity
transm_connections = []
for n=1:6
    for m=1:6
        if transm_capacity[n,m] > 0
            push!(transm_connections, [n,m])
        end
    end
end

# 2.3: make a list of all "congested" connections in transm_capacity
transm_connections_2_3 = []
for n=1:6
    for m=1:6
        if transm_capacity_2_3[n,m] > 0
            push!(transm_connections_2_3, [n,m])
        end
    end
end

#*********************************
# Create input functions:

# Create a function that returns the connected nodes in an ingoing and outgoing direction
connections = length(transm_connections)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections[i][1]
            push!(outgoing, transm_connections[i][2])
        elseif node == transm_connections[i][2]
            push!(ingoing, transm_connections[i][1])
        end
    end
    return(outgoing, ingoing)
end

# 2.3: Create a function that returns the congested connected nodes in an ingoing and outgoing direction
connections = length(transm_connections_2_3)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections_2_3[i][1]
            push!(outgoing, transm_connections_2_3[i][2])
        elseif node == transm_connections_2_3[i][2]
            push!(ingoing, transm_connections_2_3[i][1])
        end
    end
    return(outgoing, ingoing)
end

# make functions receiving a demand, strategic or non-strategic generator as input
# and returning it's node location as output.

function node_demands(demand)
    loc_demands = 0
    for i=1:length(node_dem)
        if node_dem[i] == []
            continue
        end
        if node_dem[i][1] == demand
            loc_demands = i
        end
    end
    return(loc_demands)
end

function node_strat_gen(strat)
    loc_strat = 0
    for i=1:length(strat_node_gen)
        if strat_node_gen[i] == []
            continue
        end
        if strat_node_gen[i][1] == strat
            loc_strat = i
        end
    end
    return(loc_strat)
end

function node_non_strat_gen(nonstrat)
    loc_non_strat = 0
    for i=1:length(non_strat_node_gen)
        if non_strat_node_gen[i] == []
            continue
        end
        if non_strat_node_gen[i][1] == nonstrat
            loc_non_strat = i
        end
    end 
    return(loc_non_strat)
end