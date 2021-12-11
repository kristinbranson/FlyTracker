function handles = SelectFly(handles,fly)
% change the selected fly to a specified one
% splintered from fixerrorsgui 6/23/12 JAB

if ismember(fly,handles.selected),
  % set the current fly as unselected
  fix_SetFlySelected(handles,fly,false);
  i = find(handles.selected==fly,1);
  handles.selected(i) = [];
else
  % set the current fly as selected
  fix_SetFlySelected(handles,fly,true);
  % unselect another fly if necessary
  if length(handles.selected) == handles.nselect,
    unselect = handles.selected(end);
    if ~isempty(unselect),
      fix_SetFlySelected(handles,unselect,false);
    end
  end
  % store selected
  handles.selected = [fly,handles.selected];
end
%handles.selected = handles.selected(handles.selected > 0);
