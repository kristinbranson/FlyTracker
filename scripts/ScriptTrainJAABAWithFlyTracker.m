%% retrain JAABA classifier using FlyTracker tracks

if ispc,
  addpath ../Jdetect/perframe;
else
  addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/perframe;
end
SetUpJAABAPath;

behavior = 'chase';
rootoutdir = ['/groups/branson/home/bransonk/behavioranalysis/data/JAABAFlyTracker/Data_',behavior];
jabdir = '/groups/branson/home/robiea/Projects_data/JAABA/ProjectFiles_jab';
outjabdir = '/groups/branson/home/bransonk/behavioranalysis/data/JAABAFlyTracker/ProjectFiles_jab';
jabfile = fullfile(jabdir,'ChaseAR_new_v10p0.jab');
outjabfile = fullfile(outjabdir,'ChaseAR_new_v10p0_FT.jab');
codedir = fileparts(mfilename('fullpath'));
fbadir = '/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis';
rootdatadir = '/nearline/branson/bowl_data';
protocol = 'current';

if ispc,
  jabfile = JaneliaLinux2WinPath(jabfile);
  rootoutdir = JaneliaLinux2WinPath(rootoutdir);
  fbadir = JaneliaLinux2WinPath(fbadir);
  rootdatadir = JaneliaLinux2WinPath(rootdatadir);
  outjabdir = JaneliaLinux2WinPath(outjabdir);
  outjabfile = JaneliaLinux2WinPath(outjabfile);
end
addpath(fbadir);
if ~exist(outjabdir,'dir'),
  mkdir(outjabdir);
end
  

dataloc_params = ReadParams(fullfile(fbadir,'settings',protocol,'dataloc_params.txt'));
dataloc_params.flytrackertrackstr = 'movie-track.mat';

if ~exist(rootoutdir,'dir'),
  mkdir(rootoutdir);
end

assert(exist(jabfile,'file') > 0);

jd = loadAnonymous(jabfile);
expdirs_train = jd.expDirNames;
if ispc,
  expdirs_train = JaneliaLinux2WinPath(expdirs_train);
end

assert(all(cellfun(@exist,expdirs_train)>0));

%% track all experiments in the jab file using FlyTracker
ncores = 16;

for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outmoviefile = fullfile(outexpdir,dataloc_params.moviefilestr);
  moviefile = fullfile(expdir,dataloc_params.moviefilestr);
  [~,vidname] = fileparts(dataloc_params.moviefilestr);
  trkfile = fullfile(outexpdir,[vidname '-track.mat']);
  
  if ~exist(outexpdir,'dir'),
    mkdir(outexpdir);
  end
  if ~exist(outmoviefile,'file'),
    unix(sprintf('ln -s %s %s',moviefile,outmoviefile));
  end

  options.num_cores   = maxNumCompThreads;
  options.num_chunks = options.num_cores*2;
  options.save_JAABA  = true;
  options.save_xls    = false;
  options.save_seg    = false;
  options.f_parent_calib = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/calibration20190712.mat';
  options.force_calib = true;
  options.expdir_naming = true;
  options.fr_sample = 200;
  
  if exist(trkfile,'file'),
    fprintf('Tracking done for %s, skipping.\n',expname);
  else
    jobid = sprintf('FT%s%02d',behavior,moviei);
    logfile = fullfile(outexpdir,'FlyTracker.log');
    shfile = fullfile(outexpdir,'FlyTracker.sh');
    fid = fopen(shfile,'w');
    fprintf(fid,'cd %s; matlab -nodisplay -r "FlyTrackerWrapper(''%s'',%d)"',codedir,outmoviefile,ncores);
    fclose(fid);
    unix(sprintf('chmod u+x %s',shfile));
    cmd2 = sprintf('bsub -n %d -R"affinity[core(1)]" -o %s -J %s "%s"',ncores,logfile,jobid,shfile);
    cmd3 = sprintf('ssh login1 ''source /etc/profile; %s''',cmd2);
    unix(cmd3);
  end

end

