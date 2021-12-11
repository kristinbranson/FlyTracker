%% fix errors on exp movies
addpath /home/kristin/FLIES/docs/mtrax_methods_paper/code;
set30minmovienames;

resultdir = '/home/kristin/FLIES/data/walking_arena';
tags = [tags_female;tags_male;tags_both];
movienames = [movienames_female;movienames_male;movienames_both];
matnames = [matnames_female;matnames_male;matnames_both];
annnames = [annnames_female;annnames_male;annnames_both];
savenames = cell(size(tags));
nmovies = length(tags);
isdone = false(1,nmovies);
for i = 1:length(tags),
  savenames{i} = sprintf('%s/movie%s_fixedtrx.mat',resultdir,tags{i});
  if exist(savenames{i},'file')
    isdone(i) = true;
  end
end
movietype = cell(size(tags));
for i = 1:length(tags),
  if ismember(tags{i},tags_female),
    movietype{i} = 'F';
  elseif ismember(tags{i},tags_male),
    movietype{i} = 'M';
  else
    movietype{i} = 'B';
  end
end

%tags(done) = [];
%annnames(done) = [];
%matnames(done) = [];
%savenames(done) = [];
%movienames(done) = [];
tagi = find(~isdone,1);

%% choose a movie

tag = tags{tagi};
annname = annnames{tagi};
matname = matnames{tagi};
savename = savenames{tagi};
moviename = movienames{tagi};
loadname = sprintf('fixed_movie%s.mat',tag);

fprintf('Fixing movie %s\n',moviename);

if ~exist(loadname,'file')
  [seqs,trx0,params] = suspicious_sequences(matname,annname,'minwalkvel',.5);
  trx = fixerrorsgui(seqs,moviename,trx0,annname,params,loadname);
else
  load(loadname);
  trx0 = trx;
  trx = fixerrorsgui(seqs,moviename,trx0,annname,params,loadname);
end

v = questdlg('Are you done fixing tracks? Click Yes to save to file.','Save fixed tracks?','Yes','No','Yes');
if strcmpi(v,'yes')
  trx = rmfield(trx,{'xpred','ypred','thetapred','dx','dy','v','f2i'});
  save(savename,'trx');
end

if movietype{tagi} == 'B',
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
end

%% check
tagi = tagi + 1;
tag = tags{tagi};
annname = annnames{tagi};
matname = matnames{tagi};
savename = savenames{tagi};
moviename = movienames{tagi};
loadname = sprintf('check_fixed_movie%s.mat',tag);

load(savename);
[seqs,trx0,params] = suspicious_sequences(trx,annname,'minwalkvel',.5);
trx = fixerrorsgui(seqs,moviename,trx0,annname,params,loadname);
v = questdlg('Do you want to overwrite old tracks? Click Yes to save to file.','Save fixed tracks?','Yes','No','Yes');
if strcmpi(v,'yes')
  save(savename,'trx');
end
