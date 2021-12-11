function Play(handles,hObject)
% play through a sequence
% splintered from fixerrorsgui 6/23/12 JAB

handles.isplaying = true;
set(handles.playstopbutton,'string','Stop','backgroundcolor',[.5,0,0]);
guidata(hObject,handles);
f0 = max(1,handles.seq.frames(1)-10);
f1 = min(handles.nframes,handles.seq.frames(end)+10);

for f = f0:f1,
  
  handles.f = f;
  fix_SetFrameNumber(handles);
  fix_PlotFrame(handles);
  drawnow;
  handles = guidata(hObject);

  if ~handles.isplaying,
    break;
  end
  
end

handles.f = f;

if handles.isplaying,
  handles.f = handles.seq.frames(1);
  fix_SetFrameNumber(handles);
  fix_PlotFrame(handles);  
end

handles.isplaying = false;
set(handles.playstopbutton,'string','Play','backgroundcolor',[0,.5,0]);
guidata(hObject,handles);
