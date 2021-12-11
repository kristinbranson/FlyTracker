function handles = fix_SwapEvents(handles,fly1,fly2,f0,f1)
% swap fly1 for fly2 in all suspicous sequences involving only one of them
% from frames f0 to f1
% splintered from fixerrorsgui 6/21/12 JAB

for i = 1:length(handles.seqs)
  if min(handles.seqs(i).frames) < f0 || max(handles.seqs(i).frames) > f1,
    continue;
  end
  if ismember(fly1,handles.seqs(i).flies) && ~ismember(fly2,handles.seqs(i).flies)
    handles.seqs(i).flies = union(setdiff(handles.seqs(i).flies,fly1),fly2);
  end
  if ismember(fly2,handles.seqs(i).flies) && ~ismember(fly1,handles.seqs(i).flies)
    handles.seqs(i).flies = union(setdiff(handles.seqs(i).flies,fly2),fly1);
  end
end
