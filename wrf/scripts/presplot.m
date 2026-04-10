function [prs,pname1]=presplot(mdata,plot_flag)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%nep=73;
 nep=mdata.nh;
 st=mdata.step;
 fsize=12 ;% plot font size
 gcol=0.9; % grid color

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 prs=[];
 for epoch=1:nep
    prs=[prs;mdata.prs(1,epoch)];
 end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 if(plot_flag) 
  time0=0:nep-1;
  plot(time0,prs,"linewidth",1,"markersize",9,"-r;prs [hPa];")
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
  lb=sprintf("Pressure [hPa]");
  ylabel(lb);
  grid on;
  set(gca, 'GridColor', [gcol, gcol, gcol]);
  set (gca, "yminorgrid", "on");
  set(gca, 'MinorGridColor', [gcol, gcol, gcol]);
  date=strrep(mdata.date,'-','/');
  date=strrep(date,'_',' ');
  title(date);
% pname2=sprintf("tau%d_%s.png",fre*1000,mdata.date);
  pname1=sprintf("prs.png");
  print(pname1,"-dpng","-S640,480");
% copyfile(pname2,pname1);
 end
end


