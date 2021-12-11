function handles = fix_FixDeathEvent(handles,fly)
% add or remove fly's death event from suspicious sequences list, as appropriate
% splintered from fixerrorsgui 6/21/12 JAB

f = handles.trx(fly).endframe;
if f == handles.nframes,
  handles = fix_RemoveDeathEvent(handles,fly);
else
  for i = 1:length(handles.seqs)
    if ~strcmpi(handles.seqs(i).type,'death'),
      continue;
    end
    if fly ~= handles.seqs(i).flies,
      continue;
    end
    handles.seqs(i).frames = f;
  end
end  
