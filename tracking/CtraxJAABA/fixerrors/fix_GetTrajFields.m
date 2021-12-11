function trajfns = fix_GetTrajFields(trx)

nflies = numel(trx);
fns = fieldnames(trx);
nottrajfns = {'timestamps','x_mm','y_mm','theta_mm','a_mm','b_mm','xpred','ypred','thetapred','dx','dy','v','wing_lengthl_mm','wing_lengthr_mm'};
istrajfn = false(1,numel(fns));
idxreal = false(1,nflies);
for fly = 1:nflies,
  idxreal(fly) = ~isdummytrk(trx(fly));
end
if ~any(idxreal),
  trajfns = {'x','y','theta','a','b'};
  return;
end
trx = trx(idxreal);
nflies = numel(trx);
for i = 1:numel(fns),
  fn = fns{i};
  if ismember(fn,nottrajfns),
    continue;
  end
  % string
  if ischar(trx(1).(fn)),
    continue;
  end
  % scalars 
  if max(cellfun(@numel,{trx.(fn)})) == 1,
    continue;
  end
  
  % figure out which dimension corresponds to frames, if any
  sz1 = cellfun(@size,{trx.(fn)},'Uni',0);
  nd = max(cellfun(@numel,sz1));
  sz = nan(nflies,nd);
  for j = 1:nflies,
    sz(j,1:numel(sz1{j})) = sz1{j};
  end
  offnframes = cat(1,trx.nframes)-sz;
  % only one dimension that matches number of frames
  idx = find(all(offnframes==0,1));
  if numel(idx) ~= 1,
    % offsets between 0 and 3 allowed as long as they match for all flies
    idx = find(offnframes(1,:)>=0 & offnframes(1,:) <= 3 & all(offnframes==offnframes(1,:),1));
    if numel(idx) ~= 1,
      continue;
    end
  end
  istrajfn(i) = true;

end

trajfns = fns(istrajfn);
