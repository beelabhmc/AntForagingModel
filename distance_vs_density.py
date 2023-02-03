import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
import os

# PARAMETERS

runs   = 10000           # How many times we run the simulation
J      = 5               # Number of food sources (aka, number of trails to food sources)
N      = 10000           # Total number of ants
alpha  = 0.75            # Per capita rate of spontaneous discoveries
s      = 3.5             # Per capita rate of ant leaving trail per distance
gamma1 = 0.2             # Range of foraging scouts
gamma2 = 0.021           # Range of recruitment activity
gamma3 = 0.021           # Range of influence of pheromone
K      = 1               # Inertial effects that may affect pheromones
n1     = 20              # Individual ant's contribution to rate of recruitment (orig. eta1)
n2     = 20              # Pheromone strength of trail (originally eta2)

Qmin = 0
Qmax = 20
Dmin = 0
Dmax = 60

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# TIME

start = 0.0
stop  = 50.0            
step  = 0.005
tspan = np.arange(start, stop+step, step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

# LIST OF PARAMETERS    (for exporting/reproducing results)

all_params_names  =   ["runs", "J", "N", "alpha", "s", "gamma1", "gamma2", "gamma3", "K", "n1", "n2", "Qmin", "Qmax", "Dmin", "Dmax", "start", "stop", "step", "tspan", "x0"]
all_params_vals   =   [runs, J, N, alpha, s, gamma1, gamma2, gamma3, K, n1, n2, Qmin, Qmax, Dmin, Dmax, start, stop, step, tspan, x0]

# SYSTEM OF EQUATIONS

def dx_dt(x,t,Q,D,betaB,betaS):
        """
        Creates a list of J equations describing the number of ants
        on each of the J trails. (Eqn i corresponds to food source i)
        """
        system = np.zeros(J)
        system = (alpha* np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)
        return system


# RUNS AND MODEL OUTPUT

final_time = np.zeros([runs, J])
weight_avg_D = np.zeros(runs) # Sum of (# of ants on a trail * its distance)/(total number of trails)

def simulation():
    for w in range(runs):
        print(f"Run {w} of {runs} is running.\r", end="")
        Q = np.random.uniform(Qmin, Qmax, J)         #Choose each trail's quality from uniform dist
        D = np.random.uniform(Dmin, Dmax, J)         #Choose each trail's distance from uniform dist

        betaB = n1 * Q
        betaS = n2 * Q

        xs = odeint(dx_dt, x0, tspan, args=(Q,D,betaB,betaS)) #Solves the system. Columns: trail, Rows: time step
        final_time[w,:] = xs[-1,:]
        weight_avg_D[w] = sum((final_time[w,:] * D)/N)

simulation()
weight_avg_data = pd.DataFrame(weight_avg_D)
weight_avg_data.columns = ['waD']
weight_avg_data.to_csv(f'{os.path.dirname(__file__)}/results/weight_avg_test.csv',index=False)
