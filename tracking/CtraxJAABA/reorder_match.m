function [fdata,delta] = reorder_match(f2c,cdata,ctrx,ftrx)


[fnflies,nframes] = size(f2c);

iscelldata = iscell(cdata);
if iscelldata,
  cdata_cell = cdata;
  cnflies = numel(ctrx);
  cdata = nan([cnflies,nframes]);
  delta = nan(1,cnflies);
  for cfly = 1:cnflies,
    delta(cfly) = (ctrx(cfly).endframe-ctrx(cfly).firstframe+1) - numel(cdata_cell{cfly});
    cdata(cfly,ctrx(cfly).firstframe:ctrx(cfly).firstframe+numel(cdata_cell{cfly})-1) = cdata_cell{cfly};
  end
  assert(all(delta==delta(1)));
  delta = delta(1);
end

fdata = nan([fnflies,nframes]);
for ffly = 1:fnflies,
  for t = 1:nframes,
    if f2c(ffly,t) > 0,
      fdata(ffly,t,:) = cdata(f2c(ffly,t),t,:);
    end
  end
end

if iscelldata,
  
  fdatam = fdata;
  fdata = cell(1,fnflies);
  for ffly = 1:fnflies,
    fdata{ffly} = fdatam(ffly,ftrx(ffly).firstframe:ftrx(ffly).endframe-delta);
  end
  
end