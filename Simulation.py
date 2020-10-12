import scipy as sc
import numpy as np
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

# To do: find package(s) needed for solver
#   odeint? lmao it uses lsoda like R does
#       doc: http://headmyshoulder.github.io/odeint-v2/doc/index.html 
#       more doc: https://docs.scipy.org/doc/scipy-1.2.1/reference/generated/scipy.integrate.odeint.html
#   solve_ivp (also from scipy.integrate) is allegedly more flexible than odeint, but slower
#       doc: https://docs.scipy.org/doc/scipy-1.2.1/reference/generated/scipy.integrate.solve_ivp.html
#   desolver? mostly for IVPs
#   GEKKO? 

# Parameters: J, alpha, Q_i, N, s, gamma1, gamma2, gamma3, d_i, K, eta1, eta2
"""
J: number of food sources
alpha: per capita rate of spontaneous discoveries
Q_i: quality of food source i
N: total number of ants
s: per capita rate of ant leaving trail per distance
gamma1: range of foraging scouts
gamma2: range of recruitment activity
gamma3: range of influence of pheromone
D_i: dist btwn source i and the nest
K: inertial effects that may affect pheromones
n1: individual ant's contribution to rate of recruitment
n2: pheromone strength of trail
"""
#=================================================================================================#

# PARAMETERS 

trials = 10
J      = 5 
N      = 10000
alpha  = 0.75
s      = 3.5
gamma1 = 0.2
gamma2 = 0.21
gamma3 = 0.21
K      = 1
n1     = 20 
n2     = 20 

Qmin = 0
Qmax = 20
Dmin = 0
Dmax = 55

betaB  = np.zeros(J)
betaS  = np.zeros(J)

# TIME 

start = 0.0
stop  = 1.0
step  = 0.00001
tspan = np.arange(start,stop+step,step)

# INITIAL CONDITIONS

x0 = np.zeros(J)

#=================================================================================================#

# SYSTEM OF EQUATIONS

def dx_dt(x,t):
    system = np.zeros(J)
    for i in range(J):
        system[i] = (alpha* np.exp(-gamma1*D[i]) + (gamma2/D[i])*betaB[i]*x[i])*(N-sum(x)) - (s*D[i]*x[i])/(K+ (gamma3/D[i])*betaS[i]*x[i])
    return system

# TRIALS AND MODEL OUTPUT

final_time   = np.zeros([trials,J])
weight_avg_Q = np.zeros(trials)
weight_avg_D = np.zeros(trials)
for w in range(trials):
    Q = np.random.uniform(Qmin,Qmax,J)  
    D = np.random.uniform(Dmin,Dmax,J)
    for i in range(J):
        betaB[i] = Q[i] * n1
        betaS[i] = Q[i] * n2
    xs = odeint(dx_dt, x0, tspan)
    final_time[w,:] = xs[-1,:]
    weight_avg_Q[w] = sum((final_time[w,:] * Q)/N)
    weight_avg_D[w] = sum((final_time[w,:] * D)/N)

print(weight_avg_Q)
#print(final_time)

#=================================================================================================#

# PROCESSING DATA



#=================================================================================================#

# Plotting

plt.rc('font', family='serif')

# Plotting distribution of consensus scores at the last time step 
plt.figure()
for i in range(J):
    plt.plot(tspan, xs[:,i]) 
plt.title('Number of ants over time',fontsize=15)
plt.xlabel('Time',fontsize=15)
plt.ylabel('Number of ants',fontsize=15)

#plt.show()