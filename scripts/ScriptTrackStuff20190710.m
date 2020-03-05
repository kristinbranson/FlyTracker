rootdir = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN';

addpath(genpath('.'));
addpath(fullfile(rootdir,'Code'));

expdirs = {
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlB_20120316T144030'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlC_20120316T144000'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlD_20120316T144003'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlA_20110707T154658'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlC_20110707T154934'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlD_20110707T154929'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlA_20110916T155922'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlA_20110921T085351'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlB_20110916T155917'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlB_20110921T085346'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlC_20110916T155358'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlC_20110921T084823'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlD_20110916T155353'
  '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlD_20110921T084818'
  };
moviestr = 'movie.ufmf';
rootoutdir = fullfile(rootdir,'Data/bowl');
forcevision = true;


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
  
trkfile = fullfile(outexpdir,[vidname '-track.mat']);
motionfile = fullfile(outexpdir,[vidname '-motion.mat']);
visionfile = fullfile(outexpdir,[vidname '-vision.mat']);
calibfile = fullfile(outexpdir,'calibration.mat');
bgfile = fullfile(outexpdir,[vidname '-bg.mat']);
featfile = fullfile(outexpdir,[vidname '-feat.mat']);

if ~forcevision && exist(motionfile,'file') && exist(visionfile,'file') && exist(fullfile(outexpdir,'eyrun_simulate_data.mat'),'file'),
  continue;
end

% model
model_dir = fullfile(rootdir,'Models/');
model_name = 'data4_dtype2_target4__GRU_layers1_units100_window1_bins50_diag0_later1__seq50_batch20_Yw1.0_Xw80.0_XtY0.5_C0.0_lr0.3_maint1_imp0_costw0_ada0_prct1.0_bestCost.mat';

% get scale parameters;
D = load([model_dir model_name]);
ranges = D.dataparam.scale;
mindist = D.dataparam.mindist;

fileinfo = struct('trkfile',trkfile,'motionfile',motionfile,'visionfile',visionfile,'calibfile',calibfile,'bgfile',bgfile,'featfile',featfile);
compute_motion_vision_features(3, fileinfo, 'mindist', mindist);

% locations of data

% load data 
D = load(trkfile); trk = D.trk;
D = load(motionfile); motion = D.motion;
D = load(visionfile); vision = D.vision;
D = load(calibfile); calib = D.calib;
D = load(bgfile); bg = D.bg.bg_mean;


% true motion data
n_motions = size(motion.data,3);
for i=1:n_motions
  motion.data(:,:,i) = motion.data(:,:,i)./ranges(i);
end

% get scale parameter from vison
n_oma = size(vision.data,3);

% place points on the edge of the chamber
mask = calib.masks{1};
mask(1,:) = 0; mask(end,:) = 0;
mask(:,1) = 0; mask(:,end) = 0;
outline = mask-imerode(mask,strel('disk',1));
[I,J] = find(outline==1);

% interpolate trk data
n_frames = size(trk.data,2);
for s=1:size(trk.data,1)
  for f_ind=1:17
    vec = trk.data(s,:,f_ind);
    invalid = isnan(vec);
    cc = bwconncomp(invalid);
    for c=1:cc.NumObjects
      % only interpolate if gap is less than 2 seconds
      if numel(cc.PixelIdxList{c}) > calib.FPS * 2
        continue;
      end
      fr_start = cc.PixelIdxList{c}(1)-1;
      fr_end   = cc.PixelIdxList{c}(end)+1;
      frs = fr_start:fr_end;
      % do not interpolate at the ends
      if fr_start < 1 || fr_end > n_frames
        continue
      end
      piece = (vec(fr_end)-vec(fr_start))/(numel(frs)-1);
      coeffs = 0:(numel(frs)-1);
      vec(frs) = vec(fr_start) + coeffs * piece;
    end
    trk.data(s,:,f_ind) = vec;
  end
end

% Load model
model = read_model([model_dir model_name]);
bins = model.bins;
sz = bins(:,2)-bins(:,1);
binedges = [bins(:,1)-sz,bins,bins(:,end)+sz];
bincenters = (binedges(:,1:end-1)+binedges(:,2:end))/2;

trx_x = trk.data(:,:,1);
trx_y = trk.data(:,:,2);
trx_theta = trk.data(:,:,3);
trx_a = trk.data(:,:,4);
trx_b = trk.data(:,:,5);
trx_l_wing_ang = trk.data(:,:,14);
trx_l_wing_len = trk.data(:,:,15);
trx_r_wing_ang = trk.data(:,:,16);
trx_r_wing_len = trk.data(:,:,17);

PPM = calib.PPM;
FPS = calib.FPS;

% 
% % initial values
% x = trk.data(:,1,1);
% y = trk.data(:,1,2);
% theta = trk.data(:,1,3);
% 
% % set other features to be similar to specified fly
% a          = nanmedian(trk.data(:,:,4),2);
% b          = nanmedian(trk.data(:,:,5),2);
% l_wing_ang = -nanmedian(trk.data(:,:,14),2);
% l_wing_len = nanmedian(trk.data(:,:,15),2);
% r_wing_ang = nanmedian(trk.data(:,:,16),2);
% r_wing_len = nanmedian(trk.data(:,:,17),2);
% 
% % median values:
% awing1 = l_wing_ang;
% awing2 = r_wing_ang;
% lwing1 = l_wing_len;
% lwing2 = r_wing_len;
% majax = a;

motiondata = motion.data;

save(fullfile(outexpdir,'eyrun_simulate_data.mat'),'trx_*','ranges','mindist','n_oma','I','J','PPM','FPS','binedges','bincenters','motiondata','bg');

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
