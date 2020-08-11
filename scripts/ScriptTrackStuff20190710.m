rootdir = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN';
rootbowldir = '/nearline/branson/bowl_data';

addpath(genpath('.'));
addpath(fullfile(rootdir,'Code'));

%GAL4linestr = 'GMR_71G01_AE_01_TrpA';
%GAL4linestr = 'pBDPGAL4U_TrpA';
%GAL4linestr = 'GMR_91B01_AE_01_TrpA';
GAL4linestr = 'GMR_26E01_AE_01_TrpA';
nexps = 16;

allexpdirs = mydir(fullfile(rootbowldir,[GAL4linestr,'*']));
assert(~isempty(allexpdirs));
isp = false(1,numel(allexpdirs));
clear expinfo;
for i = 1:numel(allexpdirs),
  expinfo(i) = parseExpDir(allexpdirs{i});
  f = fullfile(allexpdirs{i},'automatic_checks_complete_results.txt');
  if ~exist(f,'file'),
    continue;
  end
  r = ReadParams(fullfile(allexpdirs{i},'automatic_checks_complete_results.txt'));
  isp(i) = strcmpi(r.automated_pf,'P');
end
allexpdirs = allexpdirs(isp);
expinfo = expinfo(isp);
if numel(allexpdirs) <= nexps,
  expdirs = allexpdirs;
