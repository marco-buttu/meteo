function [data,simdate]=read_nc(fn1,fn2,nl,nh,cutpath)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fn1='MoSarT_T.nc';
% fn2='T.txt';
% nl=44;  % n. of lev.      (row)
% nh=73;  % n. of forecasts (col)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%cmd=['ncdump -fc /home/franco/wrf/data/cuts/',fn1,' > ',fn2];
 cmd=['/bin/ncdump -fc ',cutpath,fn1,' > ',fn2];
 system(cmd);
 fid=fopen(fn2,'r');
 data=zeros(nl,nh);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read SIMULATION_START_DATE
 while (true)
   a=fgetl(fid);
   if(length(a)>10)
    [v1,v2,v3]=sscanf(a,'%s%s%s','C');
    if (strcmp(v1,':SIMULATION_START_DATE'))
     break;
    end
   end
 end
 simdate=v3(2:end-1);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% skip some lines
 while (true)
  if (strcmp(fgetl(fid),'data:'))
   break;
  end
 end
 fgetl(fid);
 fgetl(fid);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 for j=1:nh
  for i=1:nl
    a=fgetl(fid);
    [v1,v2,v3,v4]=sscanf(a,'%f%s%s%s','C');
    data(i,j)=v1;
  end
 end
 fclose(fid);
end