% check that things are done
isdone = false(1,numel(expdirs_train));
for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outmoviefile = fullfile(outexpdir,dataloc_params.moviefilestr);
  moviefile = fullfile(expdir,dataloc_params.moviefilestr);
  [~,vidname] = fileparts(dataloc_params.moviefilestr);
  trkfile = fullfile(outexpdir,[vidname '-track.mat']);

  if exist(trkfile,'file'),
    fprintf('Tracking done for %s.\n',expname);
    isdone(moviei) = true;
  else
    isdone(moviei) = false;
  end
end
fprintf('%d / %d done.\n',nnz(isdone),numel(isdone));

%% set timestamps to correspond to movie frame timestamps

for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
  outtrxfile = fullfile(outexpdir,dataloc_params.ctraxfilestr);
  td = load(intrxfile);
  [~,~,fid,headerinfo] = get_readframe_fcn(fullfile(outexpdir,dataloc_params.moviefilestr));
  td.timestamps = headerinfo.timestamps'-headerinfo.timestamps(1);
  for i = 1:numel(td.trx),
    td.trx(i).timestamps = td.timestamps(td.trx(i).firstframe:td.trx(i).endframe)';
    td.trx(i).dt = diff(td.trx(i).timestamps);
  end
  fclose(fid);
  save(outtrxfile,'-struct','td');
  
end

%% run FBRegisterTrx on FlyTracker outputs

for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outannfile = fullfile(outexpdir,dataloc_params.annfilestr);
  outmetadatafile = fullfile(outexpdir,dataloc_params.metadatafilestr);
  
  if ~exist(outannfile,'file'),
    inannfile = fullfile(rootdatadir,expname,dataloc_params.annfilestr);
    assert(exist(inannfile,'file')>0);
    cmd = sprintf('ln -s %s %s',inannfile,outannfile);
    unix(cmd);
  end
  if ~exist(outmetadatafile,'file'),
    inmetadatafile = fullfile(rootdatadir,expname,dataloc_params.metadatafilestr);
    assert(exist(inmetadatafile,'file')>0);
    cmd = sprintf('cp %s %s/.',inmetadatafile,outexpdir);
    unix(cmd);
  end
  if isempty(dir(fullfile(outexpdir,dataloc_params.configfilepattern))),
    inprotocol = fullfile(rootdatadir,expname,dataloc_params.configfilepattern);
    assert(~isempty(dir(inprotocol)));
    cmd = sprintf('cp %s %s/.',inprotocol,outexpdir);
    unix(cmd);
  end
%   intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
%   outtrxfile = fullfile(outexpdir,'ctrax_results.mat');
%   if ~exist(outtrxfile,'file'),
%     assert(exist(intrxfile,'file')>0);
%     cmd = sprintf('ln -s %s %s',intrxfile,outtrxfile);
%     unix(cmd);
%   end
  
  FlyBowlRegisterTrx(outexpdir);
  
end

% check that first frames and end frames match
for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  ftrxfile = fullfile(outexpdir,dataloc_params.trxfilestr);
  ftrx = load(ftrxfile);
  ctrxfile = fullfile(expdir,dataloc_params.trxfilestr);
  ctrx = load(ctrxfile);
  ffirstframe = min([ftrx.trx.firstframe]);
  fendframe = max([ftrx.trx.endframe]);
  cfirstframe = min([ctrx.trx.firstframe]);
  cendframe = max([ctrx.trx.endframe]);
  assert(ffirstframe == cfirstframe && fendframe == cendframe);
  
end

%% compute some wing-related features from FlyTracker outputs
% wing-related features:
% wing_anglel <- -'wing l ang'
% wing_angler <- -'wing r ang'
% wing_areal <- 'wing l len'
% wing_arear <- 'wing r len'
% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2

for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  FlyTracker2WingTracking(outexpdir,'dataloc_params',dataloc_params);
  
end

%% run FBComputePerFrameFeatures on outputs

for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  FlyBowlComputePerFrameFeatures(outexpdir);%,'forcecompute',false);
  
end

%% create a new jab file with the FlyTracker outputs and the reordered labels

