import scipy as sc
from scipy import stats
import numpy as np
import pandas as pd
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import sys
import os

# PARAMETERS

#Parameters for the simulation
runs   = 5000 # How many times we run the simulation
J      = 5               # Number of food sources (aka, number of trails to food sources)
N      = 1000           # Total number of ants

#Parameters from the equation, accessed by name
p    = {
"alpha"  : 0.75,            # Per capita rate of spontaneous discoveries
"s"      : 3.5,             # Per capita rate of ant leaving trail per distance
"gamma1" : 0.2,             # Range of foraging scouts
"gamma2" : 0.021,           # Range of recruitment activity
"gamma3" : 0.021,           # Range of influence of pheromone
"K"      : 1,               # Inertial effects that may affect pheromones
"n1"     : 20,              # Individual ant's contribution to rate of recruitment (orig. eta1)
"n2"     : 20               # Pheromone strength of trail (originally eta2)       
}

Qmin = 0
Qmax = 20
Dmin = 0
Dmax = 40

betaB  = np.zeros(J)     # How much each ant contributes to recruitment to a trail
betaS  = np.zeros(J)     # Relationship btwn pheromone strength of a trail & its quality

# TIME

start = 0.0
stop  = 50.0            
step  = 0.005
tspan = np.arange(start, stop+step, step)

# INITIAL CONDITIONS

x0 = np.zeros(J)         # We start with no ants on any of the trails

# SYSTEM OF EQUATIONS

def dx_dt(x,t,Q,D,betaB,betaS):
        """
        Creates a list of J equations describing the number of ants
        on each of the J trails. (Eqn i corresponds to food source i)
        """
        system = np.zeros(J)
        system = (p["alpha"]* np.exp(-p["gamma1"]*D) + (p["gamma2"]/D)*betaB*x)*(N-sum(x)) - (p["s"]*D*x)/(p["K"]+ (p["gamma3"]/D)*betaS*x)
        return system


# RUNS AND MODEL OUTPUT

def simulation():

    final_time = np.zeros([runs, J])
    weight_ants_avg_D = np.zeros(runs) # Sum of (# of ants on a trail * its distance)/(total number of trails)
    unweight_avg_D = np.zeros(runs)
    weight_quality_avg_D = np.zeros(runs)
    
    #cov_list = []
    qd_is_popular = 0
    closest_is_popular = 0
    closest_is_qd = 0
    neither_is_popular = 0
    for w in range(runs):
        print(f"Run {w} of {runs} is running.\r", end="")
        Q = np.random.uniform(Qmin, Qmax, J)         #Choose each trail's quality from uniform dist
        D = np.random.uniform(Dmin, Dmax, J)         #Choose each trail's distance from uniform dist
        #Generate Q and D until closest is not best q/d
        while(np.argmax(Q/D) == np.argmin(D)):
            Q = np.random.uniform(Qmin, Qmax, J)
            D = np.random.uniform(Dmin, Dmax, J) 

        betaB = p["n1"] * Q
        betaS = p["n2"] * Q

        xs = odeint(dx_dt, x0, tspan, args=(Q,D,betaB,betaS)) #Solves the system. Columns: trail, Rows: time step
        final_time[w,:] = xs[-1,:]
        weight_ants_avg_D[w] = sum(final_time[w,:] * D) / N
        unweight_avg_D[w] = sum(D)/len(D)
        weight_quality_avg_D[w] = sum(Q*D) / sum(Q)

        #Determine which food source has the largest Q/D
        largest_q_to_d = np.argmax(Q/D)
        #Determine which food source is the closest
        closest = np.argmin(D)
        #Get the trail that has the most ants on it
        most_popular = np.argmax(final_time[w,:])
        if(largest_q_to_d == most_popular):
            qd_is_popular += 1
        if closest == most_popular:
            closest_is_popular += 1
        if closest == largest_q_to_d:
            closest_is_qd += 1
        if most_popular != largest_q_to_d and most_popular != closest:
            neither_is_popular += 1
        #plot_integrate(xs, Q, D)
        print(Q/D)
        print(D)
    print(f"Food Sources: {J}")
    print(f"Went to best quality / distance proportion:  {qd_is_popular / runs}")
    print(f"Went to closest proportion: {closest_is_popular/runs}")
    print(f"Closest was highest quality / distance proportion: {closest_is_qd / runs}")
    print(f"Ants went to either: {neither_is_popular / runs}")
    return (qd_is_popular/runs, closest_is_popular/runs, neither_is_popular/runs)

