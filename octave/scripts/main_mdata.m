clear all;

param;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flip_data=false;
T0=273.15;
nl=44;  % n. of lev.      (row)
nh=73;  % n. of forecasts (col)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mdata.isok=1;
mdata.nl=nl;
mdata.nh=nh;
mdata.step=1;
mdata.model='WRF(GFS) V4.2';
mdata.version=2;
mdata.site='SRT';

%%%%%%%%%% pres [hPa] %%%%%%%%%%
fn1='MoSarT_PB.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
fn1='MoSarT_P.nc';
fn2='data.txt';
[data2,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
mdata.prs=(data1+data2)/100;

%%%%%%%%%% temp [K] %%%%%%%%%% 
fn1='MoSarT_T.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
data1=data1+300;   % Theta
mdata.tmp=CalTemp(mdata.prs*100,data1);

%%%%%%%%%% hgt [m] %%%%%%%%%%
fn1='MoSarT_PH.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl+1,nh,cutpath);
fn1='MoSarT_PHB.nc';
fn2='data.txt';
[data2,simdate]=read_nc(fn1,fn2,nl+1,nh,cutpath);
%data1=data1(1:nl,:);
%data2=data2(1:nl,:);
%
data1=(data1(1:nl,:)+data1(2:nl+1,:))/2;
data2=(data2(1:nl,:)+data2(2:nl+1,:))/2;
%
mdata.hgt=(data1+data2)/9.81;

%%%%%%%%%% RH [%] %%%%%%%%%%
fn1='MoSarT_QVAPOR.nc'; % water vapor mixing ratio
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
mdata.rh=CalRH(mdata.tmp,data1,mdata.prs*100,2);

%%%%%%%%%% dew point [K] %%%%%%%%%%
mdata.dpt=CalDP(mdata.tmp-T0,mdata.rh)+T0;

%%%%%%%%%% U [m s-1] %%%%%%%%%%
fn1='MoSarT_U.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
mdata.uwind=data1;

%%%%%%%%%% V [m s-1] %%%%%%%%%%
fn1='MoSarT_V.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
mdata.vwind=data1;

%%%%%%%%%% cloud mixing ratio [kg kg-1] %%%%%%%%%%
fn1='MoSarT_QCLOUD.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,nl,nh,cutpath);
mdata.clwmr=data1.*(data1>=0);

%%%%%%%%%% cum rain [mm] %%%%%%%%%%
fn1='MoSarT_RAIN.nc';
fn2='data.txt';
[data1,simdate]=read_nc(fn1,fn2,1,nh,cutpath);
mdata.crain=data1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mdata.date=simdate;
%printf('%s\n',simdate);
%simdate=[simdate(1:4),simdate(6:7),simdate(9:10)];
simdate=[simdate(1:4),simdate(6:7),simdate(9:10),simdate(12:13)];
%printf('%s\n',simdate);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(flip_data)
 mdata.prs=flipud(mdata.prs);
 mdata.tmp=flipud(mdata.tmp);
 mdata.hgt=flipud(mdata.hgt);
 mdata.rh=flipud(mdata.rh);
 mdata.dpt=flipud(mdata.dpt);
 mdata.uwind=flipud(mdata.uwind);
 mdata.vwind=flipud(mdata.vwind);
 mdata.clwmr=flipud(mdata.clwmr);
end

%t=5;plot(mdata.prs(:,t),mdata.hgt(:,t),'o');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%mdata_f=[simdate,'.dat'];
%save(mdata_f,'mdata');
%e0=sprintf("save -binary /home/franco/wrf/data/mdata/%s.dat mdata", simdate);  
e0=sprintf("save -binary %s%s.dat mdata", mfile_a,simdate);  
eval(e0);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


