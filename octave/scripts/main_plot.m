%%%%%%%%%%%%#! /bin/octave -qf
clear all;
param;
arglist= argv ();
%printf('%d\n',nargin);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%if(nargin==1)
% t0=localtime(time());
% date=strftime("%Y%m%d",t0);
% issue=arglist{1};
%else
% date=arglist{1};
% issue=arglist{2};
%end

date=arglist{1}(1:end-2);
issue=arglist{1}(end-1:end);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%fname=[mdata_path,date,issue,'.dat'];

dataplot(date,mfile_a,issue,arch_path,www_path);

close all;
