function [DPT,TMP,RH,pname1,pname2]=dptplot(mdata)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%nep=73;
 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 DPT=[];
 TMP=[];
 RH=[];
 ILW=zeros(nep,1);
 for epoch=1:nep
    RH=[RH;mdata.rh(1,epoch)];
    TMP=[TMP;mdata.tmp(1,epoch)];
    DPT=[DPT;mdata.dpt(1,epoch)];
 end
 TMP=TMP-273.15;
 DPT=DPT-273.15;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 time0=0:nep-1;
 plot(time0,DPT,"linewidth",1,"markersize",9,'r;DPT [°C];',time0,TMP,"linewidth",1,"markersize",9,'b;TMP [°C];');
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
 ylabel("dew point [°C]");
 grid on;
 set(gca, 'GridColor', [gcol, gcol, gcol]);
 set (gca, "yminorgrid", "on");
 set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
 date=strrep(mdata.date,'-','/');
 date=strrep(date,'_',' ');
 title(date);
%pname1=sprintf("dpt_%s.png",mdata.date);
 pname1="dpt.png";
 print(pname1,"-dpng","-S640,480");
% copyfile(pname1,'dpt.png');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 time0=0:nep-1;
 plot(time0,RH,"linewidth",1,"markersize",9,'r;RH [%];');
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
 ylabel("RH [%]");
 grid on;
 set(gca, 'GridColor', [gcol, gcol, gcol]);
 set (gca, "yminorgrid", "on");
 set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
 date=strrep(mdata.date,'-','/');
 date=strrep(date,'_',' ');
 title(date);
%pname2=sprintf("rh_%s.png",mdata.date);
 pname2="rh.png";
 print(pname2,"-dpng","-S640,480");
%copyfile(pname2,'rh.png');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end
