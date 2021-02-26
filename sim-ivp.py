import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
from scipy.integrate import solve_ivp
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

#=================================================================================================#

# PARAMETERS 

runs   = 1             # How many times we run the simulation
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
stop  = 50.0            # One of our goals is to change this cutoff to reflect convergence
step  = 0.005
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
    print(betaB)
    print(betaS)
    print(x)
    # the bit sum(x) is what's making solve ivp angry. he wants an array but
    # somehow x is being passed in as float.
    system = [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB[i]*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS[i]*x) for i in range(J)]
    return system

def rhs(t,x,D,betaB,betaS):
    dx = (alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)
    return [d if d > 0 else 0 for d in dx] # set the floor of the output to 0


def jacobian(x,t,Q,D,betaB,betaS):
    jac_matrix = np.zeros([J,J]) 
    for i in range(J):
        for j in range(J):
            if i == j:
                jac_matrix[i,i] = ((gamma2/D[i])*betaB[i]*x[i]*(N-sum(x))) - (alpha* np.exp(-gamma1*D[i])) - ((gamma2/D[i])*betaB[i]*x[i]) -  (gamma3/D[i])*betaS[i]*((s*D[i])/(K+((gamma3/D[i])*betaS[i]*x[i]) )**2 ) + ((s*D[i])/  (K+ (gamma3/D[i])*betaS[i]*x[i])  )                         
            else:
                jac_matrix[i,j] = - ( (alpha* np.exp(-gamma1*D[i])) + ((gamma2/D[i])*betaB[i]*x[i]) )
    return jac_matrix

# RUNS AND MODEL OUTPUT

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

        sol = solve_ivp(rhs,[start,stop],x0,args=(D,betaB,betaS),dense='true', method = 'LSODA')
    return(sol,[list(Q),list(D)])

sol,initials = ivp_simulation() #this is in a special type that gives you extra info if you print it
# sol.t is timesteps
# sol.y is the solutions: one row for each trail, timesteps are cols
# this is the transpose of odeint's output

testruns = 100

def find_negatives():
    negative_testruns = np.zeros(testruns)  
    negative_ics = []
    for i in range(testruns):
        isnegative = 0
        #print(int(np.floor(i*100/testruns)), "% 🐜") # Progress bar
        sol,ic_list = ivp_simulation()
        # sol.y is the solutions: one row for each trail, timesteps are cols
        # reshape array so it's just one list
        flat_soly = list(sol.y.reshape(-1))
        for k in flat_soly:
            if(k<0):
                isnegative = 1
                negative_ics.append(ic_list)
                break
        negative_testruns[i] = isnegative
    percent_negative = sum(negative_testruns) / testruns

    print(" ")
    print("Stop : ", stop)
    print("Step : ", step)
    print("Per¢ : ", int(np.ceil(percent_negative*100)), "%")
    return(percent_negative,negative_ics)

#print(len(sol.t))
#print(len(sol.y))

#print(find_negatives())
negPercent,negICs = find_negatives()
# Create a dense solution
#t = np.linspace(0,50,1000)
#y = sol.sol(t)

# Visualize
qspace = [x[0] for x in negICs]
dspace = [x[1] for x in negICs]
ax = plt.subplot()
ax.set(xlabel='Q',ylabel='D')
#ax.plot(t,y.T)
ax.scatter(qspace,dspace)
plt.show()