newlabels = Labels.labels(numel(expdirs_train));
mindswap = 10;
outexpdirs = cell(size(jd.expDirNames));
for moviei = 1:numel(expdirs_train),
  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outexpdirs{moviei} = outexpdir;
  
  ftrx = load(fullfile(outexpdir,jd.file.trxfilename));
  ftrx = ftrx.trx;
  ctrx = load(fullfile(expdir,jd.file.trxfilename));
  ctrx = ctrx.trx;
  [f2c,c2f,cost] = match_ctrax_to_flytracker(ctrx,ftrx);
  clf;
  imagesc(f2c);
  hcb = colorbar;
  xlabel('Time (fr)');
  ylabel('FlyTracker id');
  hcb.Label.String = 'Ctrax id';
  box off;
  title(sprintf('%s-%d: %s',behavior,moviei,expname),'interpreter','none');
  set(gcf,'renderer','painters');
  colormap([0,0,0;hsv(numel(ctrx))]);
  saveas(gcf,fullfile(outexpdir,'FlyTracker2Ctrax.svg'),'svg')
  
  newlabels(moviei) = ReorderLabels(ctrx,ftrx,f2c,moviei,jd,'mindswap',mindswap);

end

jd.expDirNames = outexpdirs;
jd.labels = newlabels;
saveAnonymous(outjabfile,jd);

%% train

% did this in JAABA GUI! 

%% classify 71G01 data
roottestdir = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl';
testline = 'GMR_71G01_AE_01';
testdirs = mydir(fullfile(roottestdir,[testline,'*']),'isdir',true);

PrepareFlyTracker4JAABA(testdirs,...
  'rootdatadir',rootdatadir,...
  'dataloc_params',dataloc_params);

% added this to PrepareFlyTracker4JAABA
% fracmale = .5;
% for moviei = 1:numel(testdirs),
%   outtrxfile = fullfile(testdirs{moviei},dataloc_params.trxfilestr);
%   FlyTrackerClassifySex(outtrxfile,'fracmale',fracmale);
%   outtrxfile = fullfile(testdirs{moviei},dataloc_params.wingtrxfilestr);
%   td = FlyTrackerClassifySex(outtrxfile,'fracmale',fracmale);
% end

for moviei = 1:numel(testdirs),
  JAABADetect(testdirs{moviei},'jabfiles',{outjabfile});
end

%% compare frac time for each of these

for moviei = 1:numel(testdirs),
  
  fscorefile = fullfile(testdirs{moviei},jd.file.scorefilename);
  fsd = load(fscorefile);
  [~,expname] = fileparts(testdirs{moviei});
  expdir0 = fullfile(rootdatadir,expname);
  csd = load(fullfile(expdir0,dataloc_params.statsperframematfilestr));
  sd = fsd;
  n = 0;
  d = 0;
  for i = 1:numel(sd.allScores.postprocessed),
    n = n + nnz(sd.allScores.postprocessed{i}==1);
    d = d + nnz(~isnan(sd.allScores.postprocessed{i}));
  end
  fractime = n / d;
  ffractime(moviei) = fractime;
  
  fn = sprintf('fractime_flyany_frame%s',lower(jd.behaviors.names{1}));
  cfractime(moviei) = csd.statsperexp.(fn).meanmean;
  
  fprintf('%d (%s): fractime %s ctrax: %f, flytracker: %f\n',moviei,expname,...
    jd.behaviors.names{1},cfractime(moviei),ffractime(moviei));
  
end

figure(345);
clf
plot(cfractime,ffractime,'ko','MarkerFaceColor','k');
xlabel('Frac. time Ctrax');
ylabel('Frac. time FlyTracker');
axisalmosttight;
xlim = get(gca,'XLim');
ylim = get(gca,'YLim');
lim = [min(xlim(1),ylim(1)),max(xlim(2),ylim(2))];
axis equal;
axis([lim,lim]);
hold on;
plot(lim,lim,'c-');
box off;

%% run chase classifier on some simulated data

