%% run chase classifier on some simulated data

%% set up path

addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/misc;
addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/filehandling;
addpath(genpath('/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5'));
fbadir = '/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis';

%% locations of files

jabfile = '/groups/branson/home/bransonk/behavioranalysis/data/JAABAFlyTracker/ProjectFiles_jab/ChaseAR_new_v10p0_FT.jab';

rootoutdir = '/groups/branson/home/bransonk/behavioranalysis/data/JAABASim';
rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/fly_behaviour_sim/71g01/trx';
%rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/FlyTrajPred_v4/pytorch/trx';
trxfilestrs = {
  'rnn50_trx_0t0_Nonet1_epoch200000_LOO_full_100hid_lr0.010000_testvideo0.mat'
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
% be the one used for seeding the simulation. 
% 
expdir0 = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027';

%% compute per-frame features

addpath(fbadir);

protocol = 'current';
dataloc_params = ReadParams(fullfile(fbadir,'settings',protocol,'dataloc_params.txt'));
dataloc_params.flytrackertrackstr = 'movie-track.mat';

simexpdirs = PrepareSimTrx4JAABA(trxfiles,expdir0,...
  'rootoutdir',rootoutdir,...
  'dataloc_params',dataloc_params,...
  'nooverwrite',false);

%% sanity check

perframefn = 'velmag_ctr';
pd0 = load(fullfile(expdir0,dataloc_params.perframedir,[perframefn,'.mat']));
pfd = [pd0.data{:}];
maxvelmag = prctile(pfd,99);
edges = linspace(0,maxvelmag,101);
ctrs = (edges(1:end-1)+edges(2:end))/2;
counts = hist(pfd,ctrs);
figure(123);
clf;
plot(ctrs,counts/sum(counts),'k-','LineWidth',2);
hold on;
[~,n] = fileparts(expdir0);
legs = {['real ',n]};

for moviei = 1:numel(simexpdirs),
  [~,n] = fileparts(simexpdirs{moviei});
  pd = load(fullfile(simexpdirs{moviei},dataloc_params.perframedir,[perframefn,'.mat']));
  for i = 1:numel(pd.data),
    pfd = pd.data{i};
    counts = hist(pfd,ctrs);
    plot(ctrs,counts/sum(counts));
    legs{end+1} = sprintf('fly%d_%s',i,n);
  end
  %mean_velmag_ctr = nanmean([pd.data{:}]);
end
  
legend(legs,'interpreter','none');
xlabel(perframefn);

%% run chase classifier

addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/perframe;

for moviei = 1:numel(simexpdirs),
  JAABADetect(simexpdirs{moviei},'jabfiles',{jabfile});
end

jd = loadAnonymous(jabfile);
simfractime = nan(1,numel(simexpdirs));
simfractime_fly = cell(1,numel(simexpdirs));
for moviei = 1:numel(simexpdirs),
  
  fscorefile = fullfile(simexpdirs{moviei},jd.file.scorefilename{1});
  sd = load(fscorefile);
  [~,expname] = fileparts(simexpdirs{moviei});
  n = 0;
  d = 0;
  for i = 1:numel(sd.allScores.postprocessed),
    n1 = nnz(sd.allScores.postprocessed{i}==1);
    d1 = nnz(~isnan(sd.allScores.postprocessed{i}));
    n = n + n1;
    d = d + d1;
    simfractime_fly{moviei}(i) = n1/d1;
  end
  fractime = n / d;
  simfractime(moviei) = fractime;
  
  fprintf('%d (%s): fractime %s: %f\n',moviei,expname,...
    jd.behaviors.names{1},simfractime(moviei));
  fprintf('Per fly:');
  for i = 1:numel(sd.allScores.postprocessed),
    fprintf(' %f',simfractime_fly{moviei}(i));
  end
  fprintf('\n');
  
end

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
%box off;
