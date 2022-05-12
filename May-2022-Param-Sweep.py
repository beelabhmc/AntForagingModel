from re import S
import scipy as sc
import numpy as np
import pandas as pd
from scipy.integrate import odeint
from scipy.integrate import solve_ivp
import matplotlib.pyplot as plt
import sys
from tqdm import tqdm
#np.set_printoptions(threshold=sys.maxsize) # This allows to you to print large arrays without truncating them

print("\n\n")
#=================================================================================================#
"""
This code runs the model for a set of parameters (sweeping 2 parameters at 5 different values each)
and produces a csv detailing the number of ants on each trail and their associated weighted averages of 
quality and distance.

The first time you run the code, make sure to call create_QDs() to create a list of quality and
distance values in your speicified range. When you run the code again, you can import that list
to ensure colonies are deciding between the same resources in each graph you make.

Search for ":3" to find the places where you'll need to update file names and parameters.

"""
#=================================================================================================#


# PARAMETERS 
#LOW : etas 0.1, gammas 0.00001
#HIGH: etas 10, gammas 0.01

runs   = 200              
J      = 2           
N      = 5000            
alpha    =  0.006
s      = 0.0004
gamma1 = 0.02
gamma2 =  0.0021             
gamma3 =  0.0021               
K      = 0.02
n1     =  1             
n2     =  1           
Qmin = 0.1          
Qmax = 0.25
Dmin = 2.75            
Dmax = 5

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# SOLVER BEHAVIOR

convergence_range = 10 # range for dx_dt max to signal convergence

# TIME 

start = 0.0
stop  = 200.0            # One of our goals is to change this cutoff to reflect convergence
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
    x = [y if y > 0 else 0 for y in x]
    return [(alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)] # set the floor of the output to 0
    #return (alpha * np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x) # set the floor of the output to 0

# Function that checks for convergence
def convergence(t,x,D,betaB,betaS):
    m = np.amax([abs(y) for y in rhs(t,x,D,betaB,betaS)])
    if m < convergence_range:
        return 0 
    else:
        return m
convergence.terminal = True


# RUNS AND MODEL OUTPUT

density      = np.zeros([runs,J])
final_time   = np.zeros([runs,J])
# weight_avg_Q = np.zeros(runs)                   # Sum of (# of ants on a trail * its quality) over all trails
# weight_avg_D = np.zeros(runs)                   # Sum of (# of ants on a trail * its distance) over all trails
avg_Q = np.zeros(runs)  
avg_D = np.zeros(runs) 
dif_btwn_avgs_Q = np.zeros(runs)  
dif_btwn_avgs_D = np.zeros(runs)  
prop_committed_ants    = np.zeros(len(tspan))   # Proportion of committed ants (committed =  on a trail)
prop_noncommitted_ants = np.zeros(len(tspan))   # Proportion of non-committed ants 

def create_QDs():
    """
    Creates a list of quality and distance values for simulation runs
    This is used to ensure each parameter convo is run on the same resource choices
    """
    qdlist = []
    for w in range(runs):
        Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distribution      
        D = np.random.uniform(Dmin,Dmax,J) 
        rowToAdd = np.concatenate((Q,D))
        qdlist.append(rowToAdd)
    qdlist_names = []
    for i in range(J):
        qdlist_names.append("Q" + str(i+1))
    for i in range(J):
        qdlist_names.append("D" + str(i+1))
    qdlist = pd.DataFrame.from_records(qdlist, columns = qdlist_names) 
    qdlist.to_csv(r'/Users/nfn/Desktop/Ants/QD_list_april_29_j2.csv', index = False) # Fletcher's path :3


# REMOVE after first run :3
create_QDs()

#WHEN USING PRE-GENERATED Q and D
qd_df = pd.read_csv (r'/Users/nfn/Desktop/Ants/QD_list_april_29_j2.csv') # Import quality and distance list :3
q_df = qd_df[['Q1','Q2']]#,'Q3','Q4','Q5']]  # These are hard-coded for J = 5
d_df = qd_df[['D1','D2']]#,'D3','D4','D5']] 

qd_df_index = 0

def wavg_no_zeores(top_final_vals, top_Q, top_D):
    """
    Compute weighted averages of quality and distance without including
    trails with zero ants on them in the calculation

    Note that some of the averages (ex. top 5, top 4, top 3, etc.) may be
    the same if some trails don't have any ants on them.
    """
    
    nonzero_topfinal = []
    nonzero_topQ = []
    nonzero_topD = []
    
    nonzeroind = np.nonzero(top_final_vals)[0]     #list of the indices of top_final_vals that are non-zero

    for index in nonzeroind:
        nonzero_topfinal.append(top_final_vals[index])
        nonzero_topQ.append(top_Q[index])
        nonzero_topD.append(top_D[index])
    
    
    no_zeros_avg_Q = sum((nonzero_topfinal * np.array(nonzero_topQ))/N)
    no_zeros_avg_D = sum((nonzero_topfinal * np.array(nonzero_topD))/N)


    return (no_zeros_avg_Q, no_zeros_avg_D)

