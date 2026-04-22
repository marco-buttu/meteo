clear all;
%tic;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
c0=1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
param;
f=strftime ("%Y%m%d00.dat",gmtime(time()));
param;
f=[mfile_a,f];

load(f);

tau0=[];

for fre=1:116

   tau=tauplot(mdata,fre,false);
   tau0=[tau0 ; tau];

end

tau0=tau0*c0;

epoch=mdata.date;

tauf=[plot2d_path,'tau0.dat'];

%save tau0.dat tau0 epoch
save('-text',tauf, 'tau0', 'epoch');

%toc;
