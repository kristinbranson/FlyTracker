function FlyTracker2WingTracking(expdir,varargin)

[dataloc_params,analysis_protocol,settingsdir] = ...
  myparse(varargin,'dataloc_params',[],...
  'analysis_protocol','current',...
  'settingsdir','/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/settings');
if isempty(dataloc_params),
  dataloc_params = ReadParams(fullfile(settingsdir,analysis_protocol,'dataloc_params.txt'));
  dataloc_params.flytrackertrackstr = 'movie-track.mat';
end

trxfile = fullfile(expdir,dataloc_params.trxfilestr);
perframedir = fullfile(expdir,dataloc_params.perframedir);

ftd = load(fullfile(expdir,dataloc_params.flytrackertrackstr));
intrx = load(trxfile);
outtrx = intrx;
nflies = numel(intrx.trx);
reginfo = load(fullfile(expdir,dataloc_params.registrationmatfilestr));

[outtrx.trx.annname] = deal(fullfile(expdir,dataloc_params.annfilestr));
arena = struct;
arena.x = reginfo.circleCenterX;
arena.y = reginfo.circleCenterY;
arena.r = reginfo.circleRadius;
[outtrx.trx.arena] = deal(arena);

fidx = struct;
fidx.wing_anglel = find(strcmp(ftd.trk.names,'wing l ang'));
fidx.wing_angler = find(strcmp(ftd.trk.names,'wing r ang'));
fidx.wing_lengthl = find(strcmp(ftd.trk.names,'wing l len'));
fidx.wing_lengthr = find(strcmp(ftd.trk.names,'wing r len'));

for i = 1:numel(outtrx.trx),
  outtrx.trx(i).wing_anglel = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel);
  outtrx.trx(i).wing_angler = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler);
end

outtrxfile = fullfile(expdir,dataloc_params.wingtrxfilestr);
save(outtrxfile,'-struct','outtrx');

if ~exist(perframedir,'dir'),
  mkdir(perframedir);
end

% wing_anglel <- -'wing l ang'
fn = 'wing_anglel';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[fn,'.mat']),'data','units');

% wing_angler <- -'wing r ang'
fn = 'wing_angler';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[fn,'.mat']),'data','units');

% wing_areal <- 'wing l len'
ffn = 'wing_lengthr';
cfn = 'wing_arear';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
units.num = {'px^2'};
units.den = cell(1,0);
notes = sprintf('This is actually %s, units are actually mm',ffn);
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% wing_arear <- 'wing r len'
ffn = 'wing_lengthl';
cfn = 'wing_areal';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
units.num = {'px^2'};
units.den = cell(1,0);
notes = sprintf('This is actually %s, units are actually mm',ffn);
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2
cfn = 'wing_trough_angle';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = -.5*modrange(ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel)+...
    ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),-pi,pi);
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

% n wings detected: 2
cfn = 'nwingsdetected';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = 2+zeros(1,outtrx.trx(i).nframes);
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

