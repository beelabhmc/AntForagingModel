import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
from scipy.integrate import solve_ivp
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

from datetime import datetime
start_time = datetime.now()


#=================================================================================================#

# PARAMETERS 

runs   = 1               # How many times we run the simulation
J      = 5               # Number of food sources (aka, number of trails to food sources)
N      = 5000            # Total number of ants
alpha  = 9.170414e+01    # Per capita rate of spontaneous discoveries
s      = 8.124702e+01    # Per capita rate of ant leaving trail per distance
gamma1 = 1.186721e+01    # Range of foraging scouts
gamma2 = 5.814424e-06    # Range of recruitment activity 
gamma3 = 1.918047e-03    # Range of influence of pheromone 
K      = 8.126483e-03    # Inertial effects that may affect pheromones 
n1     = 1.202239e+00    # Individual ant's contribution to rate of recruitment (orig. eta1)
n2     = 9.902102e-01    # Pheromone strength of trail (originally eta2)

Qmin = 0                 # Minimum & Maximum of Quality uniform distribution
Qmax = 20
Dmin = 0                 # Minimum & Maximum of Distance uniform distribution
Dmax = 0.5

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# TIME 

start = 0.0
stop  = 25.0            # One of our goals is to change this cutoff to reflect convergence
step  = 0.01
tspan = np.arange(start, stop+step, step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

# LIST OF PARAMETERS    (for exporting/reproducing results)

all_params_names  =   ["runs", "J", "N", "alpha", "s", "gamma1", "gamma2", "gamma3", "K", "n1", "n2", "Qmin", "Qmax", "Dmin", "Dmax", "start", "stop", "step", "tspan", "x0"]
all_params_vals   =   [runs, J, N, alpha, s, gamma1, gamma2, gamma3, K, n1, n2, Qmin, Qmax, Dmin, Dmax, start, stop, step, tspan, x0]

#=================================================================================================#

# SYSTEM OF EQUATIONS

def dx_dt(x,t,Q,D,betaB,betaS):
    # TODO: REWRITE DXDT AS A SYSTEM THAT MAKES SOLVEIVP HAPPY
    """
    Creates a list of J equations describing the number of ants
    on each of the J trails. (Eqn i corresponds to food source i)
    """
    #system = np.zeros(J)
    # the bit sum(x) is what's making solve ivp angry. he wants an array but
    # somehow x is being passed in as float.
    system = [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB[i]*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS[i]*x) for i in range(J)]
    return system

def rhs(t,x,D,betaB,betaS):
    #print(x)
    #return [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB[i]*x[i])*(N-sum(x)) - (s*D*x[i])/(K+ (gamma3/D)*betaS[i]*x[i]) for i in range(J)]
    return [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)]

# RUNS AND MODEL OUTPUT

#Initialize
density      = np.zeros([runs,J])
final_time   = np.zeros([runs,J])
weight_avg_Q = np.zeros(runs)                   # Sum of (# of ants on a trail * its quality) over all trails
weight_avg_D = np.zeros(runs)                   # Sum of (# of ants on a trail * its distance) over all trails
avg_Q = np.zeros(runs)  
avg_D = np.zeros(runs) 
dif_btwn_avgs_Q = np.zeros(runs)  
dif_btwn_avgs_D = np.zeros(runs)  
prop_committed_ants    = np.zeros(len(tspan))   # Proportion of committed ants (committed =  on a trail)
prop_noncommitted_ants = np.zeros(len(tspan))   # Proportion of non-committed ants 

def ivp_simulation():
    # This version is a test that uses SciPy solve_ivp instead of odeint
    # with the eventual goal of using solve_ivp's event detector to stop
    # the simulation on convergence. 

    for w in range(runs):
        print(int(np.floor(w*100/runs)), "% 🐜") # Progress bar
        x0 = np.zeros(J)
        Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distribution      
        D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distribution     
        betaB = n1 * Q
        betaS = n2 * Q

        sol = solve_ivp(rhs,[0,stop],x0,args=(D,betaB,betaS),dense_output=False, method = 'LSODA')
    return(sol)

sol = ivp_simulation() #this is in a special type that gives you extra info if you print it
# sol.t is timesteps
# sol.y is the solutions: one row for each trail, timesteps are cols
# this is the transpose of odeint's output

print(len(sol.t))
print ("compare to tspan: ", len(tspan))

sol_time_df = pd.DataFrame(data=sol.y)
sol_time_df = sol_time_df.transpose()       # transpose to make 1 column per trail
sol_time_df['t'] = sol.t                    # Include timesteps as col with index j (as counting starts at 0)

df = sol_time_df
df.to_csv(r'/Users/nfn/Desktop/Ants/sivp-test.csv', index = False) # Fletcher's path

print("Complete! 🧁🐜 🍭🐜 🍩🐜")

end_time = datetime.now()
print('Duration: {}'.format(end_time - start_time))
print("for ", runs, " runs on ", J, " trails.")

# Create a dense solution
# t = tspan #np.linspace(0,50,1000)
# y = sol.t
#y = sol.sol(t)

# Visualize
# ax = plt.subplot()
# ax.set(xlabel='t')
# ax.plot(t,y.T)

# soldf = pd.DataFrame(data=sol)
sol_time_df.plot(x='t')
plt.show()

