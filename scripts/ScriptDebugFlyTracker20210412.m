%expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/socialCsChr_GMR_72C11_AE_01_CsChrimson_RigD_20191114T172654';
%expdir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/socialCsChr_GMR_72C11_AE_01_CsChrimson_RigD_20191114T172654';
%expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/nochr_TrpA71G01_Unknown_RigA_20201216T162938';
expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/nochr_TrpApBDP_Unknown_RigB_20201216T160731';

datadir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data';
[~,expname] = fileparts(expdir0);
expdir = fullfile(datadir,expname);
if ~exist(expdir,'dir'),
  mkdir(expdir);
  unix(sprintf('ln -s %s/movie.ufmf %s/movie.ufmf',expdir0,expdir));
end
disp(expdir);
calibfile0 = '/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/settings/current_non_olympiad_dickson_VNC/parent_calibration_bubble20210218.mat';
calibfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/parent_calibration_bubble20210413.mat';

%% add new calib params
load(calibfile0);
load(fullfile(expdir0,'flytracker','movie','movie-track.mat'));
areai = find(strcmpi(trk.names,'body area'));
maji = find(strcmpi(trk.names,'major axis len'));
mini = find(strcmpi(trk.names,'minor axis len'));
body_sizes = trk.data(:,:,[maji,mini,areai]);
body_sizes = reshape(body_sizes,[size(body_sizes,1)*size(body_sizes,2),3]);
quartiles1 = prctile(body_sizes,25,1);
quartiles2 = prctile(body_sizes,75,1);
calib.params.quartile_major_axis = [quartiles1(1),quartiles2(1)];
calib.params.quartile_minor_axis = [quartiles1(2),quartiles2(2)];
calib.params.quartile_area = [quartiles1(3),quartiles2(3)];

calib.params.choose_orientations_weight_theta = .2*calib.FPS/(2*pi);
vel_fil_w = ceil(calib.FPS/30); % filter for computing velocities
calib.params.vel_fil = normpdf(linspace(-2,2,vel_fil_w));
calib.params.vel_fil = calib.params.vel_fil / sum(calib.params.vel_fil);
calib.params.vel_fil = conv([-1,0,1]/2,calib.params.vel_fil)';
save(calibfile,'calib');

%%

options = struct;
%options.num_cores   = 1;
options.num_chunks = [];
options.save_JAABA  = true;
options.save_xls    = false;
options.save_seg    = false;
options.force_calib = true;
options.expdir_naming = true;
options.fr_samp = 200;
%options.max_minutes = .02;
options.f_parent_calib = calibfile;
options.force_tracking = true;
options.force_features = true;
%options.startframe = 30921;

outmoviefile = fullfile(expdir,'movie.ufmf');
FlyTrackerWrapper(outmoviefile,[],options);

trx = load_tracks(fullfile(expdir,'movie_JAABA','trx.mat'));

clf;
hold on;
for i = 1:numel(trx),
  
  dtheta = modrange(diff(trx(i).theta),-pi,pi);
  [maxv,f] = max(abs(dtheta));
  fprintf('Fly %d, frame %d, dtheta = %f\n',i,f,maxv);
  plot(trx(i).firstframe:trx(i).endframe-1,dtheta);
  
end