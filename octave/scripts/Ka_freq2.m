function Ka=Ka_freq2(freq,ro_v,P,Tatm,w);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Returns the atmospheric absorption coefficient [Neper/Km]
% at the points specified by the vector h [Km] at the frequency
% specified by the scalar freq [GHz], using the formula (14) and
% the "Atmospheric Absorption Models" proposed in the Cortes 
% paper "Antenna Noise Temperature Calculation".
% For its calculations require also the profiles of:
% the air density [Kg/m^3], the vapor density [g/m^3], 
% the atmospheric pressure [mbar] and the atmospheric 
% temperature [K] at the same point specified by the vector h. 
% w is the liq. water content [g/m^3]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%Oxygen absorption
freq_p=[56.2648,58.4466,59.5920,60.4348,61.1506,61.8002,62.4112,62.9980,63.5685,64.1278,64.6789,65.2241,65.7647,66.3020,66.8367,67.3694,67.9007,68.4308,68.9601,69.4887];
freq_m=[118.7503,62.4863,60.3061,59.1642,58.3239,57.6125,56.9682,56.3634,55.7838,55.2214,54.6711,54.1300,53.5957,53.0668,52.5422,52.0212,51.5030,50.9873,50.4736,49.9618];
Y_p=[4.51,4.94,3.52,1.86,0.33,-1.03,-2.23,-3.32,-4.32,-5.26,-6.13,-6.99,-7.74,-8.61,-9.11,-10.3,-9.87,-13.2,-7.07,-25.8]*1e-4;
Y_m=[-.214,-3.78,-3.92,-2.68,-1.13,.344,1.65,2.84,3.91,4.93,5.84,6.76,7.55,8.47,9.01,10.3,9.86,13.3,7.01,26.4]*1e-4;

gamma_j=1.18*(P/1013).*((300./Tatm).^0.85); %Resonant line-width parameter, formula (23) of the Cortes paper
gamma_b=0.49*(P/1013).*((300./Tatm).^0.89); %Non resonant line-width parameters, formula (23) of the Cortes Paper

FO2=((0.7*gamma_b)./(freq^2+gamma_b.^2));


for i=1:20
    j=i*2-1;
    FI_j=(4.6e-3)*(300./Tatm)*(2*j+1).*exp((-6.89e-3)*(300./Tatm)*j*(j+1)); % Fractional population of the initial state associated with the line, formula (21) of the Cortes paper
    G_P_FREQP=(gamma_j*((d_jp(j))^2)+(freq-freq_p(i))*Y_p(i)*P)./((freq-freq_p(i))^2+gamma_j.^2);
    G_M_FREQP=(gamma_j*((d_jm(j))^2)+(freq-freq_m(i))*Y_m(i)*P)./((freq-freq_m(i))^2+gamma_j.^2);
    G_P_FREQM=(gamma_j*((d_jp(j))^2)+(-freq-freq_p(i))*Y_p(i)*P)./((-freq-freq_p(i))^2+gamma_j.^2);
    G_M_FREQM=(gamma_j*((d_jm(j))^2)+(-freq-freq_m(i))*Y_m(i)*P)./((-freq-freq_m(i))^2+gamma_j.^2);
    FI_j_per_quadra=FI_j.*(G_P_FREQP+G_P_FREQM+G_M_FREQP+G_M_FREQM);
    FO2=FO2+FI_j_per_quadra;
end


KO2=1.61e-2*freq^2*(P/1013).*((300./Tatm).^2).*FO2; %Oxygen absorption coefficient [dB/Km], formula (19) of the Cortes paper


%Water Vapor absorption
Delta_k=(4.75e-6).*ro_v.*(P/1013).*((300./Tatm).^(2.1))*(freq^2);
freq_i=[22.23515,183.31012,323,325.1538,380.1968,390,436,438,442,448.0008];
E=[644,196,1850,454,306,2199,1507,1070,1507,412];
A=[1,41.9,334.4,115.7,651.8,127,191.4,697.6,590.2,973.1];
gamma_iO=[2.85,2.68,2.3,3.03,3.19,2.11,1.5,1.94,1.51,2.47];
a=[1.75,2.03,1.95,1.85,1.82,2.03,1.97,2.01,2.02,2.19];
x=[.626,.649,.420,.619,.630,.330,.290,.360,.332,.510];

KH2O=Delta_k;
for i=1:10
    gamma_i=gamma_iO(i)*(P/1013).*((300./Tatm).^x(i)).*(1+1e-2*a(i)*((ro_v.*Tatm)./P));
    FH2O=gamma_i./((freq_i(i)^2-freq^2)^2+4*freq^2.*(gamma_i.^2));
    KH2O=KH2O+(2*freq^2*A(i))*ro_v.*((300./Tatm).^(5/2)).*(exp(-E(i)./Tatm)).*FH2O;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Th=(300./Tatm);
gamma1=20.20-146*(Th-1)+316*(Th-1).^2;
gamma2=39.8*gamma1;
e0=77.66+103.3*(Th-1);
e1=0.0671*e0;
e2=3.52;
er_r=e0-freq^2*( (e0-e1)./(freq^2+gamma1.^2) + (e1-e2)./(freq^2+gamma2.^2) );
er_i=freq* ( gamma1.*(e0-e1)./(freq^2+gamma1.^2) + gamma2.*(e1-e2)./(freq^2+gamma2.^2) );
N=4.5.*w.*(er_i./((er_r+2).^2+(er_i).^2));
Kliq=0.1820*freq*N;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%keyboard
Ka_dB=KH2O+KO2+Kliq; %Atmospheric absorption coefficient [dB/Km], formula (14) of the Cortes paper
Ka=0.1*log(10)*Ka_dB; %Atmospheric absorption coefficient [Neper/Km], see note 4 at page 8 of the Cortes paper
