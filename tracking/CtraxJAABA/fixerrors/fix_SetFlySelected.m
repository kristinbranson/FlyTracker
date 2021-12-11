function fix_SetFlySelected(handles,fly,v)
% set the selected state for a fly
% splintered from fixerrorsgui 6/23/12 JAB

if fly <= 0,
  return;
end
if v,
  set(handles.hellipse(fly),'color',handles.colors(fly,:)*.5+.5,'linewidth',3);
  set(handles.hcenter(fly),'visible','off');
  set(handles.hleft(fly),'visible','off');
  set(handles.hright(fly),'visible','off');
  set(handles.hhead(fly),'visible','off');
  set(handles.htail(fly),'visible','off');
  set(handles.hpath(fly),'linewidth',2);
else
  set(handles.hellipse(fly),'color',handles.colors(fly,:),'linewidth',2);
  set(handles.hcenter(fly),'visible','on');
  set(handles.hleft(fly),'visible','on');
  set(handles.hright(fly),'visible','on');
  set(handles.hhead(fly),'visible','on');
  set(handles.htail(fly),'visible','on');
  set(handles.hpath(fly),'linewidth',1);
end
