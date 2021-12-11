function [xlim,ylim] = match_aspect_ratio(xlim,ylim,handles)
% zoom in on a set of limits as much as possible without changing aspect ratio
% splintered from fixerrorsgui 6/21/12 JAB

aspectratiocurr = diff(xlim)/diff(ylim);
if aspectratiocurr < handles.mainaxesaspectratio,
  % make x limits bigger to match
  xmu = mean(xlim);
  dx = diff(ylim)*handles.mainaxesaspectratio;
  xlim = xmu+[-dx/2,dx/2];
else
  % make y limits bigger to match
  ymu = mean(ylim);
  dy = diff(xlim)/handles.mainaxesaspectratio;
  ylim = ymu+[-dy/2,dy/2];
end