def plot_integrate(xs, Q, D, display=True, save=False):
    """
    Plots the results of numerical integration from integrate
    """
    fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)
    for i in range(len(xs[0])):
        ax.plot(tspan, xs[:,i], label=f"Trail {i}")
    #ax.plot(xs.t, xs.y[0] + xs.y[1], label="Total Ants on Trail")
    #Find point at which we are using pretty much all the ants
    all_ants = 0
    for i in range(len(xs)):
        if sum(xs[i]) > 0.95*N:
            all_ants = tspan[i]
            break
    ax.axvline(x = all_ants, linestyle ="dashed")
    ax.legend()
    ax.set_xlabel("Time")
    ax.set_ylabel("Ants")
    plt.ylim([0, N])
    if save:
        plt.savefig(f"Plots/Plot-{datetime.now().strftime('%d-%m-%Y-%H-%M-%S-%f')}.png")
    if display:
        plt.show()

def manipulate_data(data):
    plt.scatter(data[2]/data[0], data[1]/data[0])
    """
    delta_ants_to_unweight = data[1] - data[0]
    delta_quality_to_unweight = data[2] - data[0]
    delta_ants_to_quality = data[1] - data[2]
    plt.scatter(-1 * delta_quality_to_unweight, -1*delta_ants_to_quality)
    plt.xlabel("Avg Unweight Dist - Avg Dist Weight by Quality")
    plt.ylabel("Avg Dist Weight by Quality - Avg Dist Weight by No. of Ants")
    print(f"Average ants to unweighted: {sum(delta_ants_to_unweight)/len(delta_ants_to_unweight)}")
    print(f"Average ants to quality: {sum(delta_ants_to_quality)/len(delta_ants_to_quality)}")
    """
    #plt.xticks(np.linspace(0, 2, 11))
    #plt.yticks(np.linspace(0,2, 11))
    print(f"Covariance: {np.cov(data[2]/data[0], data[1]/data[0])[0][1]}")
    plt.title(f"Covariance: {round(np.cov(data[2]/data[0], data[1]/data[0])[0][1], 3)}")
    plt.show()

def plot_fit(b, weight_avg):
    """
    plot fit takes in the list of weighted averages, plots a histogram of their distribution,
        and then plots the fitted distribution calculated by get_fit over them, mostly used for
        sanity-checking.
    """
    # Make our plot
    plt.rcParams['text.usetex'] = True                      #Comment out this line if you don't want to render latex.
    fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)

    # Plot the normalized average weight histogram
    counts, bins = np.histogram(weight_avg)
    ax.stairs(100*counts/((bins[1]-bins[0])*sum(counts)), bins)

    # Plot the fitted distribution on top
    x_fitted = np.linspace(np.min(bins), np.max(bins), 100)
    y_fitted = 100 * (1/b) * np.exp((-1/b) * x_fitted) 
    ax.plot(x_fitted, y_fitted)

    ax.set_xlabel("Weighted Average of Distance to Food Source")
    ax.set_ylabel('$10^{-2}$ Density')
    plt.show()

def get_fit(weight_avg):
    """
    get_fit takes in a list of weighted averages generated by simulation and returns lambda,
        which is the parameter of an exponential distribution
    """
    b = stats.expon.fit(weight_avg, floc=0)[1]
    print(f"beta: {b}")
    return b

def get_covariance(data):
    return np.cov(data[2]/data[0], data[1]/data[0])[0][1]

