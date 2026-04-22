% calcola la Tm con tre metodi
% Tmr --> Tm radiativa
% Tm1 --> Tm (rvap)
% Tm2 --> Tm empirica
function [Tmr,Tm1,Tm2,Tg]=Tmean(mdata,f)
 Tmr=Tm1=Tm2=Tg=[];
 nepoch=mdata.nh;

 for epoch=1:nepoch
  if(mdata.isok)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   TMP=mdata.tmp(:,epoch);
%  DPT=mdata.dpt(:,epoch);
   PRS=mdata.prs(:,epoch);
   HGT=mdata.hgt(:,epoch);
   RH=mdata.rh(:,epoch);
   CLW=mdata.clwmr(:,epoch);
%
%  rvap =  densità vap. g/m^3
   t=TMP-273.15;
   Tg=[Tg ; TMP(1)];
   rvap = 216.7*(RH/100.0*6.112.*exp(17.62*t./(243.12+t))./(273.15+t));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  AD = air density [kg/m3]
   Rd=287.05;
   AD=100*PRS./(Rd*TMP);
   LWC=AD.*CLW;  %[kg/m3]
   LWC=1E3*LWC;  %[g/m3]  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   Ka=Ka_freq2(f,rvap,PRS,TMP,LWC);
   tau=[];
   for i=1:length(HGT)
    tau(i)=trapz(HGT(1:i)*1E-3,Ka(1:i));
   end
%  printf('%d %d %d %d %d %d %d\n',length(TMP),length(HGT),length(DPT),length(RH),length(PRS),length(CLW),length(Ka));   
%  printf('%f %f\n',HGT(1),HGT(length(HGT)));   
   I1=trapz(HGT*1E-3,Ka.*TMP.*exp(-tau'));
   I2=trapz(HGT*1E-3,Ka.*exp(-tau'));
   Tmr=[Tmr ; I1/I2];  
%    printf('Tmr(%3.2f)=%3.2f\t',f,Tmr);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   n1=trapz(HGT,rvap);
   n2=trapz(HGT,rvap./TMP);
   Tm1=[Tm1 ; n1/n2];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   Tm2=[Tm2 ; 0.683*TMP(1)+77.919];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  else
   Tmr=[Tmr ; 0];  
   Tm1=[Tm1 ; 0];
   Tm2=[Tm2 ; 0];
  end 
%    printf('Tm1=%3.2f\tTm2=%3.2f\n',Tm1,Tm2);
 end
end