rootoutdir = '/groups/branson/home/bransonk/behavioranalysis/data/JAABASim';
rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/fly_behaviour_sim/71g01/trx';
%rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/FlyTrajPred_v4/pytorch/trx';
trxfilestrs = {
  'rnn50_trx_0t0_30320t1_epoch50000_SMSF_full_100hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_1000t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo1.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo2.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo3.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo4.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo5.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo6.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo7.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo8.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo9.mat'
  };
trxfiles = cellfun(@(x) fullfile(rootsimtestdir,x),trxfilestrs,'Uni',0);
% one real experiment that the simulator was trained on. ideally, it would
% be the one used for seeding the simulation
expdir0 = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027';

simexpdirs = PrepareSimTrx4JAABA(trxfiles,expdir0,...
  'rootoutdir',rootoutdir,...
  'dataloc_params',dataloc_params);

% sanity check

pd = load(fullfile(simexpdirs{moviei},dataloc_params.perframedir,'velmag_ctr.mat'));
sim_mean_velmag_ctr = nanmean([pd.data{:}]);
pd = load(fullfile(testdirs{moviei},dataloc_params.perframedir,'velmag_ctr.mat'));
mean_velmag_ctr = nanmean([pd.data{:}]);


for moviei = 1:numel(simexpdirs),
  JAABADetect(simexpdirs{moviei},'jabfiles',{outjabfile});
end

simfractime = nan(1,numel(simexpdirs));
for moviei = 1:numel(simexpdirs),
  
  fscorefile = fullfile(simexpdirs{moviei},jd.file.scorefilename);
  sd = load(fscorefile);
  [~,expname] = fileparts(simexpdirs{moviei});
  n = 0;
  d = 0;
  for i = 1:numel(sd.allScores.postprocessed),
    n = n + nnz(sd.allScores.postprocessed{i}==1);
    d = d + nnz(~isnan(sd.allScores.postprocessed{i}));
  end
  fractime = n / d;
  simfractime(moviei) = fractime;
  
  fprintf('%d (%s): fractime %s: %f\n',moviei,expname,...
    jd.behaviors.names{1},simfractime(moviei));
  
end

figure(346);
clf
boxplot([ffractime,simfractime],[ones(size(ffractime)),ones(size(simfractime))+1],...
  'labels',{'Real','Simulated'});
% plot(cfractime,ffractime,'ko','MarkerFaceColor','k');
% xlabel('Frac. time Ctrax');
% ylabel('Frac. time FlyTracker');
% axisalmosttight;
% xlim = get(gca,'XLim');
% ylim = get(gca,'YLim');
% lim = [min(xlim(1),ylim(1)),max(xlim(2),ylim(2))];
% axis equal;
% axis([lim,lim]);
% hold on;
% plot(lim,lim,'c-');
box off;

%% compute per-frame stats

statsperframefeaturesfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/stats_perframefeatures.txt';
histperframefeaturesfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/hist_perframefeatures.txt';
for i = 1:numel(testdirs),
  FlyBowlComputePerFrameStats2(testdirs{i},'statsperframefeaturesfile',statsperframefeaturesfile,'histperframefeaturesfile',histperframefeaturesfile)
end
for i = 1:numel(simexpdirs),
  FlyBowlComputePerFrameStats2(simexpdirs{i},'statsperframefeaturesfile',statsperframefeaturesfile,'histperframefeaturesfile',histperframefeaturesfile)
end

%% plot per-frame stats

figure(123);
clf;
hold on;
plottype = 'linear';
for i = 1:1,%numel(testdirs),
  hd = load(fullfile(testdirs{i},dataloc_params.histperframematfilestr));
  plot(hd.bins.velmag_ctr.(['centers_',plottype]),hd.histperexp.velmag_ctr_flyany_frameany.(['meanfrac_',plottype]),'k-');
end
for i = 1:1,%numel(simexpdirs),
  hd = load(fullfile(simexpdirs{i},dataloc_params.histperframematfilestr));
  plot(hd.bins.velmag_ctr.(['centers_',plottype]),hd.histperexp.velmag_ctr_flyany_frameany.(['meanfrac_',plottype]),'r-');
end
xlabel('velmag_ctr','interpreter','none');
ylabel('Frac. frames');
%% compute groundtruth accuracy
