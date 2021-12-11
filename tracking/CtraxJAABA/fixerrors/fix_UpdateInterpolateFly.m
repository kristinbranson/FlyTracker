function UpdateInterpolateFly(handles)
% update a fly's position during interpolation
% splintered from fixerrorsgui 6/23/12 JAB

fly = handles.interpolatefly;
i = handles.trx(fly).off+(handles.interpolatefirstframe);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
ellipseupdate(handles.hinterpolate(fly),a,b,x,y,theta);
