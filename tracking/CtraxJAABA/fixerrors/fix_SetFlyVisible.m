function SetFlyVisible(handles,fly,v)
% makes fly body visible or invisible
% splintered from fixerrorsgui 6/21/12 JAB

if isdummytrk(handles.trx(fly))
  return;
end

set(handles.hellipse(fly),'visible',v);
set(handles.hcenter(fly),'visible',v);
set(handles.hleft(fly),'visible',v);
set(handles.hright(fly),'visible',v);
set(handles.hhead(fly),'visible',v);
set(handles.htail(fly),'visible',v);
set(handles.htailmarker(fly),'visible',v);
set(handles.hpath(fly),'visible',v);
