function FlyTrackerWrapper(outmoviefile,num_cores,options)

p = mfilename('fullpath');
p = fileparts(p);
addpath(genpath(p));

if nargin < 2 || isempty(num_cores),
  num_cores = maxNumCompThreads;
else
  num_cores = min(num_cores,maxNumCompThreads);
end
fprintf('num_cores = %d\n',num_cores);

options_def.num_cores   = num_cores;
options_def.num_chunks = options_def.num_cores*2;
options_def.save_JAABA  = true;
options_def.save_xls    = false;
options_def.save_seg    = false;
options_def.f_parent_calib = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/calibration20190712.mat';
options_def.force_calib = true;
options_def.expdir_naming = true;
options_def.fr_samp = 200;
options_def.forcecompute = true;
options_def.n_flies_is_max = true;

if ~exist('options','var'),
  options = struct;
end
fns = setdiff(fieldnames(options_def),fieldnames(options));
for i = 1:numel(fns),
  options.(fns{i}) = options_def.(fns{i});
end

vinfo = video_open(outmoviefile);
tracker([], options, [], vinfo);