else
  datenums = datenum({expinfo.date},'yyyymmddTHHMMSS');
  rigbowl = arrayfun(@(x) [x.rig,x.bowl],expinfo,'Uni',0);
  [~,~,rbi] = unique(rigbowl);
  nexpsperrb = nexps/max(rbi);
  expidx = nan(1,nexps);
  selecteddatenums = nan(nexps,1);
  for i = 1:max(rbi),
    idx = find(rbi == i);
    if i == 1,
      [~,order] = sort(datenums(idx));
      idx1 = order(round(linspace(1,numel(idx),nexpsperrb)));
      selecteddatenums((i-1)*nexpsperrb+(1:nexpsperrb)) = datenums(idx(idx1));
    else
      idx1 = nan(1,nexpsperrb);
      for j = 1:nexpsperrb,
        d = min(abs(selecteddatenums-datenums(idx)'),[],1);
        [~,idx1(j)] = max(d);
        selecteddatenums((i-1)*nexpsperrb+j) = datenums(idx(idx1(j)));
      end
    end
    expidx((i-1)*nexpsperrb+(1:nexpsperrb)) = idx(idx1);
  end
  expdirs = allexpdirs(expidx);
end

moviestr = 'movie.ufmf';
rootoutdir = fullfile(rootdir,'Data/bowl');
forcevision = true;

%% track and compute features


for moviei = 1:numel(expdirs),

%% track
  
expdir = expdirs{moviei};
[~,expname] = fileparts(expdir);
outexpdir = fullfile(rootoutdir,expname);
outmoviefile = fullfile(outexpdir,moviestr);
moviefile = fullfile(expdir,moviestr);
[~,vidname] = fileparts(moviestr);
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
  vinfo = video_open(outmoviefile);
  tracker([], options, [], vinfo);
end

%% compute motion and vision features

  
% locations of data

trkfile = fullfile(outexpdir,[vidname '-track.mat']);
motionfile = fullfile(outexpdir,[vidname '-motion.mat']);
visionfile = fullfile(outexpdir,[vidname '-vision.mat']);
calibfile = fullfile(outexpdir,'calibration.mat');
bgfile = fullfile(outexpdir,[vidname '-bg.mat']);
featfile = fullfile(outexpdir,[vidname '-feat.mat']);

% model
model_dir = fullfile(rootdir,'Models/');
model_name = 'data4_dtype2_target4__GRU_layers1_units100_window1_bins50_diag0_later1__seq50_batch20_Yw1.0_Xw80.0_XtY0.5_C0.0_lr0.3_maint1_imp0_costw0_ada0_prct1.0_bestCost.mat';
modelfile = fullfile(model_dir,model_name);

% output
simulatefile = fullfile(outexpdir,'eyrun_simulate_data.mat');

if ~forcevision && exist(motionfile,'file') && exist(visionfile,'file') && exist(fullfile(outexpdir,'eyrun_simulate_data.mat'),'file'),
  continue;
end

D = load(fileinfo.modelfile);
ranges = D.dataparam.scale;
mindist = D.dataparam.mindist;

fileinfo = struct('trkfile',trkfile,'motionfile',motionfile,'visionfile',visionfile,...
  'calibfile',calibfile,'bgfile',bgfile,'featfile',featfile,'modelfile',modelfile,...
  'simulatefile',simulatefile);
compute_motion_vision_features(3, fileinfo, 'mindist', mindist);

compute_simulate_data(fileinfo);

end


%% compare 

newd = load(fullfile(outexpdir,'eyrun_simulate_data.mat'));
oldd = load('/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Code/eyrun_simulate_data.mat');
assert(all(newd.bincenters(:)==oldd.bincenters(:)));
figure;
clf;
hax = createsubplots(size(oldd.bincenters,1),1,.025);
for i = 1:size(oldd.bincenters,1),
  counts = hist(vectorize(oldd.motiondata(:,:,i)),oldd.bincenters(i,:));
  frac = counts / sum(counts);
  plot(hax(i),oldd.bincenters(i,:),frac);
  hold(hax(i),'on');
  counts = hist(vectorize(newd.motiondata(:,:,i)),oldd.bincenters(i,:));
  frac = counts / sum(counts);
  plot(hax(i),oldd.bincenters(i,:),frac);
end
legend(hax(1),{'old','new'});

oldd = load('/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653-vision.mat');
newd = load(visionfile);
figure
clf;
nbinsplot = 10;
idx = round(linspace(1,size(oldd.vision.data,3),nbinsplot));
hax = createsubplots(nbinsplot,numel(oldd.vision.names),.025);
hax = reshape(hax,[nbinsplot,numel(oldd.vision.names)]);
minv = min(min(oldd.vision.data(~isinf(oldd.vision.data))),min(newd.vision.data(~isinf(newd.vision.data))));
maxv = max(max(oldd.vision.data(~isinf(oldd.vision.data))),max(newd.vision.data(~isinf(newd.vision.data))));
edges = linspace(minv,maxv,51);
ctrs = (edges(1:end-1)+edges(2:end))/2;

for i = 1:numel(oldd.vision.names),
  for jj = 1:numel(idx),
    j = idx(jj);
    datacurr = oldd.vision.data(:,:,j,i);
    datacurr = datacurr(~isinf(datacurr));
    counts = hist(datacurr,ctrs);
    frac = counts / sum(counts);
    plot(hax(jj,i),ctrs,frac);
    hold(hax(jj,i),'on');
    datacurr = newd.vision.data(:,:,j,i);
    datacurr = datacurr(~isinf(datacurr));
    counts = hist(datacurr,ctrs);
    frac = counts / sum(counts);
    plot(hax(jj,i),ctrs,frac);
  end
end
legend(hax(1,1),{'old','new'});

%oldd = load('/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Code/compute_vision_data.mat');
oldd = struct;
oldd.vision = struct;
pyd = readNPY('/groups/branson/home/bransonk/behavioranalysis/code/FlyTrajPred_v4/data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/real_fly_vision_dist_data_0t0_1000t1.npy');
pyd = reshape(pyd,[size(pyd,1),size(pyd,2),size(pyd,3)/2,2]);
pyd = cat(1,nan(1,size(pyd,2),size(pyd,3),size(pyd,4)),pyd);
pyd = permute(pyd,[2,1,3,4]);
oldd.vision.data = pyd;

pyd = readNPY('/groups/branson/home/bransonk/behavioranalysis/code/FlyTrajPred_v4/data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/real_fly_vision_data_0t0_1000t1.npy');
%pyd = readNPY('/groups/branson/home/imd/Documents/janelia/research/FlyTrajPred_v4/pytorch/data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/real_fly_vision_data_0t0_30320t1.npy');
pyd = reshape(pyd,[size(pyd,1),size(pyd,2),size(pyd,3)/2,2]);
pyd = cat(1,nan(1,size(pyd,2),size(pyd,3),size(pyd,4)),pyd);
pyd = permute(pyd,[2,1,3,4]);
oldd.vision.ndata = pyd;

newd = load(visionfile);

figure
clf;
nbinsplot = 10;
idx = round(linspace(1,size(newd.vision.ndata,3),nbinsplot));
hax = createsubplots(nbinsplot,numel(newd.vision.names),.025);
hax = reshape(hax,[nbinsplot,numel(newd.vision.names)]);
minv = min(min(oldd.vision.ndata(~isinf(oldd.vision.ndata))),min(newd.vision.ndata(~isinf(newd.vision.ndata))));
maxv = max(max(oldd.vision.ndata(~isinf(oldd.vision.ndata))),max(newd.vision.ndata(~isinf(newd.vision.ndata))));
edges = linspace(minv,maxv,51);
ctrs = (edges(1:end-1)+edges(2:end))/2;

for i = 1:numel(newd.vision.names),
  for jj = 1:numel(idx),
    j = idx(jj);
    datacurr = oldd.vision.ndata(:,:,j,i);
    datacurr = datacurr(~isinf(datacurr));
    counts = hist(datacurr,ctrs);
    frac = counts / sum(counts);
    plot(hax(jj,i),ctrs,frac);
    hold(hax(jj,i),'on');
    datacurr = newd.vision.ndata(:,:,j,i);
    datacurr = datacurr(~isinf(datacurr));
    counts = hist(datacurr,ctrs);
    frac = counts / sum(counts);
    plot(hax(jj,i),ctrs,frac);
    xlabel(sprintf('%s, bin %d',newd.vision.names{i},j));
  end
end
legend(hax(1,1),{'old','new'});

%% call JAABA classifiers -- at least ones that don't need wings! 

jabfile = '/groups/branson/home/robiea/Projects_data/JAABA/ProjectFiles_jab/ChaseAR_new_v10p0.jab';
