import sympy as sym

#Set up variables
X, alpha, gamma1, gamma2, gamma3, eta1, eta2, s, K, N, q1, d1, q2, d2 = sym.symbols('X alpha gamma1 gamma2 gamma3 eta1 eta2 s K N q1 d1 q2 d2')

#system = (alpha* np.exp(-gamma1*D) + (gamma2/D)*betaB*x)*(N-sum(x)) - (s*D*x)/(K+ (gamma3/D)*betaS*x)
#Equation
eq1 = (alpha * sym.exp(-gamma1 * d1) + gamma2*eta1* (q1/d1)*X) * (N - X) - (s*d1*X)/ (K + gamma3*eta2*(q1/d1)*X)
eq2 = (alpha * sym.exp(-gamma1 * d2) + gamma2*eta1* (q2/d2)*X) * (N - 2*X) * (K + gamma3*eta2*(q2/d2)*X)-s*d2*X

#Parameters
alphaV  = 50
sV      = 3.5
gamma1V = 0.2
gamma2V = 0.021
gamma3V = 0.021
KV      = 1
n1V     = 20
n2V     = 20
NV = 10000
q1V = 30
d1V = 10
q2V = 64
d2V = 20

#Substitute in the parameters
eq1V = eq1.subs([(alpha, alphaV),
         (s, sV),
         (gamma1, gamma1V),
         (gamma2, gamma2V),
         (gamma3, gamma3V),
         (K, KV),
         (eta1, n1V),
         (eta2, n2V),
         (N, NV),
         (q1, q1V),
         (d1, d1V)])

eq2V = eq2.subs([(alpha, alphaV),
         (s, sV),
         (gamma1, gamma1V),
         (gamma2, gamma2V),
         (gamma3, gamma3V),
         (K, KV),
         (eta1, n1V),
         (eta2, n2V),
         (N, NV),
         (q2, q2V),
         (d2, d2V)])
#print(eq1V)
#print(sym.solve([eq1V, eq2V], [X1, X2]))

solu = sym.latex(sym.solve(eq1, q1))

print(solu)
#print(sym.latex(sym.simplify(eq2Sub)))
#sym.solve(eq2Sub, X1)
