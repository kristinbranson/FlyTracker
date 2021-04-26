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

if ~exist('options','var'),
  options.num_cores   = num_cores;
  options.num_chunks = options.num_cores*2;
  options.save_JAABA  = true;
  options.save_xls    = false;
  options.save_seg    = false;
  options.f_parent_calib = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/calibration20190712.mat';
  options.force_calib = true;
  options.expdir_naming = true;
  options.fr_samp = 200;
  options.forcecompute = true;
elseif ~isfield(options,'num_cores'),
  options.num_cores = num_cores;
end

vinfo = video_open(outmoviefile);
tracker([], options, [], vinfo);
