from numpy.lib.shape_base import dstack
from numpy.lib.ufunclike import _dispatcher
import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
from scipy.integrate import solve_ivp
import scipy.stats as stat
import matplotlib.pyplot as plt
import sys
from tqdm import tqdm
from matplotlib.pyplot import get_cmap
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
#Dmax = 0.5
Dmax = 1

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# SOLVER BEHAVIOR

convergence_range = 1 # range for dx_dt max to signal convergence

# TIME 

start = 0.0
stop  = 255.0            # One of our goals is to change this cutoff to reflect convergence
step  = 0.005
tspan = np.arange(start, stop+step, step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

# LIST OF PARAMETERS    (for exporting/reproducing results)

all_params_names  =   ["runs", "J", "N", "alpha", "s", "gamma1", "gamma2", "gamma3", "K", "n1", "n2", "Qmin", "Qmax", "Dmin", "Dmax", "start", "stop", "step", "tspan", "x0"]
all_params_vals   =   [runs, J, N, alpha, s, gamma1, gamma2, gamma3, K, n1, n2, Qmin, Qmax, Dmin, Dmax, start, stop, step, tspan, x0]

#=================================================================================================#

# SYSTEM OF EQUATIONS

# rhs returns dx_dt for our array x.
def rhs(t,x,D,betaB,betaS):
    #x = [y if y > 0 else 0 for y in x]
    x = [1/2*(y+abs(y)) for y in x] # suggestion to constrain x given by Bernoff and Weinburd
    return [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)] # set the floor of the output to 0
    #return (alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x) # set the floor of the output to 0

# Function that checks for convergence
def convergence(t,x,D,betaB,betaS):
    m = 5*np.amax([abs(y) for y in rhs(t,x,D,betaB,betaS)]) # check if one ant total is changing trails
    if m < convergence_range:
        return 0 
    else:
        return m
convergence.terminal = True

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
    data_out = []
    for w in range(runs):
        #print(int(np.floor(w*100/runs)), "%") # Progress bar
        x0 = np.zeros(J)
        Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distribution      
        D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distribution     
        betaB = n1 * Q
        betaS = n2 * Q

        #sol = solve_ivp(rhs,[start,stop],x0,args=(D,betaB,betaS),dense='true',method = 'LSODA')
        sol = solve_ivp(rhs,[start,stop],x0,events=convergence,args=(D,betaB,betaS),method = 'LSODA')
        #data_out.append([sol,[list(Q),list(D)]])
    if list(sol.t_events[-1]):
        return sol,[list(Q),list(D)],list(sol.t_events[-1])[0]
    else:
        return sol,[list(Q),list(D)],255

    #return sol

sol = ivp_simulation() #this is in a special type that gives you extra info if you print it
#print(sol)
# sol.t is timesteps
# sol.y is the solutions: one row for each trail, timesteps are cols
# this is the transpose of odeint's output

testruns = 1000

def find_negatives():
    negative_testruns = np.zeros(testruns)  
    for i in range(testruns):
        isnegative = 0
        #print(int(np.floor(i*100/testruns)), "% 🐜") # Progress bar
        sol = ivp_simulation()
        # sol.y is the solutions: one row for each trail, timesteps are cols
        # reshape array so it's just one list
        flat_soly = list(sol.y.reshape(-1))
        for k in flat_soly:
            if(k<0):
                isnegative = 1
                break
        negative_testruns[i] = isnegative
    percent_negative = sum(negative_testruns) / testruns

    print(" ")
    print("Stop : ", stop)
    print("Step : ", step)
    print("Per¢ : ", int(np.ceil(percent_negative*100)), "%")
    return(percent_negative)

def qd_convergence_comparison(numIter):
    qs = np.zeros([J,testruns])
    ds = np.zeros([J,testruns])
    dframe = np.zeros([testruns,testruns,J])
    timeToConverge = []
    finalVals = []
    print("Generating convergence data...")
    for i in tqdm(range(numIter)):
        sol,qdArray,conTime = ivp_simulation()
        qdArray[0] = stat.zscore(qdArray[0])
        qdArray[1] = stat.zscore(qdArray[1])
        

        end = list(sol.y[:,-1])
        trailChoice = end.index(max(end))


        finalVals.append(end.index(max(end)))
        timeToConverge.append(conTime)
    print("done!")
    return qs,ds,timeToConverge,finalVals


#print(sol)
#print(len(sol.t))
#print(len(sol.y))

#print(find_negatives())
#negPercent,negICs = find_negatives()
# Create a dense solution
#t = np.linspace(0,50,1000)
#t = sol.t
#y = sol.y
#convergence_time = sol.t_events[-1]
#print(convergence_time)
#y = sol.sol(t)

qspace,dspace,Ts,fV = qd_convergence_comparison(testruns)


print(fV)
#print(Ts)
#print(qspace)
# Visualize
#qspace = [x[0] for x in negICs]
#dspace = [x[1] for x in negICs]
ax = plt.subplot()
ax.set(xlabel='Quality (z-score)',ylabel='Distance (z-score)')
ax.set(title="Relative quality/distance of chosen food source vs. convergence time")
# color = [[str(t/255.) for _ in range(J)] for t in Ts] # plot all q and d
color = [str(t/255.) for t in Ts] # plot only max val's q and d
for i in range(testruns):
    #ax.scatter(qspace[:,i],dspace[:,i],c=color[i],cmap='viridis')
    plt.set_cmap('viridis')
    ax.scatter(qspace[fV[i],i],dspace[fV[i],i],c=color[i],s=5)
#plt.colorbar(mappable=color)
'''
ax.set(xlabel='t',ylabel='Number of ants')
ax.set(title="Number of ants over time")
ax.plot(t,y.T)
'''
#ax.legend()
plt.show()