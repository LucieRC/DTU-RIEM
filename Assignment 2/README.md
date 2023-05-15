# Introduction
This repository contains all necessary codes to the 2nd assignment of the 46755 - Renewables in electricty markets course. The goal of this assignment is to investigate both the offering strategy of price taker non-strategic and strategic producer. The files named Step1_.. are solving a bidding strategy problem for a wind farm (150MW of nom. capacity), for both one-price and two-price balancing schemes. Step1_3 and Step1_4 are the sensitivity and risk analysis. Step1_6 comprises in an out-of-sample simulation with cross-validation techniques. The files named Step2_.. are dealing with the offering strategy of a strategic producer (as a price-taker or maker), the impact of network effects, modeling of uncertainty, and the consideration of ramping constraints.

The files do not provide any additional outputs than the model logs. However, if one wants to access a specific output variable, they can decomment the lines of interest at the end of the model file.

# Running indications
The repository is organized such that the user only has go the the Assign2_master script if he is willing to run the different files. If one script was to malfunction, the user is welcomed to select and execute the code in the Julia REPL, which is how the different programs have been runned and debugged. The "outputs" folder is left empty in case the user wants to save the CSV provided in the comments of the files.
1. install the following packages
2. go to the Assign2_master script
3. run line by line according to the model of interest
4. if interested in certain output variable, go to the specific file and un-commment the specific line


