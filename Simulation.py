import scipy as sc
import numpy as np
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

#=================================================================================================#

# PARAMETERS 

trials = 10
J      = 5              # number of food sources (aka, number of trails to food sources)
N      = 10000          # total number of ants
alpha  = 0.75           # per capita rate of spontaneous discoveries
s      = 3.5            # per capita rate of ant leaving trail per distance
gamma1 = 0.2            # range of foraging scouts
gamma2 = 0.21           # range of recruitment activity
gamma3 = 0.21           # range of influence of pheromone
K      = 1              # inertial effects that may affect pheromones
n1     = 20             # individual ant's contribution to rate of recruitment (orig. eta1)
n2     = 20             # pheromone strength of trail (originally eta2)

Qmin = 0                # Minimum & Maximum of Quality uniform distribution
Qmax = 20
Dmin = 0                # Minimum & Maximum of Distance uniform distribution
Dmax = 55

betaB  = np.zeros(J)    # how much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)    # relationship btwn pheromone strength of a trail & its quality

# TIME 

start = 0.0
stop  = 5.0
step  = 0.001
tspan = np.arange(start,stop+step,step)

# INITIAL CONDITIONS

x0 = np.zeros(J)        # We start with no ants on any of the trails

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

# TRIALS AND MODEL OUTPUT

final_time   = np.zeros([trials,J])
weight_avg_Q = np.zeros(trials)
weight_avg_D = np.zeros(trials)
for w in range(trials):
    Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distrib
    D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distrib
    for i in range(J):
        betaB[i] = Q[i] * n1                # Each trail has different betas, so they're calculated here
        betaS[i] = Q[i] * n2
    xs = odeint(dx_dt, x0, tspan)           # Solve the system
    final_time[w,:] = xs[-1,:]              # Array of the number of ants on each trail at the last timestep
    #                                         Columns: trail (food source), Rows: trials

    weight_avg_Q[w] = sum((final_time[w,:] * Q)/N)  # Weighted average of quality (selected.Q in R)
    weight_avg_D[w] = sum((final_time[w,:] * D)/N)  # Weighted average of distance (selected.D in R)

#print(weight_avg_Q)
#print(final_time)

#=================================================================================================#

# PROCESSING DATA



#=================================================================================================#

# Plotting

plt.rc('font', family='serif')

# Plotting the number of ants on each trail over time
plt.figure()
for i in range(J):
    plt.plot(tspan, xs[:,i], label = str(i+1)) 
plt.title('Number of ants over time',fontsize=15)
plt.xlabel('Time',fontsize=15)
plt.ylabel('Number of ants',fontsize=15)
plt.legend(title='Trail', bbox_to_anchor=(1.01, 0.5), loc='center left', borderaxespad=0.)
plt.show()
