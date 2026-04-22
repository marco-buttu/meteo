function [tau,pname1]=tauplot(mdata,fre,plot_flag)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%nep=73;
 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 for epoch=1:nep
   TMP=mdata.tmp(:,epoch);
   DPT=mdata.dpt(:,epoch);
   PRS=mdata.prs(:,epoch);
   HGT=mdata.hgt(:,epoch);
   CLW=mdata.clwmr(:,epoch);
   RH=mdata.rh(:,epoch);
   t=TMP-273.15;
   HGT/=1000;
%  rvap =  densità vap. g/m^3
   rvap = 216.7*(RH/100.0*6.112.*exp(17.62*t./(243.12+t))./(273.15+t));
%  AD = air density [kg/m3]
   Rd=287.05;
   AD=100*PRS./(Rd*TMP);
   LWC=AD.*CLW;  %[kg/m3]
   LWC=1E3*LWC;  %[g/m3]  
   Ka=Ka_freq2(fre,rvap,PRS,TMP,LWC);
   tau(epoch)=trapz(HGT,Ka);
 end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 if(plot_flag) 
  time0=0:nep-1;
  plot(time0,tau,"linewidth",1,"markersize",9,"-r;tau [Neper];")
  set(gca, "fontsize", fsize);
  axis([0,nep-1]);
  switch(st)
   case(1)
    ep=['00';' ';' ';' ';' ';' ';'06';' ';' ';' ';' ';' ';'12';' ';' '; ...
       ' ';' ';' ';'18';' ';' ';' ';' ';' '];
   case(3)
    ep= ep=['00';'03';'06';'09';'12';'15';'18';'21';'00';'03';'06';'09';'12';'15';'18';'21';'00'];
  end
  xtick=time0;
  set(gca,'xtick',xtick);
  xticklabel=ep;
  set(gca,'xticklabel',xticklabel);
  xlabel("forecast time [UT]");
  lb=sprintf("tau %6.2f GHz",fre);
  ylabel(lb);
  grid on;
  set(gca, 'GridColor', [gcol, gcol, gcol]);
  set (gca, "yminorgrid", "on");
  set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
  date=strrep(mdata.date,'-','/');
  date=strrep(date,'_',' ');
  title(date);
% pname2=sprintf("tau%d_%s.png",fre*1000,mdata.date);
  pname1=sprintf("tau%d.png",fre*1000);
  print(pname1,"-dpng","-S640,480");
% copyfile(pname2,pname1);
 end
end


