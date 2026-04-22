function dataplot(date,mdata_path,issue,arch_path,www_path)

 fname=[mdata_path,date,issue,'.dat'];
 if(exist(fname))
  load(fname);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  [ang,mod0,pname1,pname2]=windplot(mdata);
  fname1=[arch_path,pname1(1:end-4),'_',date,issue,'.png'];
  fname2=[arch_path,pname2(1:end-4),'_',date,issue,'.png'];
 %pause(1);
  copyfile(pname1,fname1);
  movefile(pname1,www_path,'f');
  copyfile(pname2,fname2);
  movefile(pname2,www_path,'f');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  [IWV,ILW,ZDD,ZWD,pname3]=iwvplot(mdata,true);
% pause(1);
  fname3=[arch_path,pname3(1:end-4),'_',date,issue,'.png'];
  copyfile(pname3,fname3);
  movefile(pname3,www_path,'f');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  [DPT,TMP,RH,pname4,pname5]=dptplot(mdata);
% pause(1);
  fname4=[arch_path,pname4(1:end-4),'_',date,issue,'.png'];
  fname5=[arch_path,pname5(1:end-4),'_',date,issue,'.png'];
  copyfile(pname4,fname4);
  movefile(pname4,www_path,'f');
  copyfile(pname5,fname5);
  movefile(pname5,www_path,'f');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  [prs,pname7]=presplot(mdata,true);
% pause(1);
  fname7=[arch_path,pname7(1:end-4),'_',date,issue,'.png'];
  copyfile(pname7,fname7);
  movefile(pname7,www_path,'f');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  [rain,pname8]=rainplot(mdata,true);
% pause(1);
  fname8=[arch_path,pname8(1:end-4),'_',date,issue,'.png'];
  copyfile(pname8,fname8);
  movefile(pname8,www_path,'f');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  freq=[22.23,70,75,93,100,116];
  n=length(freq);
  for i=1:n
   [tau,pname6]=tauplot(mdata,freq(i),true);
   fname6=[arch_path,pname6(1:end-4),'_',date,issue,'.png'];
   copyfile(pname6,fname6);
%  cmd=['cp ',pname6,' ',fname6];
%  system(cmd);
   movefile(pname6,www_path,'f');
%  pause(2);
  end
  printf('plot creati: %s %s\n',date,issue);
 else
  printf('file mdata non trovato: %s\n',date);
 end


end

