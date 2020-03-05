if ispc,
  addpath ../Jdetect/perframe;
else
  addpath /groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/perframe;
end
SetUpJAABAPath;

if ispc,
  frootdir = 'FlyTrackerData';
  crootdir = 'CtraxData';
  jabfile = 'ChaseAR_new_v10p0.jab';
else
  frootdir = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl';
  jabfile = '/groups/branson/home/robiea/Projects_data/JAABA/ProjectFiles_jab/ChaseAR_new_v10p0.jab';
end

jd = loadAnonymous(jabfile);
expi = 4;

%expdir_ctrx = jd.expDirNames{expi};

expdir_ctrx = '/groups/branson/home/robiea/Projects_data/JAABA/Data_wingextension/GMR_71G01_AE_01_TrpA_Rig2Plate17BowlD_20110921T084818';

[~,name] = fileparts(expdir_ctrx);
expdir_ftrx = fullfile(frootdir,name);
if ispc,
  expdir_ctrx = fullfile(crootdir,name);
end

ctrx = load(fullfile(expdir_ctrx,jd.file.trxfilename));

ctrx = ctrx.trx;
ftrx = load(fullfile(expdir_ftrx,'movie_JAABA','registered_trx.mat'));
ftrx = ftrx.trx;
%ftrx0 = ftrx;
%fdata = load(fullfile(expdir_ftrx,'movie-track.mat'));

% %% crop ftrx to match pre-cropped ctrx
% t0 = min([ctrx.firstframe]);
% t1 = max([ctrx.endframe]);
% 
% % which fields should be cropped
% for i = 1:numel(ftrx),
%   n = structfun(@numel,ftrx(i));
%   fnidxcurr = n == ftrx(i).nframes;
%   if i == 1,
%     fnidx = fnidxcurr;
%   else
%     assert(all(fnidxcurr==fnidx));
%   end
% end
% fns = fieldnames(ftrx);
% fnscrop = fns(fnidx);
% 
% % crop!
% ncrop0 = nan(1,numel(ftrx));
% ncrop1 = nan(1,numel(ftrx));
% for i = 1:numel(ftrx),
%   ncrop0(i) = max(0,t0-ftrx(i).firstframe);
%   ncrop1(i) = max(0,ftrx(i).endframe-t1);
%   if ncrop0(i) > 0,
%     ftrx(i).firstframe = t0;
%     ftrx(i).off = 1-ftrx(i).firstframe;
%     for j = 1:numel(fnscrop),
%       ftrx(i).(fnscrop{j})(1:ncrop0(i)) = [];
%     end
%   end
%   if ncrop1(i) > 0,
%     ftrx(i).endframe = t1;
%     for j = 1:numel(fnscrop),
%       ftrx(i).(fnscrop{j})(end-ncrop1(i)+1:end) = [];
%     end
%   end
% end

%% match

[f2c,c2f,cost] = match_ctrax_to_flytracker(ctrx,ftrx);

%% reorder labels based on matching

mindswap = 10;
VALS = 1;
IMP = 2;
TIMESTAMP = 3;
cnflies = numel(ctrx);
fnflies = numel(ftrx);
nframes = max([ctrx.endframe]);
clabels = zeros([cnflies,nframes,3]);
for i = 1:size(jd.labels(expi).flies,1),
  fly = jd.labels(expi).flies(i,1);
  labelsshort = Labels.labelsShortInit(Labels.labelsShort(),jd.labels(expi),fly);
  labelidx = Labels.labelIdx(jd.behaviors.names,ctrx(fly).firstframe,ctrx(fly).endframe);
  labelidx = Labels.labelIdxInit(labelidx,labelsshort);
  clabels(fly,labelidx.T0:labelidx.T1,VALS) = labelidx.vals;
  clabels(fly,labelidx.T0:labelidx.T1,IMP) = labelidx.imp;
  clabels(fly,labelidx.T0:labelidx.T1,TIMESTAMP) = labelidx.timestamp;
