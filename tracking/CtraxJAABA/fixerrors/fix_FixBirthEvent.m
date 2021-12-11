function handles = fix_FixBirthEvent(handles,fly)
% add or remove fly's birth event from suspicious sequences list, as appropriate
% splintered from fixerrorsgui 6/21/12 JAB

f = handles.trx(fly).firstframe;
if f == 1,
  handles = fix_RemoveBirthEvent(handles,fly);
else
  for i = 1:length(handles.seqs)
    if ~strcmpi(handles.seqs(i).type,'birth'),
      continue;
    end
    if fly ~= handles.seqs(i).flies,
      continue;
    end
    handles.seqs(i).frames = f;
  end
end
