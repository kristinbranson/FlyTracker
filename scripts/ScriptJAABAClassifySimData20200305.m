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
% real experiment used for seeding the simulation
% 
expdir0 = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlA_20110707T154658';

%% compute per-frame features

addpath(fbadir);

protocol = 'current';
dataloc_params = ReadParams(fullfile(fbadir,'settings',protocol,'dataloc_params.txt'));
dataloc_params.flytrackertrackstr = 'movie-track.mat';

simexpdirs = PrepareSimTrx4JAABA(trxfiles,expdir0,...
  'rootoutdir',rootoutdir,...
  'dataloc_params',dataloc_params,...
  'forcecompute',true,...
  'is_temporally_aligned',false);

%% sanity check

perframefn = 'dnose2ell';
pd0 = load(fullfile(expdir0,dataloc_params.perframedir,[perframefn,'.mat']));
pfd = [pd0.data{:}];
maxvelmag = prctile(pfd,99);
edges = linspace(0,maxvelmag,101);
ctrs = (edges(1:end-1)+edges(2:end))/2;

counts = nan(numel(pd0.data),numel(ctrs));
for i = 1:numel(pd.data),
  pfd = pd0.data{i};
  counts(i,:) = hist(pfd,ctrs);
  %plot(ctrs,counts/sum(counts));
end

figure(123);
clf;
hax = createsubplots(2,1,.05);
axes(hax(1));
% colors1 = bone(numel(pd0.data));
% colors2 = copper(numel(pd0.data));
% nflies = numel(pd0.data);
% colors = [colors1(end-ceil(nflies/2)-3:end-4,:)
%   flipud(colors2(end-floor(nflies/2)+1:end,:))];
% simflies = [1,11];
% colors(simflies,:) = 0;

h = bar(ctrs,counts'/sum(counts(:)),'stacked');
% for i = 1:numel(h),
%   set(h(i),'FaceColor',colors(i,:));
% end
% set(h,'LineStyle','none');
title('real');
box off;

moviei = 1;
axes(hax(2));
pd = load(fullfile(simexpdirs{moviei},dataloc_params.perframedir,[perframefn,'.mat']));
counts = zeros(numel(pd.data),numel(ctrs));
for i = 1:numel(pd.data),
  pfd = pd.data{i};
  counts(i,:) = hist(pfd,ctrs);
end
h = bar(ctrs,counts'/sum(counts(:)),'stacked');
% for i = 1:numel(h),
%   set(h(i),'FaceColor',colors(i,:));
% end
% set(h,'LineStyle','none');
xlabel(perframefn);
title('simulated');
box off;

linkaxes(hax);

%% run chase classifier

addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/perframe;

for moviei = 1:numel(simexpdirs),
  JAABADetect(simexpdirs{moviei},'jabfiles',{jabfile},'forcecompute',true);
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
    fprintf(' %d: %f',i,simfractime_fly{moviei}(i));
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