end

flabels = zeros([fnflies,max([ftrx.endframe]),3]);
for ffly = 1:fnflies,
  for t = ftrx(ffly).firstframe:ftrx(ffly).endframe,
    if f2c(ffly,t) > 0,
      flabels(ffly,t,:) = clabels(f2c(ffly,t),t,:);
    end
  end
end

dswap = zeros([fnflies,max([ftrx.endframe])]);
for ffly = 1:fnflies,
  isswap = [f2c(ffly,1:end-1)~=f2c(ffly,2:end),false];
  dswap(ffly,:) = bwdist(isswap);
end

flabelsclean = flabels;
for i = 1:3,
  tmp = flabels(:,:,i);
  tmp(dswap<=mindswap) = 0;
  flabelsclean(:,:,i) = tmp;
end
fprintf('Exp %d (%s): %d / %d positive and %d / %d negative labels remain\n',...
  expi,name,...
  nnz(flabelsclean(:,:,VALS)==1),nnz(flabels(:,:,VALS)==1),...
  nnz(flabelsclean(:,:,VALS)==2),nnz(flabels(:,:,VALS)==2));

%% compare overlapping features after matching

cnflies = numel(ctrx);
fnflies = numel(ftrx);

fpfd = fullfile(expdir_ftrx,'movie_JAABA','perframe');
cpfd = fullfile(expdir_ctrx,'perframe');
ffns = mydir(fullfile(fpfd,'*.mat'));
cfns = mydir(fullfile(cpfd,'*.mat'));
for i = 1:numel(ffns),
  [~,ffns{i}] = fileparts(ffns{i});
end
for i = 1:numel(cfns),
  [~,cfns{i}] = fileparts(cfns{i});
end

plottype = 'hist';

fns = intersect(cfns,ffns);
fns = fns(cellfun(@isempty,regexp(fns,'^closestfly','once')));
fns(ismember(fns,{'sex','dt','timestamps'})) = [];

nr = 3;
nc = 3;

npages = ceil(numel(fns)/nr/nc);
clear hax;
switch plottype,
  case 'off',
    figoff = 0;
  case 'hist'
    figoff = 100;
  case 'raw',
    figoff = 200;
end


hfigs = gobjects(npages);
for pagei = 1:npages,
  hfigs(pagei) = figure(pagei+figoff);
  clf;
  hax(:,:,pagei) = reshape(createsubplots(nr,nc,.05),[nr,nc]);
end

for fni = 1:numel(fns),
  
  [ci,ri,pagei] = ind2sub([nc,nr,npages],fni);
  if ci == 1 && ri == 1,
    figure(hfigs(pagei));
  end
  
  haxcurr = hax(ri,ci,pagei);
  
  fn = fns{fni};
  fd = load(fullfile(fpfd,[fn,'.mat']));
  cd = load(fullfile(cpfd,[fn,'.mat']));
  
  PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,fn,'hax',haxcurr,'plottype',plottype);

  drawnow;
  
end

%% compare wing features after matching

plottype = 'hist';
nr = 2;
nc = 3;
limprctile = 2;

% wing lengths
ftd = load(fullfile(expdir_ftrx,'movie-track.mat'));
fidx = struct;
fidx.wing_anglel = find(strcmp(ftd.trk.names,'wing l ang'));
fidx.wing_angler = find(strcmp(ftd.trk.names,'wing r ang'));
fidx.wing_lengthl = find(strcmp(ftd.trk.names,'wing l len'));
fidx.wing_lengthr = find(strcmp(ftd.trk.names,'wing r len'));

hfig = 123;
figure(hfig);
hax = reshape(createsubplots(nr,nc,.05),[nr,nc]);

