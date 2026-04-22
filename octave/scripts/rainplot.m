function [rain,pname1]=rainplot(mdata,plot_flag)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%nep=73;
 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 rain=mdata.crain;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 if(plot_flag) 
  time0=0:nep-1;
  plot(time0,rain,"linewidth",1,"markersize",9,"-r;rain [mm];")
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
  lb=sprintf("Cumulative Rain Fall [mm]");
  ylabel(lb);
  grid on;
  set(gca, 'GridColor', [gcol, gcol, gcol]);
  set (gca, "yminorgrid", "on");
  set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
  date=strrep(mdata.date,'-','/');
  date=strrep(date,'_',' ');
  title(date);
  pname1=sprintf("rain.png");
  print(pname1,"-dpng","-S640,480");
 end
end


