function [dewPointC]=CalDP(tempC,humidity)
  % Calculate dew point
  % Specify the constants for water vapor (b) and barometric (c) pressure.
  % NOAA constants https://en.wikipedia.org/wiki/Dew_point
  % Script expects temperature in °C and humidity in %

  b = 17.67;
  c = 243.5;

  eps0=1E-12;
  i0=find(humidity<eps0);
  humidity(i0)=eps0;

  % Calculate the intermediate value 'gamma'
  gamma = log(humidity / 100) + b * tempC ./ (c + tempC);
  % Calculate dew point in Celsius
  dewPointC = c * gamma ./ (b - gamma);

end
