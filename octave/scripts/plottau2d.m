close all;
clear all;
param;
%graphics_toolkit ("fltk");
tauf=[plot2d_path,'tau0.dat'];
load('-text',tauf);

[nf, ne]=size(tau0);

tau0(52:68,:)=NaN;

i0=find(tau0>1);
tau0(i0)=1;
pcolor(log10(tau0));
% pcolor(tau0);

shading('flat');
c=colorbar("SouthOutside");
set(gca,'ColorScale','log')
%colorbar;
colormap('jet');

a=[];
j=0;
for i=1:ne
%d=strftime ("%m/%d\n%a",gmtime(time()+j*86400));
 d=strftime ("%m/%d\n%a",localtime(time()+j*86400));
%a={a {d,'','','','','','',''}};
%a={a {d,'','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''}};
 a={a {d,'','','','','','','','','','','','','','','','','','','','','',''}};
 j++;
end
set(gca (), "xtick", 1:ne-1, "xticklabel", a);

tit=['SRT log(tau) ',epoch(1:10)];
title(tit);
xlabel('Date [UT]');
ylabel('Frequency [GHz]');

h=get(gcf, "currentaxes");
set(h, "fontsize", 6, "linewidth", 1);

%e0=sprintf("print -dpng -nosvgconvert '-S1400,600' tau2d_%s.png",epoch(1:10));
e0=sprintf("print -dpng -nosvgconvert '-S1400,600' %stau2d_%s.png",plot2d_path,epoch(1:10));
eval(e0);


