function handles = UpdateFlyPathVisible(handles)
% makes fly path visible or invisible
% splintered from fixerrorsgui 6/21/12 JAB

%%%% this code should probably be merged into fix_FixUpdateFly, since they're *almost*
%%%% always called together and contain some duplicated logic
% example glitch caused by this incomplete duplication:
% 1. choose plot path "seq flies"
% 2. uncheck "show dead tracks"
% 3. scroll frame
% 4. choose plot path "all flies"
% 5. scroll frame
% see flies change visiblity on scroll, because visibility logic is inconsistent here

hObject = handles.plotpathmenu;
contents = get(hObject,'String');
s = contents{get(hObject,'Value')};
handles.plotpath = s;

for fly = 1:handles.nflies,
  if isdummytrk(handles.trx(fly))
    if ishandle(handles.hpath(fly)) && handles.hpath(fly) > 0,
      delete(handles.hpath(fly));
    end
    continue;
  end
  if strcmpi(handles.plotpath,'all flies') || ...
      (strcmpi(handles.plotpath,'seq flies') && ismember(fly, handles.seq.flies)),
     try
        set(handles.hpath(fly),'visible','on'); % < r2014b
     catch
        set( handles.hpath(fly), 'handlevisibility', 'on' ) % >= r2014b
     end
  else
     try
        set(handles.hpath(fly),'visible','off'); % < r2014b
     catch
        set( handles.hpath(fly), 'handlevisibility', 'off' ) % >= r2014b
     end
  end
end
