% Attempt to run solver with the non-negative option set to compare to
% results in python. Current version is hard-coded to J=5 to get it running

% This version runs, but there's an error with the plot line.

tspan = [0 5];
y0 = [0 0 0 0 0];

options = odeset('NonNegative',1);
[t,y] = ode45(@(t,y) odefun(t,y), tspan, y0, options);

%       ode23s runs but does not have non-negative ability

plot(t,y(:,1),'-o',t,y(:,2),'-.', y(:,3),'--',y(:,4),'-x',y(:,5),'-*')
% Error: "Data must be a single input of y-values or one or more pairs of
% x- and y-values."

%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%
%%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%=%%

function dydt = odefun(t,y)

% Hard-coded to J = 5 just to get it running
% If it works, will make it work for other Js

% INITIALIZE PARAMETERS

N      = 5000;                %# Total number of ants
alphaa = 9.170414*10^1;       %# Per capita rate of spontaneous discoveries
s      = 8.124702*10^1;       %# Per capita rate of ant leaving trail per distance
gamma1 = 1.186721*10^1;       %# Range of foraging scouts
gamma2 = 5.814424*10^(-6);    %# Range of recruitment activity 
gamma3 = 1.918047*10^(-3);    %# Range of influence of pheromone 
K      = 8.126483*10^(-3);    %# Inertial effects that may affect pheromones 
n1     = 1.202239;            %# Individual ant's contribution to rate of recruitment (orig. eta1)
n2     = 9.902102*10^(-1);    %# Pheromone strength of trail (originally eta2)

Qmin = 0;                 %# Minimum & Maximum of Quality uniform distribution
Qmax = 20;
Dmin = 0;                 %# Minimum & Maximum of Distance uniform distribution
Dmax = 0.5;

%=============================================%

% QUALITY AND DISTANCE SELECTION

Q1 = (Qmax-Qmin).*rand + Qmin;
Q2 = (Qmax-Qmin).*rand + Qmin;
Q3 = (Qmax-Qmin).*rand + Qmin;
Q4 = (Qmax-Qmin).*rand + Qmin;
Q5 = (Qmax-Qmin).*rand + Qmin;

D1 = (Dmax-Dmin).*rand + Dmin;
D2 = (Dmax-Dmin).*rand + Dmin;
D3 = (Dmax-Dmin).*rand + Dmin;
D4 = (Dmax-Dmin).*rand + Dmin;
D5 = (Dmax-Dmin).*rand + Dmin;

%=============================================%

%BETA PARAMETERS

betaB1 = n1 * Q1;
betaB2 = n1 * Q2;
betaB3 = n1 * Q3;
betaB4 = n1 * Q4;
betaB5 = n1 * Q5;

betaS1 = n2 * Q1;
betaS2 = n2 * Q2;
betaS3 = n2 * Q3;
betaS4 = n2 * Q4;
betaS5 = n2 * Q5;

%=============================================%

% CREATE SYSTEM OF EQUATIONS

dydt = zeros(5,1);
dydt(1)= (alphaa * exp(-gamma1*D1) + (gamma2/D1)*betaB1*y(1))*(N-(y(1)+y(2)+y(3)+y(4)+y(5))) - (s*D1*y(1))/(K+ (gamma3/D1)*betaS1*y(1));
dydt(2)= (alphaa * exp(-gamma1*D2) + (gamma2/D2)*betaB2*y(2))*(N-(y(1)+y(2)+y(3)+y(4)+y(5))) - (s*D2*y(2))/(K+ (gamma3/D2)*betaS2*y(2));
dydt(3)= (alphaa * exp(-gamma1*D3) + (gamma2/D3)*betaB3*y(3))*(N-(y(1)+y(2)+y(3)+y(4)+y(5))) - (s*D3*y(3))/(K+ (gamma3/D3)*betaS3*y(3));
dydt(4)= (alphaa * exp(-gamma1*D4) + (gamma2/D4)*betaB4*y(4))*(N-(y(1)+y(2)+y(3)+y(4)+y(5))) - (s*D4*y(4))/(K+ (gamma3/D4)*betaS4*y(4));
dydt(5)= (alphaa * exp(-gamma1*D5) + (gamma2/D5)*betaB5*y(5))*(N-(y(1)+y(2)+y(3)+y(4)+y(5))) - (s*D5*y(5))/(K+ (gamma3/D5)*betaS5*y(5));

end



