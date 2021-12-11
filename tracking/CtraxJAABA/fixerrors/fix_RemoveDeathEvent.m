function handles = fix_RemoveDeathEvent(handles,fly)
% removes a death event for a fly
% splintered from fixerrorsgui 6/21/12 JAB

for i = 1:length(handles.seqs)
  if strcmpi(handles.seqs(i).type,'death'),
    if fly ~= handles.seqs(i).flies,
      continue;
    end
    if isempty(handles.doneseqs),
      handles.doneseqs = handles.seqs(i);
    else
      handles.doneseqs(end+1) = handles.seqs(i);
    end
    handles.seqs(i).type = ['dummy', handles.seqs(i).type];
  end
end  
