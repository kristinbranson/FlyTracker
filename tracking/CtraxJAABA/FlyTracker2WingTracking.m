function outtrx = FlyTracker2WingTracking(expdir,varargin)

[dataloc_params,analysis_protocol,datalocparamsfilestr,settingsdir,perframe_params,ftfile] = ...
  myparse(varargin,'dataloc_params',[],...
  'analysis_protocol','current',...
  'datalocparamsfilestr','dataloc_params.txt',...
  'settingsdir','/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/settings',...
  'perframe_params',[],...
  'ftfile','');
if isempty(dataloc_params),
  dataloc_params = ReadParams(fullfile(settingsdir,analysis_protocol,datalocparamsfilestr));
  if ~isfield(dataloc_params,'flytrackertrackstr'),
    warning('flytrackertrackstr not set in %s/dataloc_params.txt, using default value movie-track.mat',settingsdir);
    dataloc_params.flytrackertrackstr = 'movie-track.mat';
  end
end

if isempty(perframe_params),
  perframe_params = ReadParams(fullfile(settingsdir,analysis_protocol,dataloc_params.perframeparamsfilestr));
end
if ~isfield(perframe_params,'fakectrax'),
  warning('perframe_params.fakectrax not set, using default value true');
  perframe_params.fakectrax = true;
end

trxfile = fullfile(expdir,dataloc_params.trxfilestr);
perframedir = fullfile(expdir,dataloc_params.perframedir);

if isempty(ftfile),
  ftfile = fullfile(expdir,dataloc_params.flytrackertrackstr);
end

% ftd = load(ftfile);
% intrx = load(trxfile);
% outtrx = intrx;
% nflies = numel(intrx.trx);
reginfo = load(fullfile(expdir,dataloc_params.registrationmatfilestr));

try
  registrationmatfile = fullfile(expdir,dataloc_params.registrationmatfilestr);
  load(registrationmatfile,'newid2oldid');
catch
  warning('Could not load newid2oldid from registration file, assuming flytracker data and trx data match');
  newid2oldid = [];
end

arena = struct;
arena.x = reginfo.circleCenterX;
arena.y = reginfo.circleCenterY;
arena.r = reginfo.circleRadius;

annfile = fullfile(expdir,dataloc_params.annfilestr);
outtrxfile = fullfile(expdir,dataloc_params.wingtrxfilestr);
outtrx = FlyTracker2WingTracking_helper(ftfile,trxfile,perframedir,outtrxfile,perframe_params,arena,newid2oldid,annfile);

