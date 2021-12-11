% this is a script so that the scope is global
% please set the following variables:
% tags,matnames,movienames,annnames,fixedmatnames
% optional:
% DISPLAYAREAS

required = {'tags','matnames','movienames','annnames','fixedmatnames'};
optional = {'DISPLAYAREAS'};
default = {false};

for i = 1:length(required),
  if ~exist(required{i},'var'),
    error('Required input: %s',required{i});
  end
end

for i = 1:length(optional),
  if ~exist(optional{i},'var'),
    eval(sprintf('%s = default{i};',optional{i}));
  end
end

nmovies = length(tags);
isdone = false(1,nmovies);
for i = 1:length(tags),
  if exist(fixedmatnames{i},'file')
    isdone(i) = true;
  end
end

alltrx = {};
for tagi = find(~isdone),

  tag = tags{tagi};
  annname = annnames{tagi};
  matname = matnames{tagi};
  savename = fixedmatnames{tagi};
  moviename = movienames{tagi};
  loadname = sprintf('tmpfixed_movie%s.mat',tag);

  fprintf('Fixing movie %s\n',moviename);

  if ~exist(loadname,'file')
    [seqs,trx0,params] = suspicious_sequences(matname,annname,'minwalkvel',.5);
    trx = fixerrorsgui(seqs,moviename,trx0,annname,params,loadname);
  else
    load(loadname);
    trx0 = trx;
    trx = fixerrorsgui(seqs,moviename,trx0,annname,params,loadname);
  end

  alltrx{tagi} = trx; %#ok<AGROW>
  v = questdlg('Are you done fixing tracks? Click Yes to save to file.','Save fixed tracks?','Yes','No','Yes');
  if strcmpi(v,'yes')
    trx = rmfield(trx,{'xpred','ypred','thetapred','dx','dy','v','f2i'});
    save(savename,'trx');
  else
    trx = rmfield(trx,{'xpred','ypred','thetapred','dx','dy','v','f2i'});
    tmpsavename = sprintf('backupfixed_movie%s.mat',tag);
    save(tmpsavename,'trx');
    fprintf('saving trx to file %s\n',tmpsavename);
    keyboard;
  end
  
  if DISPLAYAREAS,
    ncrop = 1000;
    clf;
    hold on;
    colors = jet(length(trx));
    areas = zeros(1,length(trx));
    for fly = 1:length(trx),
    a = trx(fly).a.*trx(fly).b;
    if trx(fly).nframes <= ncrop*2,
      continue;
    end
    ac = cumsum(a(ncrop:end-ncrop+1));
    mu1 = ac(1:end-1) ./ (1:length(ac)-1);
    mu2 = (ac(end)-ac(1:end-1)) ./ (length(ac)-1:-1:1);
    [maxdiff,split] = max(abs(mu2-mu1));
    plot([trx(fly).firstframe+ncrop,trx(fly).firstframe+ncrop-1+split,trx(fly).firstframe+ncrop-1+split,trx(fly).endframe-ncrop+1],...
      [mu1(split),mu1(split),mu2(split),mu2(split)],'.-','color',colors(fly,:));
    areas(fly) = mean(trx(fly).a.*trx(fly).b);
    end
    questdlg('Go on to next movie?', ...
      'Next?', 'Yes', 'Yes');
  end
end
