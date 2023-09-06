using JuMP
using Gurobi

# Data of IEEE 24-bus reliability test system
include("Data_Project.jl")

# SETS
# Time [1:24]
T = length(Time)

# Conventional Generator Set [1:12]
G = length(LGN)

# Wind farm set
W = length(LWFN)

# Demand set
D = length(LDN)

# Charging or Discharging set
CH = 2

#************************************************************************
# Model
Step1 = Model(Gurobi.Optimizer)

# Variables
@variable(Step1,pg[g=1:G,t=1:T]>=0) #Hourly Production per conventional generator
@variable(Step1,pw[w=1:W,t=1:T]>=0) #Hourly Production per Wind farm
@variable(Step1,pd[d=1:D,t=1:T]>=0) #Hourly demand
@variable(Step1,e[t=1:T]>=0) #State of charge of ONE battery system
@variable(Step1,b[t=1:T,ch=1:CH]>=0) # Battery charging or discharging

# Objective (3a)
@objective( Step1, Max,   sum( BP[d]*pd[d,t] for t=1:T,d=1:D) # Revenue from demand 

                        - sum( PC[g]*pg[g,t] for t=1:T,g=1:G) # Production cost conventional generator

                        - sum( 0*pw[w,t]     for w=1:W,t=1:T) # Production cost Wind farm
                    )

# Constraints

# Capacity Constraints 
@constraint(Step1,CapCon[t=1:T,g=1:G], 0 <= pg[g,t] <= CAPG[g] ) # (3b) Capacity for conventional generator
@constraint(Step1,[t=1:T,w=1:W], 0 <= pw[w,t] <= WP[t,w]*CAPW[w] ) # (3c) Capacity for Wind farms

@constraint(Step1,[t=1:T,d=1:D], 0 <= pd[d,t] <= ED[d,t] ) # (3d) Capacity for demand

# Ramping up and down (3e)
@constraint(Step1,Ramp[t=2:T,g=1:G], -RD[g]
                                <= pg[g,t] - pg[g,t-1] <=
                                 RU[g] )

@constraint(Step1,[g=1:G], pg[g,1] == PINI[g] ) # (3f) Initial capacity

# BATTERY Constraints 

# Charging and discharging capacities (3g)
@constraint(Step1, [t=1:T,ch=1:CH], 0 <= b[t,ch] <= PMAX[ch] )

# State of charge constraint (3h)
@constraint(Step1, [t=1:T], EMIN <= e[t] <= EMAX)

# initial state of charge (3i)
@constraint(Step1,  e[1] == 0 )

#(3j)
@constraint(Step1, [t=1:T], (t<T ? e[t+1] : e[t] ) ==
                            e[t] + sum(eta[ch]*b[t,ch] for ch=1:CH) )

# CHP constraints (4k)
@constraint(Step1, [t=1:T], TCH[t] == pg[8,t]/HPR ) # Inelatic Heat demand

# Balance constraint (4l)
@constraint(Step1,Balance[t=1:T], 
                            0 ==
                            sum(pd[d,t] for d=1:D) - #Demand
                            sum(pg[g,t] for g=1:G) - #Generator production
                            sum(pw[w,t] for w=1:W) - #Wind production
                            b[t,2] + # Discharging
                            b[t,1] # Charging
                            )


#************************************************************************
# Solve
solution = optimize!(Step1)
#************************************************************************

# Constructing outputs:
DA_price = zeros(T)
Ramp_out = zeros((T-1,G))
pg_out = zeros((G,T))


