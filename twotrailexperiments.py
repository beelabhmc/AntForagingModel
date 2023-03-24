import numpy as np
from scipy.integrate import solve_ivp, odeint
from matplotlib import pyplot as plt
from datetime import datetime
#from sympy import solve, evalf, symbols, nsolve
# Parameters
p    = {
        "alpha"  : 50,            # Per capita rate of spontaneous discoveries
        "s"      : 1.2,             # Per capita rate of ant leaving trail per distance
        "gamma1" : 0.26,             # Range of foraging scouts
        "gamma2" : 0.1,           # Range of recruitment activity
        "gamma3" : 0.021,           # Range of influence of pheromone
        "K"      : 50,               # Inertial effects that may affect pheromones
        "n1"     : 20,              # Individual ant's contribution to rate of recruitment (orig. eta1)
        "n2"     : 20              # Pheromone strength of trail (originally eta2)
}

N = 10 #Number of ants
J = 2 # Number of trails

#Controls Timespan and integration steps
start = 0.0
stop  = 30
step = 0.005
#tspan = np.arange(start, stop+step, step)
tspan = [start, stop]
#teval = np.arange(start,stop+step,step)
A = np.array([20.0,   10.0])
B = np.array([0.1,     0.2])
def dx_dt_gen(t, x, D, Q, A, B):
    system = np.zeros(J)
    system = (A + B*x) * (N - sum(x)) - (p["s"]*D*x)/(p["K"]+ (p["gamma3"]/D)*p["n2"]*Q*x)
    return system

def dx_dt(t,x, D, Q):
    system = np.zeros(J) #Only two trails
    system = (p["alpha"]* np.exp(-p["gamma1"]*D) + (p["gamma2"]/D)*p["n1"]*Q*x)*(N-sum(x)) - (p["s"]*D*x)/(p["K"]+ (p["gamma3"]/D)*p["n2"]*Q*x)
    return system

def integrate(D, Q):
    """
    Numercally integrates the system and returns an object with time and ants per trail.
    """
    #xs = solve_ivp(dx_dt, tspan, np.zeros(J), args = (D, Q), t_eval = teval)
    xs = solve_ivp(dx_dt_gen, tspan, np.zeros(J), args = (D, Q, A, B))
    #xs = odeint(dx_dt, np.zeros(1), tspan, args=(D,Q))
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
    A = (p["alpha"]* np.exp(-p["gamma1"]*D))
    B = (p["gamma2"]/D)*p["n1"]*Q
    plt.title(f"Q: {Q}, D: {D}, B: {B}")
    ax.set_xlabel("Time")
    ax.set_ylabel("Ants")
    plt.ylim([0, N])
    if save:
        plt.savefig(f"Plots/Plot-{datetime.now().strftime('%d-%m-%Y-%H-%M-%S-%f')}.png")
    if display:
        plt.show()
    

"""
while loop:
    xs = integrate(D,Q)
    #Initially, we expect Trail 1 to be the more popular one at steady state
    #Keep incrementing the quality of Trail 2 until it is the more popular one.
    trail1_ss = xs.y[0][-1] + B*x)*(N-2*x)*(K+L*x)-s*x
    trail2_ss = xs.y[1][-1]
    #plot_integrate(xs, Q, D, save=True, display=False)
    print
    if trail1_ss < trail2_ss:
        break
    Q[1] *= 1.1
D1 = 10.0
Q1 = 30.0
A = (p["alpha"]* np.exp(-p["gamma1"]*D1))
B = (p["gamma2"]/D1)*p["n1"]*Q1
s = p["s"]*D1
K = p["K"]
L = p["gamma3"] * p["n2"] * Q1 / D1

x1 = symbols('x1')
x2 = symbols('x2')
eq1 = (A + B*x1)*(N-x1-x2)*(K+L*x1)-s*x1

D2 = 20.0
Q2 = 67.0
A = (p["alpha"]* np.exp(-p["gamma1"]*D2))
B = (p["gamma2"]/D2)*p["n1"]*Q2
s = p["s"]*D2
K = p["K"]
L = p["gamma3"] * p["n2"] * Q2 / D2

eq2 = (A + B*x2)*(N-x1-x2)*(K+L*x2)-s*x2

print(eq1)
print(eq2)
ss = nsolve([eq1,eq2], [x1,x2],[N/2,N/2])

print(ss)
"""
def q_from_dX(d, X):
    D1 = (1/(2*X))*(p["K"]/(p["n2"]*p["gamma3"]) - (p["alpha"]*np.exp(-d*p["gamma1"]))/(p["n1"]*p["gamma2"]))
    D2 = (d/(N-X)) * (p["s"]/(X*p["n1"]*p["n2"]*p["gamma2"]*p["gamma3"]))
    D3 = (1/(2*X))*(p["K"]/(p["n2"]*p["gamma3"]) + (p["alpha"]*np.exp(-d*p["gamma1"]))/(p["n1"]*p["gamma2"]))
    return d*(np.sqrt(D1**2 + D2) - D3)
D = np.array((10.0, 20.0))
Q = np.array((30, 60) )
print(f"Quality and Distance: {Q, D}")
print(f"Desired Steady State: {0}")
xs = integrate(D,Q)

print(f"Number of ants on trail at end of simulation: {xs.y[-1]}")
plot_integrate(xs, Q, D)


