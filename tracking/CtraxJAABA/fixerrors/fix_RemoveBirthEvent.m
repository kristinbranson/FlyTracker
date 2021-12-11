function handles = fix_RemoveBirthEvent(handles,fly)
% removes a birth event for a fly
% splintered from fixerrorsgui 6/21/12 JAB (as a no-op)

%if handles.trx(fly).firstframe > 1,
%  for i = 1:length(handles.seqs)
%    if strcmpi(handles.seqs(i).type,'birth'),
%      if fly ~= handles.seqs(i).flies,
%        continue;
%      end
%      if isempty(handles.doneseqs),
%        handles.doneseqs = handles.seqs(i);
%      else
%        handles.doneseqs(end+1) = handles.seqs(i);
%      end
%      handles.seqs(i).type = 'dummy';
%    end
%  end
%end
