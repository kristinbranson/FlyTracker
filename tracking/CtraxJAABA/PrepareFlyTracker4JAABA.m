function PrepareFlyTracker4JAABA(expdirs,varargin)

if ~iscell(expdirs),
  expdirs = {expdirs};
end

[rootoutdir,rootdatadir,dataloc_params,analysis_protocol,settingsdir,forcecompute] = ...
  myparse(varargin,'rootoutdir','',...
  'rootdatadir','',...
  'dataloc_params',[],...
  'analysis_protocol','current',...
  'settingsdir','/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/settings',...
  'forcecompute',false);

if isempty(dataloc_params),
  dataloc_params = ReadParams(fullfile(settingsdir,analysis_protocol,'dataloc_params.txt'));
  dataloc_params.flytrackertrackstr = 'movie-track.mat';
end

if isempty(rootoutdir),
  outexpdirs = expdirs;
else
  outexpdirs = cell(size(expdirs));
  for moviei = 1:numel(expdirs),
    expdir = expdirs{moviei};
    [~,expname] = fileparts(expdir);
    outexpdirs{moviei} = fullfile(rootoutdir,expname);
  end
end
if isempty(rootdatadir),
  expdirs0 = expdirs;
else
  expdirs0 = cell(size(expdirs));
  for moviei = 1:numel(expdirs),
    expdir = expdirs{moviei};
    [~,expname] = fileparts(expdir);
    expdirs0{moviei} = fullfile(rootdatadir,expname);
  end
end

for moviei = 1:numel(expdirs),

  outexpdir = outexpdirs{moviei};
  intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
  outtrxfile = fullfile(outexpdir,dataloc_params.ctraxfilestr);
  td = load(intrxfile);
  [~,~,fid,headerinfo] = get_readframe_fcn(fullfile(outexpdir,dataloc_params.moviefilestr));
  td.timestamps = headerinfo.timestamps'-headerinfo.timestamps(1);
  for i = 1:numel(td.trx),
    td.trx(i).timestamps = td.timestamps(td.trx(i).firstframe:td.trx(i).endframe)';
    td.trx(i).dt = diff(td.trx(i).timestamps);
  end
  fclose(fid);
  save(outtrxfile,'-struct','td');
  
  md = ReadMetadataFile(fullfile(expdir,dataloc_params.metadatafilestr));
  switch lower(md.gender),
    case 'm',
      fracmale = 1;
    case 'f',
      fracmale = 0;
    case 'b',
      fracmale = .5;
    otherwise,
      error('Unknown gender field in Metadata');
  end
  
  td = FlyTrackerClassifySex(outtrxfile,'fracmale',fracmale);
  
end

%% run FBRegisterTrx on FlyTracker outputs

for moviei = 1:numel(expdirs),

  expdir0 = expdirs0{moviei};
  outexpdir = outexpdirs{moviei};
  outannfile = fullfile(outexpdir,dataloc_params.annfilestr);
  outmetadatafile = fullfile(outexpdir,dataloc_params.metadatafilestr);
  
  if ~exist(outannfile,'file'),
    inannfile = fullfile(expdir0,dataloc_params.annfilestr);
    assert(exist(inannfile,'file')>0);
    cmd = sprintf('ln -s %s %s',inannfile,outannfile);
    unix(cmd);
  end
  if ~exist(outmetadatafile,'file'),
    inmetadatafile = fullfile(expdir0,dataloc_params.metadatafilestr);
    assert(exist(inmetadatafile,'file')>0);
    cmd = sprintf('cp %s %s/.',inmetadatafile,outexpdir);
    unix(cmd);
  end
  if isempty(dir(fullfile(outexpdir,dataloc_params.configfilepattern))),
    inprotocol = fullfile(expdir0,dataloc_params.configfilepattern);
    assert(~isempty(dir(inprotocol)));
    cmd = sprintf('cp %s %s/.',inprotocol,outexpdir);
    unix(cmd);
  end
%   intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
%   outtrxfile = fullfile(outexpdir,'ctrax_results.mat');
%   if ~exist(outtrxfile,'file'),
%     assert(exist(intrxfile,'file')>0);
%     cmd = sprintf('ln -s %s %s',intrxfile,outtrxfile);
%     unix(cmd);
%   end
  
  FlyBowlRegisterTrx(outexpdir);
  
end

% check that first frames and end frames match
for moviei = 1:numel(expdirs),

  if strcmp(expdirs{moviei},outexpdirs{moviei}),
    expdir0 = expdirs0{moviei};
  else
    expdir0 = expdirs{moviei};
  end
  outexpdir = outexpdirs{moviei};
  ftrxfile = fullfile(outexpdir,dataloc_params.trxfilestr);
  ftrx = load(ftrxfile);
  ctrxfile = fullfile(expdir0,dataloc_params.trxfilestr);
  ctrx = load(ctrxfile);
  ffirstframe = min([ftrx.trx.firstframe]);
  fendframe = max([ftrx.trx.endframe]);
  cfirstframe = min([ctrx.trx.firstframe]);
  cendframe = max([ctrx.trx.endframe]);
  assert(ffirstframe == cfirstframe && fendframe == cendframe);
  
end

%% compute some wing-related features from FlyTracker outputs
% wing-related features:
% wing_anglel <- -'wing l ang'
% wing_angler <- -'wing r ang'
% wing_areal <- 'wing l len'
% wing_arear <- 'wing r len'
% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2

for moviei = 1:numel(expdirs),

  outexpdir = outexpdirs{moviei};
  FlyTracker2WingTracking(outexpdir,'dataloc_params',dataloc_params);
  
end

%% run FBComputePerFrameFeatures on outputs

for moviei = 1:numel(expdirs),

  outexpdir = outexpdirs{moviei};
  FlyBowlComputePerFrameFeatures(outexpdir,'forcecompute',forcecompute);
  
end