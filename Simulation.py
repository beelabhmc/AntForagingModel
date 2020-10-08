# Creates data using DE Model

import scipy as sc
import numpy as np
# To do: find package(s) needed for solver
#   odeint? lmao it uses lsoda like R does
#       doc: http://headmyshoulder.github.io/odeint-v2/doc/index.html 
#       more doc: https://docs.scipy.org/doc/scipy-1.2.1/reference/generated/scipy.integrate.odeint.html
#   solve_ivp (also from scipy.integrate) is allegedly more flexible than odeint, but slower
#       doc: https://docs.scipy.org/doc/scipy-1.2.1/reference/generated/scipy.integrate.solve_ivp.html
#   desolver? mostly for IVPs
#   GEKKO?

from scipy.integrate import odeint
import matplotlib.pyplot as plt

# Initialize parameters

# Parameters: J, alpha, Q_i, N, s, gamma1, gamma2, gamma3, d_i, K, eta1, eta2
"""
J: number of food sources
alpha: per capita rate of spontaneous discoveries
Q_i: quality of food source i
N: total number of ants
s: per capita rate of ant leaving trail per distance
gamma1: range of foraging scouts
gamma2: range of recruitment activity
gamma 3: range of influence of pheromone
d_i: dist btwn source i and the nest
K: inertial effects that may affect pheromones
eta1: individual ant's contribution to rate of recruitment
eta2: pheromone strength of trail
"""

J = 5 #number of food sources