#convarray = np.empty((J*3+1,1))
def ivp_simulation(qd_df_index):
    # This version is a test that uses SciPy solve_ivp instead of odeint
    # with the eventual goal of using solve_ivp's event detector to stop
    # the simulation on convergence.
    # 
    # Array we want looks like:
    # Q1, Q2, Q3.., D1, D2, D3..., final val 1, final val 2, final val 3,...
    # conv time

    #convarray = np.empty((1,J*3+1))

    convlist = []
    for w in  tqdm(range(runs)):
        x0 = np.zeros(J)

        #WHEN USING PRE-GENERATED Q and D
        Q = np.array(q_df.loc[qd_df_index])
        D = np.array(d_df.loc[qd_df_index])
       
        # WHEN GENERATING Q and D ON THE FLY
        #Q = np.random.uniform(Qmin,Qmax,J)      # Choose each trail's quality from uniform distribution      
        #D = np.random.uniform(Dmin,Dmax,J)      # Choose each trail's distance from uniform distribution     
        
        qd_df_index += 1
        betaB = n1 * Q
        betaS = n2 * Q
        #sol = solve_ivp(rhs,[start,stop],x0,args=(D,betaB,betaS),dense='true',method = 'LSODA')
        sol = solve_ivp(rhs,[start,stop],x0,events=convergence,args=(D,betaB,betaS),method = 'LSODA')
        rowToAdd = np.concatenate((Q,D))
        rowToAdd = rowToAdd.tolist()
        finalvals = sol.y[:,-1].tolist()
        rowToAdd = rowToAdd + finalvals + [sol.t[-1]] # Qs + Ds + final ants + final time
        rowToAdd = rowToAdd + [K] + [s] #CHANGE PARAMS HERE :3


        #do quality, dist averages
        # add them to rowtoadd which adds them to convlist
        #add to colnamer
        wavgsQ = [0] * J
        wavgsD = [0] * J
        topfinal = finalvals
        topQ = Q.tolist()
        topD = D.tolist()
        for i in range(J):
            #wavgsQ[i] = sum((topfinal * np.array(topQ))/N)
            #wavgsD[i] = sum((topfinal * np.array(topD))/N)

            wavgsQ[i] = wavg_no_zeores(topfinal, topQ, topD)[0]
            wavgsD[i] = wavg_no_zeores(topfinal, topQ, topD)[1]


            smallests_index = topfinal.index(min(topfinal))
            topfinal.remove(min(topfinal))
            del topQ[smallests_index]
            del topD[smallests_index]

            

        #weight_avg_Q  = sum((finalvals * Q)/N)  # Weighted average of quality (selected.Q in R)
        #weight_avg_D  = sum((finalvals * D)/N)  # Weighted average of distance (selected.D in R)
        


        rowToAdd = rowToAdd + [wavgsQ[0]] + [wavgsD[0]]+ [wavgsQ[1]] + [wavgsD[1]]#+ [wavgsQ[2]] + [wavgsD[2]]+ [wavgsQ[3]] + [wavgsD[3]]+ [wavgsQ[4]] + [wavgsD[4]]


        convlist.append(rowToAdd)
        #print("Length (expect 3 * J + 1): ", len(rowToAdd)) 
        # rowlen = len(rowToAdd)
        # rowToAdd = np.array(rowToAdd)
        # rowToAdd = rowToAdd.reshape(1, rowlen)
        # print(rowToAdd.shape)
        #print("ROW SHAPE: ", rowToAdd.shape, (np.transpose(rowToAdd.shape)).shape)

    #convarray = np.vstack([convarray, rowToAdd])
    #print("convlist", convlist)
    #return(sol,[list(Q),list(D)])
    return(sol, convlist)

#make the list of column names 
def colnamer():
    names = []
    for i in range(J):
        names.append("Q" + str(i+1))
    for i in range(J):
        names.append("D" + str(i+1))
    for i in range(J):
        names.append("Final Ants " + str(i+1))
    names.append("Convergence Time")
    names.append("K")     #CHANGE PARAMS HERE :3
    names.append("s")         #CHANGE PARAMS HERE :3
    #names.append("WavgQTop5")
   # names.append("WavgDTop5")
    #names.append("WavgQTop4")
    #names.append("WavgDTop4")
    #names.append("WavgQTop3")
    #names.append("WavgDTop3")
    names.append("WavgQTop2")
    names.append("WavgDTop2")
    names.append("WavgQTop1")
    names.append("WavgDTop1")
    return names

convlist = []
# The "middle" value of the parameters we're sweeping
basea = 0.01                    # ⬅️❗️⚠️ #CHANGE PARAM VALUES HERE :3
baseb = 0.0004 

avals = [0.1* basea , 0.5* basea, basea , 2*basea, 10*basea]      
bvals = [0.1* baseb , 0.5* baseb , baseb  , 2*baseb , 10*baseb]

for p in tqdm(range(len(avals))):                    # for each value of paramA... (assumes len(avals) = lensouthboundvals))                         
    for q in range(len(bvals)):
        K = avals[p]                      # ⬅️❗️⚠️ #CHANGE PARAMS HERE :3
        s = bvals[q]                      # ⬅️❗️⚠️ #CHANGE PARAMS HERE :3
        #print(K)
        #print(s)
        
        #print("\nrun "+ q + " of 25\n")


        # When starting a new set of parameters, return to the top fo the list of quality/distance values.
        qd_df_index = 0
        convlist = convlist + ivp_simulation(qd_df_index)[1]

colnameslist = colnamer()
convdf = pd.DataFrame.from_records(convlist, columns = colnameslist) 
#print(convdf)
convdf.to_csv(r'/Users/nfn/Desktop/Ants/APRIL29-ks-v1.csv', index = False) # Fletcher's path :3

# sol.t is timesteps
# sol.y is the solutions: one row for each trail, timesteps are cols
# this is the transpose of odeint's output

testruns = 100

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