#************************************************************************
# Solution
if termination_status(Step1) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(Step1))")

    obj = objective_value(Step1)
    println("Hourly Market clearing price")
    DA_price = dual.(Balance[:])
    for t = 1:T
        println("t$t: ", dual(Balance[t]))
    end

    pg_out = value.(pg[:,:]) 
    Ramp_out = -dual.(Ramp[:,:])

    println("")
    println("Ramping")
    print("   [")
    for g=1:G
        print(" G$g ")
    end
    println(" ]")
    for t = 2:T
        print("t$t [ ")
        for g=1:G
            print(Ramp_out[t,g]," ")
        end
        println(" ]")
    end

    println("")
    println("Cost breakdown")
    Revenue = round(Int,sum( BP[d]*value(pd[d,t]) for d=1:D,t=1:T))
    Cost_p_g = round(Int,sum( PC[g]*value(pg[g,t]) for g=1:G,t=1:T))
    Social_Welfare = Revenue - Cost_p_g

    println("Social Welfare: ",Social_Welfare," Revenue: ",Revenue,
            " Cost: [",Cost_p_g,"] ")
    println("")
    println("")

    # Profit Generators
    Revenue_p_g = round(Int,sum( shadow_price(Balance[t])*value(pg[g,t]) for g=1:G,t=1:T))
    Cost_p_g = round(Int,sum( PC[g]*value(pg[g,t]) for g=1:G,t=1:T))
    Profit_p_g = Revenue_p_g - Cost_p_g

    # Profit Wind farms
    Revenue_p_wf = round(Int,sum( shadow_price(Balance[t])*value(pw[w,t]) for w=1:W,t=1:T))
    Cost_p_wf = round(Int,sum( 0*value(pw[w,t]) for w=1:W,t=1:T))
    Profit_p_wf = Revenue_p_wf - Cost_p_wf

    # Profit CHP
    Revenue_CHP = round(Int,sum( dual(Balance[t])*value(pg[8,t]) for t=1:T)) # Discharging
    Cost_CHP = round(Int,sum( PC[8]*value(pg[8,t]) for t=1:T)) # Charging
    Profit_CHP = Revenue_CHP - Cost_CHP

    # Profit Storge
    Revenue_b = round(Int,sum( dual(Balance[t])*value(b[t,2]) for t=1:T)) # Discharging
    Cost_b = round(Int,sum( dual(Balance[t])*value(b[t,1]) for t=1:T)) # Charging
    Profit_b = Revenue_b - Cost_b

    # Profit Demand
    Revenue_Demand = 0 # Discharging
    Cost_Demand = round(Int,sum( dual(Balance[t])*value(pd[d,t]) for d=1:D,t=1:T)) # Charging
    Profit_Demand = Revenue_Demand - Cost_Demand

    println("")
    println("Total profit for each type of unit:")
    println("Revenue, G: ",Revenue_p_g, " WF: ", Revenue_p_wf, " b: ",Revenue_b," CHP: ",Revenue_CHP," Demand: ",Revenue_Demand)
    println("Cos, G: ",Cost_p_g, " WF: ", Cost_p_wf, " b: ",Cost_b," CHP: ",Cost_CHP," Demand: ",Cost_Demand)
    println("Profit, G: ",Profit_p_g, " WF: ", Profit_p_wf, " b: ",Profit_b," CHP: ",Profit_CHP," Demand: ",Profit_Demand)
    println("")


    println("Production/Consumption break down: ")
    for t = 1:T
        println("t$t [D: ", round(Int, sum(value(pd[d,t]) for d=1:D)),"/" ,round(Int, sum(value(ED[d,t]) for d=1:D)),
            " p_g: ", round(Int, sum(value(pg[g,t]) for g=1:G)) ,
            " p_wf: ", round(Int, sum(value(pw[w,t]) for w=1:W)),
            " b_ch: ", round(Int, value(b[t,1])),
            " b_disch: ", round(Int, value(b[t,2])),
            " SOC:", round(Int, value(e[t])),"] "
            )  
    end
    println("")


    println("Production Conventional Generators")
    println("Time, ( Generator, Production, Profit)")
    for t=1:T

        print(Time[t]," [")
        for g=1:G
            if value(pg[g,t]) != 0
                print(" (",Generator[g],": ", round(Int, value(pg[g,t])),", ",(round(Int, DA_price[t]*value(pg[g,t])-value(pg[g,t])*PC[g])),") ")
        
            end
        end
        println("], Total: ", round(Int, sum(value(pg[g,t]) for g=1:G)))


    end
    println("")
    println("Total Profit for each Generator  (Production, Profit)")
    for g=1:G
        println("G$g: (", round(Int, sum(value(pg[g,t]) for t=1:T)) ,", ", round(Int, sum(DA_price[t]*value(pg[g,t])-value(pg[g,t])*PC[g] for t=1:T)),") " )
    end
    println("")

    println("Optimal objective value: $(objective_value(Step1))")
else
    println("No optimal solution available")
end
#************************************************************************
