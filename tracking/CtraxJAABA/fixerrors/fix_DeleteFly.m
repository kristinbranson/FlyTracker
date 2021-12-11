function handles = fix_DeleteFly(handles,fly)
% find birth and death event for this fly, if it exists
% splintered from fixerrorsgui 6/21/12 JAB

handles = fix_RemoveBirthEvent(handles,fly);
handles = fix_RemoveDeathEvent(handles,fly);

fns = fieldnames(handles.trx(fly));
for i = 1:length(fns),
  fn = fns{i};
  handles.trx(fly).(fn) = nan;
end
del_fields = {'hellipse', 'hcenter', 'hhead', 'htail', ...
   'hleft', 'hright', 'htailmarker', 'hpath'};
for fi = 1:length( del_fields )
   eval( sprintf( 'delete( handles.%s(fly) );', del_fields{fi} ) )
end
