ftd = load('Data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439/movie/movie-track.mat');
ctraxd = load('/nearline/branson/bowl_data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439/registered_trx.mat');
cald = load('Data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439/calibration.mat');

%% histogram major axis length

ctrs = linspace(2,9,100);
ai = find(strcmp(ftd.trk.names,'major axis len'));
fta = ftd.trk.data(:,:,ai)/4;
fta = fta(:);
ctraxa = [ctraxd.trx.a]';

ftfrac = hist(fta,ctrs)/numel(fta);
ctraxfrac = hist(ctraxa,ctrs)/numel(ctraxa);

hfig = 1;
figure(hfig);
clf;
h = plot(ctrs,[ftfrac;ctraxfrac]','.-');
legend(h, {'flytracker','ctrax'});
xlabel('quarter maj ax length');
ylabel('frac frames');

%% make calibration parameters
calib = cald.calib;
%calib.params.fly_comp = 1;
calib.arena_r_mm = 65;

save('parent_calibration.mat','calib');

%% 


%    videos.            - videos to process through tracking pipeline
%       dir_in          - directory containing input videos
%       dir_out         - directory in which to save results
%       filter          - file filter (eg '*.avi') (default: '*')
%       

videos = struct;
videos.dir_in = 'Data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439';
videos.dir_out = 'Data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439/test2';
videos.filter = 'movie.ufmf';
f_calib = 'Data/GMR_82E08_AE_01_TrpA_Rig1Plate15BowlD_20110921T110439/test/calibration.mat';
options = struct;
options.save_JAABA = true;
options.num_cores = feature('numCores');
options.f_parent_calib = 'parent_calibration.mat';
options.force_calib = true;
options.expdir_naming = true;
options.num_chunks = options.num_cores;

tracker(videos,options,f_calib);

%% 

ftrxfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653_JAABA/trx.mat';
ctrxfile = '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/registered_trx.mat';
moviefile = '/nearline/branson/bowl_data/GMR_71G01_AE_01_TrpA_Rig2Plate14BowlB_20110707T154653/movie.ufmf';
load(ctrxfile,'trx');
ctrx = trx;
load(ftrxfile,'trx');
ftrx = trx;

ctraxlabel_cell = cell(size(ctrx));
for fly = 1:numel(ctrx),
  ctraxlabel_cell{fly} = fly*100000+(1:ctrx(fly).nframes);
end

readframe = get_readframe_fcn(moviefile);
im = readframe(t);