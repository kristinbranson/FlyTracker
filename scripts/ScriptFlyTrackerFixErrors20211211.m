addpath(genpath('/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/FlyTracker'));

expdir = '/groups/branson/home/bransonk/behavioranalysis/code/MABe2022/data/nochr_TrpA71G01_Unknown_RigA_20201216T153505';

intrxfile = fullfile(expdir,'movie_JAABA/trx.mat');
inflytrackerfile = fullfile(expdir,'movie-track.mat');
inbgfile = fullfile(expdir,'movie-bg.mat');
incalibfile = fullfile(expdir,'flytracker-calibration.mat');
inannfile = fullfile(expdir,'movie.ufmf.ann');

% give these as input to fixerrors
outtrxfile = fullfile(expdir,'movie_JAABA/tofixtrx.mat');
outcalibfile = fullfile(expdir,'movie_JAABA/tofixcalibration.mat');

PrepareFlyTracker4FixErrors(intrxfile,inflytrackerfile,inbgfile,incalibfile,inannfile,outtrxfile,outcalibfile);

fixerrors;

