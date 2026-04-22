function [Tm,ZDD,ZWD,ZDDS,ZWDS,PW,LW,IWV]=pwl5(TMP,DPT,PRS,HGT,CLW,RH)
%
% franco buffa - 2015
%
% Tm,        T media atm. calcolata
% ZDD,ZWD,   calcolati
% ZDDS,ZWDS, modello Saast.
% PW,        IWV calcolato a partire dalla quota z0
% LW,        ILW calcolato a partire dalla quota z0
%
  g=9.784;
  Rd=287.05;
  RS=8.314472;
  mw=0.018015;
  md=0.0289644;
  eps0=mw/md;
  k1=77.60;
  k2=70.4;
  k3=3.739E5;
  T0=273.15;
  RV=461.525;  % [J/(kg*K)] GAS CONSTANT FOR WATER VAPOR
%
  DPT=DPT-T0;
%
  e=exp(1.81+17.27*DPT./(DPT+237.5));
  q=eps0*e./PRS;
  ZWD0= (q*Rd/g/eps0).*((k2-k1*eps0)+k3./TMP); 
  ZWD=trapz(-PRS,ZWD0);
%
  ZDD=k1*Rd/g*(PRS(1));
  ZDD=ZDD*1E-6;
  ZWD=ZWD*1E-6;
%
  Tm=0.673*TMP(1)+83.0;
  C=1E6*mw/(k2-k1*eps0+k3/Tm)/RS;
  PW=ZWD*C*100;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  t=TMP-T0;
% rho =  densità vap. kg/m^3
% e=RH/100*6.1121*exp(17.62*t./(243.12+t));
% rho=  1E-3*216.7*100.*e./TMP
  rho = 1E-3*216.7*(RH/100.0*6.112.*exp(17.62*t./(243.12+t))./TMP);
  IWV=trapz(HGT,rho);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ZDDS=0.002277*PRS(1);
  e0=e(1); %exp(1.81+17.27*DPT(1)/(DPT(1)+237.5));
  ZWDS=0.002277*(0.005+1255/TMP(1))*e0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AD = air density [kg/m3]
% AD=100*PRS./(Rd+TMP).*(1.0-0.378*e./(100*PRS));
  AD=100*PRS./(Rd*TMP);
% LWC [kg/m3]
  LWC=AD.*CLW;
% keyboard;
% LW [mm]<=>[kg/m2]
  LW=trapz(HGT,LWC);
% LW=100/9.81*trapz(-PRS,CLW);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

