function [handles, seqs_removed] = RemoveFlyEvent(handles,fly,f0,f1)
% remove all suspicious sequences involving fly in frames f0 to f1
% splintered from fixerrorsgui 6/23/12 JAB

seqs_removed = [];
for i = 1:length(handles.seqs)
  if ismember(fly,handles.seqs(i).flies) && f0 <= min(handles.seqs(i).frames) && ...
      f1 >= max(handles.seqs(i).frames)
    handles.seqs(i).type = ['dummy', handles.seqs(i).type];
    seqs_removed(end+1) = i;
  end
end
