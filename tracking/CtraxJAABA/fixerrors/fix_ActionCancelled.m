function fix_ActionCancelled( hObject, handles, panel_to_deselect )
% cancel a fix-action and return GUI to neutral state
% JAB 6/23/12

for fly = handles.selected,
  if fly > 0,
    fix_SetFlySelected(handles,fly,false);
  end
end
handles.nselect = 0;
handles.selected = [];
set(panel_to_deselect,'visible','off');
fix_EnablePanel(handles.editpanel,'on');

guidata(hObject,handles);
