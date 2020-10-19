import scipy as sc
import numpy as np
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

#=================================================================================================#

# PARAMETERS 

runs   = 1               # How many times we run the simulation
J      = 5               # Number of food sources (aka, number of trails to food sources)
N      = 10000           # Total number of ants
alpha  = 91.7            # Per capita rate of spontaneous discoveries
s      = 81.2            # Per capita rate of ant leaving trail per distance
gamma1 = 11.9            # Range of foraging scouts
gamma2 = 5.81*(10**(-6)) # Range of recruitment activity
gamma3 = 1.91*(10**(-3)) # Range of influence of pheromone
K      = 8.11*(10**(-3)) # Inertial effects that may affect pheromones
n1     = 1.2             # Individual ant's contribution to rate of recruitment (orig. eta1)
n2     = 0.99            # Pheromone strength of trail (originally eta2)

Qmin = 0                 # Minimum & Maximum of Quality uniform distribution
Qmax = 20
Dmin = 0                 # Minimum & Maximum of Distance uniform distribution
Dmax = 1

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# TIME 

start = 0.0
stop  = 1500.0
step  = 5.0
tspan = np.arange(start,stop+step,step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

#=================================================================================================#

# SYSTEM OF EQUATIONS

def dx_dt(x,t):
    """
    Creates a list of J equations describing the number of ants
    on each of the J trails. (Eqn i corresponds to food source i)
    """
    system = np.zeros(J)
    for i in range(J):
        system[i] = (alpha* np.exp(-gamma1*D[i]) + (gamma2/D[i])*betaB[i]*x[i])*(N-sum(x)) - (s*D[i]*x[i])/(K+ (gamma3/D[i])*betaS[i]*x[i])
    return system

# RUNS AND MODEL OUTPUT

density      = np.zeros([runs,J])
final_time   = np.zeros([runs,J])
weight_avg_Q = np.zeros(runs)
weight_avg_D = np.zeros(runs)
prop_committed_ants    = np.zeros(len(tspan))   # Proportion of committed ants 
prop_noncommitted_ants = np.zeros(len(tspan))   # Proportion of non committed ants 
for w in range(runs):
    Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distrib   [10]   
    D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distrib  [0.55] 
    print('Q: ',Q)
    print('D: ',D)
    for i in range(J):
        betaB[i] = Q[i] * n1                # Each trail has different betas, so they're calculated here
        betaS[i] = Q[i] * n2
    xs = odeint(dx_dt, x0, tspan)           # Solve the system, Columns: trail (food source), Rows: time step
    final_time[w,:] = xs[-1,:]              # 2D array of the number of ants on each trail at the last timestep. Columns: trail (food source), Rows: runs.
    
    for i in range(J):
        density[w,i] = xs[-1,i]/D[i]                         
    weight_avg_Q[w]  = sum((final_time[w,:] * Q)/N)  # Weighted average of quality (selected.Q in R)
    weight_avg_D[w]  = sum((final_time[w,:] * D)/N)  # Weighted average of distance (selected.D in R)
    
    for t in range(len(tspan)):
        prop_committed_ants[t]    = sum(xs[t,:]/N)
        prop_noncommitted_ants[t] = 1 - prop_committed_ants[t]
    


#=================================================================================================#

# PROCESSING DATA



#=================================================================================================#

# Plotting

plt.rc('font', family='serif')

# The number of ants on each trail over time
plt.figure()
for i in range(J):
    plt.plot(tspan, xs[:,i], label = str(i+1)) 
plt.title('Number of ants over time',fontsize=15)
plt.xlabel('Time',fontsize=15)
plt.ylabel('Number of ants',fontsize=15)
plt.legend(title='Trail', bbox_to_anchor=(1.01, 0.5), loc='center left', borderaxespad=0.)

# The proportion of ants committed to a trail
plt.figure()
plt.plot(tspan, prop_committed_ants) 
plt.title('Proportion of committed ants',fontsize=15)
plt.xlabel('Time',fontsize=15)
plt.ylabel('Proportion',fontsize=15)

plt.show()