fni = 1;
[ci,ri] = ind2sub([nc,nr],fni);
haxcurr = hax(ri,ci);
ffn = '-wing_anglel';
cfn = 'wing_angler';
fd0 = -ftd.trk.data(:,:,fidx.wing_anglel);
fd = struct;
fd.data = cell(1,fnflies);
for i = 1:fnflies,
  fd.data{i} = fd0(i,ftrx(i).firstframe:ftrx(i).endframe);
end

if strcmp(cfn,ffn),
  ti = cfn;
else
  ti = sprintf('f=%s vs c=%s',ffn,cfn);
end

cd = load(fullfile(cpfd,[cfn,'.mat']));
PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,ti,'hax',haxcurr,'plottype',plottype,'limprctile',limprctile,'domatch',false);

drawnow;

fni = fni + 1;
[ci,ri] = ind2sub([nc,nr],fni);
haxcurr = hax(ri,ci);
ffn = '-wing_angler';
cfn = 'wing_anglel';
fd0 = -ftd.trk.data(:,:,fidx.wing_angler);
fd = struct;
fd.data = cell(1,fnflies);
for i = 1:fnflies,
  fd.data{i} = fd0(i,ftrx(i).firstframe:ftrx(i).endframe);
end

if strcmp(cfn,ffn),
  ti = cfn;
else
  ti = sprintf('f=%s vs c=%s',ffn,cfn);
end

cd = load(fullfile(cpfd,[cfn,'.mat']));
PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,ti,'hax',haxcurr,'plottype',plottype,'limprctile',limprctile,'domatch',false);

drawnow;

fni = fni + 1;
[ci,ri] = ind2sub([nc,nr],fni);
haxcurr = hax(ri,ci);
ffn = 'wing_lengthr';
cfn = 'wing_areal';
fd0 = ftd.trk.data(:,:,fidx.(ffn));
fd = struct;
fd.data = cell(1,fnflies);
for i = 1:fnflies,
  fd.data{i} = fd0(i,ftrx(i).firstframe:ftrx(i).endframe);
end
if strcmp(cfn,ffn),
  ti = cfn;
else
  ti = sprintf('f=%s vs c=%s',ffn,cfn);
end
cd = load(fullfile(cpfd,[cfn,'.mat']));
PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,ti,'hax',haxcurr,'plottype',plottype,'limprctile',limprctile,'domatch',false);

drawnow;

fni = fni + 1;
[ci,ri] = ind2sub([nc,nr],fni);
haxcurr = hax(ri,ci);
ffn = 'wing_lengthl';
cfn = 'wing_arear';
fd0 = ftd.trk.data(:,:,fidx.(ffn));
fd = struct;
fd.data = cell(1,fnflies);
for i = 1:fnflies,
  fd.data{i} = fd0(i,ftrx(i).firstframe:ftrx(i).endframe);
end
if strcmp(cfn,ffn),
  ti = cfn;
else
  ti = sprintf('f=%s vs c=%s',ffn,cfn);
end
cd = load(fullfile(cpfd,[cfn,'.mat']));
PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,ti,'hax',haxcurr,'plottype',plottype,'limprctile',limprctile,'domatch',false);

drawnow;

fni = fni + 1;
[ci,ri] = ind2sub([nc,nr],fni);
haxcurr = hax(ri,ci);
ffn = 'mean_wing_angle';
cfn = 'wing_trough_angle';
fn = cfn;
fd0 = -.5*modrange(ftd.trk.data(:,:,fidx.wing_anglel)+ftd.trk.data(:,:,fidx.wing_angler),-pi,pi);
fd = struct;
fd.data = cell(1,fnflies);
for i = 1:fnflies,
  fd.data{i} = fd0(i,ftrx(i).firstframe:ftrx(i).endframe);
end
if strcmp(cfn,ffn),
  ti = cfn;
else
  ti = sprintf('f=%s vs c=%s',ffn,cfn);
end
cd = load(fullfile(cpfd,[cfn,'.mat']));
PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,ti,'hax',haxcurr,'plottype',plottype,'limprctile',limprctile,'domatch',false);

drawnow;
  
