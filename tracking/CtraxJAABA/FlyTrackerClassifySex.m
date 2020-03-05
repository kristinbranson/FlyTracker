function td = FlyTrackerClassifySex(trxfile,varargin)

[fracmale,dosave] = ...
  myparse(varargin,...
  'fracmale',.5,'dosave',true);

td = load(trxfile);
nflies = numel(td.trx);

nmale = round(fracmale*nflies);
nfemale = nflies - nmale;

if nmale == 0,
  for i = 1:nflies,
    td.trx(i).sex = 'F';
  end
elseif nfemale == 0,
  for i = 1:nflies,
    td.trx(i).sex = 'M';
  end
else
  area = nan(1,nflies);
  for i = 1:nflies,
    area(i) = nanmedian(td.trx(i).a.*td.trx(i).b);
  end
  [~,order] = sort(area);
  for i = 1:nmale,
    td.trx(order(i)).sex = 'M';
  end
  for i = nmale+1:nflies,
    td.trx(order(i)).sex = 'F';
  end
end

if dosave,
  save(trxfile,'-struct','td');
end