%% fix errors in the 10, 20, 50 movies
tags = {'20071009_153624',
  '20071009_154355',
  '20071009_155327',
  '20071009_160257',
  '20071009_160940',
  '20071009_161603',
  '20071009_163231',
  '20071009_163846',
  '20071009_164618',
  '20071009_222528',
  '20071009_223250',
  '20071009_223914',
  '20071009_224903',
  '20071009_225452',
  '20071009_230040',
  '20071009_230808',
  '20071009_231532',
  '20071009_232142'};
stem = '/home/kristin/FLIES/data/walking_arena/movie';
movienames = cell(size(tags));
annnames = cell(size(movienames));
matnames = cell(size(movienames));
savenames = cell(size(movienames));
done = [];
for i = 1:length(tags),
  movienames{i} = sprintf('%s%s.sbfmf',stem,tags{i});
  annnames{i} = sprintf('%s.ann',movienames{i});
  if ~exist(annnames{i},'file'),
    movienames{i} = sprintf('%s%s.fmf',stem,tags{i});
    annnames{i} = sprintf('%s.ann',movienames{i});
  end
  matnames{i} = sprintf('%s%s.mat',stem,tags{i});
  savenames{i} = sprintf('%s%s_fixedtrx.mat',stem,tags{i});
  if exist(savenames{i},'file')
    done(end+1) = i;
  end
end

%tags(done) = [];
%annnames(done) = [];
%matnames(done) = [];
%savenames(done) = [];
%movienames(done) = [];

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
  save(savename,'trx');
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
