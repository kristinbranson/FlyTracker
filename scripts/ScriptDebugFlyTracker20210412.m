%expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/socialCsChr_GMR_72C11_AE_01_CsChrimson_RigD_20191114T172654';
%expdir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/socialCsChr_GMR_72C11_AE_01_CsChrimson_RigD_20191114T172654';
%expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/nochr_TrpA71G01_Unknown_RigA_20201216T162938';

% alice data for which orientation errors have been identified
expdir0 = '/groups/branson/home/robiea/Projects_data/FlyDisco/Bubble_data/nochr_TrpApBDP_Unknown_RigB_20201216T160731';
calibfile0 = '/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/settings/current_non_olympiad_dickson_VNC/parent_calibration_bubble20210218.mat';
calibfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/parent_calibration_bubble_dickson_VNC_20210413.mat';
trkfile0 = fullfile(expdir0,'flytracker','movie','movie-track.mat');

% katie's RGB bowl
expdir0 = '/groups/branson/bransonlab/flydisco_example_experiments_read_only/FlyBowlRGB/20210401T134552_rig1_flyBowl4__aIPgSS1UASCsChrimson_KS_redonly_protocolRGB_0315_2';
calibfile0 = '/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/settings/20210329_flybubble_FlyBowlRGB_LED/flytracker-parent-calibration_20210329.mat';
calibfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/parent_calibration_bubble_FlyBowlRGB_LED_20210413.mat';
trkfile0 = '';

% ming's bowl
expdir0 = '/groups/branson/bransonlab/flydisco_example_experiments_read_only/FlyBowlOpto/SS36564_20XUAS_CsChrimson_mVenus_attP18_flyBowlMing_20200227_Continuous_2min_5int_20200107_20200229T132141';
calibfile0 = '/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/settings/20190712_flybubble_flybowloptoKatie_mingrig_flytracker/flytracker-parent-calibration.mat';
calibfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data/parent_calibration_bubble_mingrig_20210413.mat';
trkfile0 = '';

datadir = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/Data';
[~,expname] = fileparts(expdir0);
expdir = fullfile(datadir,expname);
if ~exist(expdir,'dir'),
  mkdir(expdir);
  unix(sprintf('ln -s %s/movie.ufmf %s/movie.ufmf',expdir0,expdir));
end
disp(expdir);

%% add new calib params

if ~exist(calibfile,'file'),
  if isempty(trkfile0),
    
    calibfile1 = fullfile(expdir,'calibration.mat');
    if ~exist(calibfile1,'file'),
      fprintf('Calibrate video now!\n');
      keyboard;
    end
    
    tmp1 = load(calibfile1);
    tmp2 = load(calibfile0);
    fprintf('original ppm = %f, new = %f\n',tmp2.calib.PPM,tmp1.calib.PPM);
    fns = setdiff(fieldnames(tmp1.calib.params),fieldnames(tmp2.calib.params));
    for i = 1:numel(fns),
      tmp2.calib.params.(fns{i}) = tmp1.calib.params.(fns{i});
    end
    save(calibfile,'-struct','tmp2');
    
  else
    
    load(calibfile0);
    load(trkfile0);
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
  end
end

%%
load(calibfile);

options = struct;
options.num_cores   = 1;
options.num_chunks = [];
options.save_JAABA  = true;
options.save_xls    = false;
options.save_seg    = false;
options.force_calib = true;
options.expdir_naming = true;
options.fr_samp = 200;
options.max_minutes = 200/calib.FPS/60;
options.f_parent_calib = calibfile;
options.force_tracking = true;
options.force_features = true;
options.startframe = 3351;

outmoviefile = fullfile(expdir,'movie.ufmf');
FlyTrackerWrapper(outmoviefile,options.num_cores,options);


%% 
trx = load_tracks(fullfile(expdir,'movie_JAABA','trx.mat'));

figure(11);
clf;
hold on;
for i = 1:numel(trx),
  
  dtheta = modrange(diff(trx(i).theta),-pi,pi)/calib.FPS;
  [maxv,f] = max(abs(dtheta));
  fprintf('Fly %d, frame %d, dtheta = %f\n',i,f,maxv);
  plot(trx(i).firstframe:trx(i).endframe-1,dtheta);
  
end