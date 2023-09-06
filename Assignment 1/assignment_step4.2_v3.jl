


# Results of DA model
DA_MCP_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_MCP_24h.csv", DataFrame, delim=","))
DA_production_suppliers_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_production_suppliers_24h.csv", DataFrame, delim=","))
DA_demands_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_demands_24h.csv", DataFrame, delim=","))
DA_thetas_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_thetas_24h.csv", DataFrame, delim=","))
DA_electro_24h = Matrix(CSV.read("created_data/LUCIE_18.03_Step3_nodal_DA_electro_24h.csv", DataFrame, delim=",")[1:2,1:24])


# Variables specific to Step4.2
generator_failed = zeros(18,1)
generator_failed[12] = 1

up_generators = 