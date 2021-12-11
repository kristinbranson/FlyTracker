function handles = fix_FixUpdateFly(handles,fly)
% sets fly plot properties based on fly data
% splintered from fixerrorsgui 6/21/12 JAB

if isdummytrk(handles.trx(fly)),
  return;
end

ii = handles.trx(fly).off+(handles.f);

if strcmpi(handles.plotpath,'all flies') || ...
      (strcmpi(handles.plotpath,'seq flies') && ismember(fly, handles.seq.flies))
   if isalive(handles.trx(fly), handles.f)
      fix_SetFlyVisible(handles,fly,'on');
      i = ii;
   elseif handles.show_dead
      fix_SetFlyVisible(handles,fly,'on');
      i = 1;
   else
      fix_SetFlyVisible(handles,fly,'off');
      i = 1;
   end
else
   fix_SetFlyVisible(handles,fly,'off');
   if isalive(handles.trx(fly), handles.f)
      i = ii;
   else
      i = 1;
   end
end

x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
ellipseupdate(handles.hellipse(fly),a,b,x,y,theta);

xleft = x - b*cos(theta+pi/2);
yleft = y - b*sin(theta+pi/2);
xright = x + b*cos(theta+pi/2);
yright = y + b*sin(theta+pi/2);
xhead = x + a*cos(theta);
yhead = y + a*sin(theta);
xtail = x - a*cos(theta);
ytail = y - a*sin(theta);

set(handles.htailmarker(fly),'xdata',[xtail,x],'ydata',[ytail,y]);
set(handles.hleft(fly),'xdata',xleft,'ydata',yleft);
set(handles.hright(fly),'xdata',xright,'ydata',yright);
set(handles.hhead(fly),'xdata',xhead,'ydata',yhead);
set(handles.htail(fly),'xdata',xtail,'ydata',ytail);
set(handles.hcenter(fly),'xdata',x,'ydata',y);

i0 = ii - floor((handles.nframesplot-1)/2);
i1 = ii + handles.nframesplot - 1;
i0 = max(i0,1);
i1 = min(i1,handles.trx(fly).nframes);
set(handles.hpath(fly),'xdata',handles.trx(fly).x(i0:i1),...
  'ydata',handles.trx(fly).y(i0:i1));

handles.needssaving = 1;
guidata( handles.figure1, handles )

