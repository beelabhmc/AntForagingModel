import numpy as np
from scipy.integrate import solve_ivp
from matplotlib import pyplot as plt
from datetime import datetime

# Parameters
p    = {
        "alpha"  : 0.05,            # Per capita rate of spontaneous discoveries
        "s"      : 3.5,             # Per capita rate of ant leaving trail per distance
        "gamma1" : 0.2,             # Range of foraging scouts
        "gamma2" : 0.021,           # Range of recruitment activity
        "gamma3" : 0.021,           # Range of influence of pheromone
        "K"      : 1,               # Inertial effects that may affect pheromones
        "n1"     : 20,              # Individual ant's contribution to rate of recruitment (orig. eta1)
        "n2"     : 20               # Pheromone strength of trail (originally eta2)
}

N = 10000 #Number of ants

#Controls Timespan and integration steps
start = 0.0
stop  = 0.002
tspan = [start, stop]

def dx_dt(t, x, D, Q):
    system = np.zeros(2) #Only two trails
    system = (p["alpha"]* np.exp(-p["gamma1"]*D) + (p["gamma2"]/D)*p["n1"]*Q*x)*(N-sum(x)) - (p["s"]*D*x)/(p["K"]+ (p["gamma3"]/D)*p["n2"]*Q*x)
    return system

def steady_state(t, x):
    """
    Returns 1 until the number of ants on one of the trails is basically all the ants.
    Then, it returns -1 to telll solve_ivp to stop integrating.
    TODO: Finish
    """
    for i in x:
        if N - i < 1:
            return 1.0
    return -1.0

def integrate(D, Q):
    """
    Numercally integrates the system and returns an object with time and ants per trail.
    Stops integrating once one trail has all of the ants
    """
    steady_state.terminal = True
    steady_state.direction = 1
    xs = solve_ivp(dx_dt, tspan, np.zeros(2), args = (D, Q))
    return xs

def plot_integrate(xs, Q, D, display=True, save=False):
    """
    Plots the results of numerical integration from integrate
    """
    fig, ax = plt.subplots(figsize=(6,4), tight_layout=True)
    ax.plot(xs.t, xs.y[0], label="Trail 1")
    ax.plot(xs.t, xs.y[1], label="Trail 2")
    ax.plot(xs.t, xs.y[0] + xs.y[1], label="Total Ants on Trail")
    ax.legend()
    plt.title(f"Q: {Q}, D: {D}")
    ax.set_xlabel("Time")
    ax.set_ylabel("Ants")
    plt.ylim([0, N])
    if save:
        plt.savefig(f"Plots/Plot-{datetime.now().strftime('%d-%m-%Y-%H-%M-%S-%f')}.png")
    if display:
        plt.show()
    

D = np.array((10.0,20.0))
Q = np.array((30.0,30.0))
loop = True
while loop:
    xs = integrate(D,Q)
    #Initially, we expect Trail 1 to be the more popular one at steady state
    #Keep incrementing the quality of Trail 2 until it is the more popular one.
    trail1_ss = xs.y[0][-1]
    trail2_ss = xs.y[1][-1]
    plot_integrate(xs, Q, D, save=True, display=False)
    if trail1_ss < trail2_ss:
        break
    Q[1] *= 1.1
