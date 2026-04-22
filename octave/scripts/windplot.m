function [ang,mod0,pname1,pname2]=windplot(mdata)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%nep=73;
 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 u=v=[];
 for epoch=1:nep
  u=[u; mdata.uwind(1,epoch)];
  v=[v; mdata.vwind(1,epoch)];  
 end
 ang=rem(270-atan2(v,u)*180/pi,360);
 mod0=3.6*sqrt(u.^2+v.^2);  % km/h

 %%%% VEL %%%%
 time0=0:nep-1;
 plot(time0,mod0,"linewidth",1,"markersize",9,"-;WS;");
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
 ylabel("wind speed (km/h)");
 xlabel("forecast time (h)");
 grid on;
 set(gca, 'GridColor', [gcol, gcol, gcol]);
 set (gca, "yminorgrid", "on");
 set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
 date=strrep(mdata.date,'-','/');
 date=strrep(date,'_',' ');
 title(date);
%pname1=sprintf("ws_%s.png",mdata.date);
 pname1="ws.png";
 print(pname1,"-dpng","-S640,480");
%copyfile(pname1,'wind_s.png');

 %%%% DIR %%%%
% pause(2);
 time0=0:nep-1;
 plot(time0,ang,"linewidth",1,"markersize",6,"-*;WD;")
 set(gca, "fontsize", fsize);
 axis([0,nep-1,0,360]);
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
%
 ytick=0:45:360;
 set(gca,'ytick',ytick);
 yticklabel=['N';'NE';"E";"SE";"S";"SW";"W";"NW";"N"];
 set(gca,'yticklabel',yticklabel);
%
%ylabel("wind dir (deg)");
 ylabel("wind dir");
 xlabel("forecast time (h)");
 grid on;
 set(gca, 'GridColor', [gcol, gcol, gcol]);
 set (gca, "yminorgrid", "on");
 set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
 date=strrep(mdata.date,'-','/');
 date=strrep(date,'_',' ');
 title(date);
%pname2=sprintf("wd_%s.png",mdata.date);
 pname2="wd.png";
 print(pname2,"-dpng","-S640,480");
%copyfile(pname2,'wind_d.png');

end