def sweep_one_covariance(param, values):
    """sweep_one_covariance takes in the name of a parmeter param string (ex: "alpha") and a list of
       the values to run a sweep on.
       Returns two arrays, the first containing the values and the second the resulting covariances
    """
    cov_list = []
    for val in values:
        print(f"Setting {param} to {val}")
        p[param] = val
        cov_list.append(get_covariance(simulation()))

    return param, values, cov_list

def plot_sweep_one(sweep_data):
    """ 
    plot_sweep_one takes in the output of sweep_one_fit and plots the values
    """
    # Make our plot
    #plt.rcParams['text.usetex'] = True                      #Comment out this line if you don't want to render latex.
    fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)

    ax.plot(sweep_data[1], sweep_data[2])

    ax.set_xlabel(sweep_data[0])
    ax.set_ylabel("Covariance of Normalized Weighted Averages")
    plt.xscale("log")
    plt.show()


def sweep_one_fit(param, values, save=True):
    """ sweep_one_takes in the name of a parameter param string (ex: "alpha") and a list of the values
        to run a sweep on.
        Returns two arrays, the first containing the values and the second the resulting b value.
    """
    b_list = []
    for val in values:
        #Iterate through all the values and get the resulting Beta value
        p[param] = val
        b_list.append(get_fit(simulation()))
    if save:
        #Save the data
        d = {"values": values, "betas": b_list}
        df = pd.DataFrame(data = d)
        df.to_csv(f'{path.dirname(__file__)}/results/{param}-sweep-.csv', index = False)

    return param, values, b_list


def sweep_two_fit(param1, param2, values1, values2):
    index = values1
    columns = values2
    df = pd.DataFrame(0, index = index, columns = columns)
    for val1 in values1:
        for val2 in values2:
             p[param1] = val1
             p[param2] = val2
             df.at[val1,val2] = get_fit(simulation())
    return df, param1, param2
    

def plot_sweep_two(sweepdata):
    """ 
    plot_sweep_two takes in the output of sweep_one_fit and plots the values
    """
    fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)
    # Displaying dataframe as an heatmap
    # with diverging colourmap as RdYlBu
    plt.imshow(sweepdata[0], cmap ="RdYlBu")
  
    # Displaying a color bar to understand
    # which color represents which range of data
    plt.colorbar()
  
    # Assigning labels of x-axis 
    # according to dataframe
    plt.xticks(range(len(sweepdata[0])), sweepdata[0].index)
  
    # Assigning labels of y-axis 
    # according to dataframe
    plt.yticks(range(len(sweepdata[0])), sweepdata[0].columns)

    ax.set_xlabel(sweepdata[1])
    ax.set_ylabel(sweepdata[2])
  
    # Displaying the figure
    plt.show()

"""
runs = 1000
results = []
num_ants = []
for i in range(2, 10):
    print(f"{i} food sources \n")
    J = i
    x0 = np.zeros(J)
    num_ants.append(i)
    results.append(simulation())
print(results)
qd = [i[0] for i in results]
di = [i[1] for i in results]
ne = [i[2] for i in results]

fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)
ax.plot(num_ants, qd, label="Best ratio of quality to distance")
ax.plot(num_ants, di, label="Closest")
ax.plot(num_ants, ne, label="Neither")
ax.set_xlabel("Number of Food Sources")
ax.set_ylabel("Proportion to Food Source")
ax.legend()
plt.show()
"""
J = 10
x0 = np.zeros(J)
runs = 1
simulation()

#plot_fit(get_fit(sim), sim)
#plot_sweep_one(sweep_one_fit("gamma2", [5.8e-7, 2.96e-6, 5.8e-6, 1.2e-5, 5.8e-5]))
#plot_sweep_two(sweep_two_fit("gamma2", "n1", [5.8e-7, 2.96e-6, 5.8e-6, 1.2e-5, 5.8e-5], [0.12, 0.6, 1.2, 2.4, 12]))
#plot_sweep_one(sweep_one_covariance("n2", [20 / 100, 20 / 10, 20, 20*10, 20*100]))
#manipulate_data(simulation())
