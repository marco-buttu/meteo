function [IWV,ILW,ZDD,ZWD,pname]=iwvplot(mdata,flag)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 IWV=zeros(nep,1);
 ILW=zeros(nep,1);
 ZWD=zeros(nep,1);
 ZDD=zeros(nep,1);
 for epoch=1:nep
    TMP=mdata.tmp(:,epoch);
    DPT=mdata.dpt(:,epoch);
    PRS=mdata.prs(:,epoch);
    HGT=mdata.hgt(:,epoch);
    CLW=mdata.clwmr(:,epoch);
    RH=mdata.rh(:,epoch);
    [Tm,ZDD0,ZWD0,ZDDS,ZWDS,PW,LW,IWV0]=pwl5(TMP,DPT,PRS,HGT,CLW,RH);    
    IWV(epoch)=IWV0; %PW;
    ILW(epoch)=LW;
    ZWD(epoch)=ZWD0;
    ZDD(epoch)=ZDD0;
 end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 if(flag)
  time0=0:nep-1;
%
% graphics_toolkit gnuplot;
% figure ("visible", "off");
  plot(time0,IWV/10,"linewidth",1,"markersize",9,'-r;IWV [cm];',time0,ILW,"linewidth",1,"markersize",9,'-b;ILW [mm];');
% plot(time0,IWV,"linewidth",1,"markersize",9,'-r;IWV [mm];',time0,ILW*100,"linewidth",1,"markersize",9,'-b;ILW [mm*0.1];');
%
  set(gca, "fontsize", fsize);
  axis([0,nep-1]);
%
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
  ylabel("IWV - ILW");
  grid on;
  set(gca, 'GridColor', [gcol, gcol, gcol]);
  set (gca, "yminorgrid", "on");
  set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
  date=strrep(mdata.date,'-','/');
  date=strrep(date,'_',' ');
  title(date);
% pname=sprintf("iwv_%s.png",mdata.date);
  pname="iwv.png";
  print(pname,"-dpng","-S640,480");
% copyfile(pname,'iwv.png');
 end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end
