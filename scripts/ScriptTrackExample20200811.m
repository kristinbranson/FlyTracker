%% example code to run fly tracker

inexpdir = '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027';
rootoutdir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/sampledata';
codedir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5';
addpath(genpath('.'));
moviestr = 'movie.ufmf';
num_cores = maxNumCompThreads;

%% copy directory

[~,expname] = fileparts(inexpdir);
outexpdir = fullfile(rootoutdir,expname);
if ~exist(outexpdir,'dir'),
  unix(sprintf('cp -r %s %s',inexpdir,outexpdir));
end

%% OPTION 1: track locally
  
moviefile = fullfile(outexpdir,moviestr);
[~,vidname] = fileparts(moviestr);
trkfile = fullfile(outexpdir,[vidname '-track.mat']);

FlyTrackerWrapper(moviefile,num_cores);

%% OPTION 2: track on the cluster with ssh + bsub

jobid = sprintf('FT_%s',expname);
logfile = fullfile(outexpdir,'FlyTracker.log');
shfile = fullfile(outexpdir,'FlyTracker.sh');
fid = fopen(shfile,'w');
fprintf(fid,'cd %s; matlab -nodisplay -r "FlyTrackerWrapper(''%s'',%d)"',codedir,outmoviefile,ncores);
fclose(fid);
unix(sprintf('chmod u+x %s',shfile));
cmd2 = sprintf('bsub -n %d -R"affinity[core(1)]" -o %s -J %s "%s"',ncores,logfile,jobid,shfile);
cmd3 = sprintf('ssh login1 ''source /etc/profile; %s''',cmd2);
unix(cmd3);

