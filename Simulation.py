import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

#=================================================================================================#

# PARAMETERS 

runs   = 500             # How many times we run the simulation
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
stop  = 50.0
step  = 0.005
tspan = np.arange(start, stop+step, step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

# LIST (for exporting)

all_params_names  =   ["runs", "J", "N", "alpha", "s", "gamma1", "gamma2", "gamma3", "K", "n1", "n2", "Qmin", "Qmax", "Dmin", "Dmax", "start", "stop", "step", "tspan", "x0"]
all_params_vals   =   [runs, J, N, alpha, s, gamma1, gamma2, gamma3, K, n1, n2, Qmin, Qmax, Dmin, Dmax, start, stop, step, tspan, x0]

#=================================================================================================#

# SYSTEM OF EQUATIONS

def dx_dt(x,t,Q,D,betaB,betaS):
    """
    Creates a list of J equations describing the number of ants
    on each of the J trails. (Eqn i corresponds to food source i)
    """
    system = np.zeros(J)
    system = (alpha* np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)
    return system

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
weight_avg_Q = np.zeros(runs)                   # Sum of (# of ants on a trail * its quality)
weight_avg_D = np.zeros(runs)                   # Sum of (# of ants on a trail * its distance)
avg_Q = np.zeros(runs)  
avg_D = np.zeros(runs)  
prop_committed_ants    = np.zeros(len(tspan))   # Proportion of committed ants 
prop_noncommitted_ants = np.zeros(len(tspan))   # Proportion of non committed ants 

def simulation():
    for w in range(runs):
        # print(int(np.floor(w*100/runs)), "%")   # Progress bar
        Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distrib      
        D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distrib     
        betaB = n1 * Q
        betaS = n2 * Q

        xs = odeint(dx_dt, x0, tspan, args=(Q,D,betaB,betaS))   # Solves the system. Columns: trail (food source), Rows: time step
        final_time[w,:] = xs[-1,:]              # 2D array of # of ants on each trail at the last timestep. Columns: trail (food source), Rows: runs.
    
        weight_avg_Q[w]  = sum((final_time[w,:] * Q)/N)  # Weighted average of quality (selected.Q in R)
        weight_avg_D[w]  = sum((final_time[w,:] * D)/N)  # Weighted average of distance (selected.D in R)

        avg_Q[w]  = sum(Q/J)  # Weighted average of quality (selected.Q in R)
        avg_D[w]  = sum(D/J)  # Weighted average of distance (selected.D in R)

    dif_btwn_avgs_Q = weight_avg_Q - avg_Q   # positive difference- picking better than environment
    dif_btwn_avgs_D = weight_avg_D - avg_D   # negative difference- picking better than environment

#=================================================================================================#

# PARAMETER SWEEPING

# Here we choose one parameter to vary (param), specifying a range and number of values to try.
# • We are exporting weighted avg info in a tidy csv, so we're creating 3 different lists
#   that will be turned into columns in a dataframe.
# • We keep track of which value was used in a particular run (row) with the param_values list.

# SWEEPING ONE PARAMETER

# param            = np.linspace(0,0.1,10)        # (start, stop, # samples). Creates array of param values to test.
# all_params_names.append("gamma3")             # ❗️⚠️ Update to match which params you're sweeping ⚠️❗️
# all_params_vals.append(param)                 # Records what param values are being tested in the paramdf

# param_values     = []                         # specifies which value's used for param during each chunk of sim runs. used in df.
# weight_avg_Q_tot = []                         # list of all the Q weighted avg values from all sim for all tested values of param
# weight_avg_D_tot = []
# for p in range(len(param)):                   # for each value of param...
#     gamma3 = param[p]
#     simulation()
#     param_values += ([param[p]] * runs)       # add param value (once for each run) to list of param values
#     weight_avg_Q_tot += list(weight_avg_Q)    # add onto list of quality weighted averages with values for this set of runs
#     weight_avg_D_tot += list(weight_avg_D)

# SWEEPING TWO PARAMETERS

param1           = np.linspace(0,0.1,10)         # ⚠️ Make sure that param1 and param2 have the same number elements in this array!
param2           = np.linspace(0,0.1,10)         # You can also use np.arrange if you want to do specify, stop, step

# all_params_names.extend("gamma2", "gamma3")     # ❗️⚠️ Update to match which params you're sweeping ⚠️❗️
# all_params_vals.extend(param1, param2)          # Records what param values are being tested in the paramdf

param1_values    = []   
param2_values    = []                           # specifies which value's used for param during each chunk of sim runs. used in df.
weight_avg_Q_tot = []                           # list of all the Q weighted avg values from all sim for all tested values of param
weight_avg_D_tot = []
dif_btwn_avgs_Q_tot = []
dif_btwn_avgs_D_tot = []
for p in range(len(param1)):                    # for each value of param1... note- (len(param1) = len(param2))                         
    for q in range(len(param2)):
        print(int(np.floor(p*100/len(param2))), "%") # Progress bar
        gamma2 = param1[p]                      # Specify the first param you want to sweep
        gamma3 = param2[q]                      # Specify the second param you want to sweep
        simulation()  
        param1_values += ([param1[p]] * runs)   # add param1 value (once for each run) to list of param values
        param2_values += ([param2[q]] * runs)  
        weight_avg_Q_tot += list(weight_avg_Q)  # add onto list of quality weighted averages with values for this set of runs
        weight_avg_D_tot += list(weight_avg_D)
        dif_btwn_avgs_Q_tot += list(dif_btwn_avgs_Q)
        dif_btwn_avgs_D_tot += list(dif_btwn_avgs_D)

#=================================================================================================#

# CREATING CSVs

# PARAMETERS
# Create dataframe of all of the parameters we're using in this set of runs
# This can help us recreate graphs and recall the context of each sweep
paramd = {'Param': all_params_names, 'Value': all_params_vals}
paramdf = pd.DataFrame(data=paramd)
#print(paramdf)

# QUALITY DIST SWEEP DATA
# One parameter:
# df = {'Param Values': param_values, 'WeightedQ': weight_avg_Q_tot,'WeightedD': weight_avg_D_tot, 'Dif Avgs Q': dif_btwn_avgs_Q_tot, 'Dif Avgs D': dif_btwn_avgs_D_tot}
# Two parameters:
df = {'Param1 Values': param1_values, 'Param2 Values': param2_values, 'WeightedQ': weight_avg_Q_tot,'WeightedD': weight_avg_D_tot, 'Dif Avgs Q': dif_btwn_avgs_Q_tot, 'Dif Avgs D': dif_btwn_avgs_D_tot}
df = pd.DataFrame(data=df)

# EXPORT
# Filename format: [params_ for param DF][swept parameters]_[# of runs]

# PARAMETERS
paramdf.to_csv(r'/Users/nfn/Desktop/Ants/params_gamma23_tiny_500r.csv', index = False) # Fletcher's path
#paramdf.to_csv( INSERT PATH , index = False)                             # Miguel's path

# QUALITY DIST SWEEP DATA
df.to_csv(r'/Users/nfn/Desktop/Ants/gamma23_tiny_500r.csv', index = False) # Fletcher's path
#df.to_csv( INSERT PATH , index = False)                                  # Miguel's path

#=================================================================================================#

# PLOTTING

#plt.rc('font', family='serif')

# The number of ants on each trail over time
#plt.figure()
#for i in range(J):
#    plt.plot(tspan, xs[:,i], label = str(i+1)) 
#plt.title('Number of ants over time',fontsize=15)
#plt.xlabel('Time',fontsize=15)
#plt.ylabel('Number of ants',fontsize=15)
#plt.legend(title='Trail', bbox_to_anchor=(1.01, 0.5), loc='center left', borderaxespad=0.)

# The proportion of ants committed to a trail
#plt.figure()
#plt.plot(tspan, prop_committed_ants) 
#plt.title('Proportion of committed ants',fontsize=15)
#plt.xlabel('Time',fontsize=15)
#plt.ylabel('Proportion',fontsize=15)

# Plotting histogram of weighted average of quality
#plt.figure()
#plt.bar(Q_edges, Q_hist, width = 0.5, color='#0504aa',alpha=0.7)
#plt.title('Histogram of weighted av Q in trials',fontsize=15)
#plt.xlabel('bins',fontsize=15)
#plt.ylabel('weighted Q',fontsize=15)

# Plotting histogram of weighted average of quality
#plt.figure()
#plt.hist(weight_avg_Q, bins = 50)
#plt.title('Histogram of weighted av Q in trials',fontsize=15)
#plt.xlabel('weighted Q',fontsize=15)
#plt.ylabel('count',fontsize=15)

# Plotting histogram of weighted average of distance
#plt.figure()
#plt.hist(weight_avg_D, bins = 50)
#plt.title('Histogram of weighted av D in trials',fontsize=15)
#plt.xlabel('weighted D',fontsize=15)
#plt.ylabel('count',fontsize=15)

# # Plotting Probability distribution of quality weighted average
# plt.figure()
# plt.bar(Q_bins[:-1], Q_distr, width = 0.5, color='#0504aa',alpha=0.7)
# plt.title('Distribution Weighted average of Quality',fontsize=15)
# plt.xlabel('Weighted Average of Quality',fontsize=15)
# plt.ylabel('Probability',fontsize=15)

# # Plotting Probability distribution of distance weighted average
# plt.figure()
# plt.bar(D_bins[:-1], D_distr, width = 0.01, color='#0504aa',alpha=0.7)
# plt.title('Distribution Weighted average of Distance',fontsize=15)
# plt.xlabel('Weighted Average of Distance',fontsize=15)
# plt.ylabel('Probability',fontsize=15)

# #plt.show()
