function j = mjd(year, month, day, hour, minute, second)
   
 a = floor((14 - month)/12);
 y = year + 4800 - a;
 m = month + 12*a - 3;
   
 j = day + floor((153*m + 2)/5) + y*365 + floor(y/4) - floor(y/100) + floor(y/400) - 32045 + ( second + 60*minute + 3600*(hour - 12) )/86400;
   
 j=j-2400000.5;
 
end