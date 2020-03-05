function SimTrx2WingTracking(expdir,intrxfile,expdir0,varargin)

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

std = load(intrxfile);
intrx = load(trxfile);
outtrx = intrx;
nflies = numel(intrx.trx);
reginfo = load(fullfile(expdir0,dataloc_params.registrationmatfilestr));

[outtrx.trx.annname] = deal(fullfile(expdir0,dataloc_params.annfilestr));
arena = struct;
arena.x = reginfo.circleCenterX;
arena.y = reginfo.circleCenterY;
arena.r = reginfo.circleRadius;
[outtrx.trx.arena] = deal(arena);

for i = 1:numel(outtrx.trx),
  outtrx.trx(i).wing_anglel = std.l_wing_ang(:,i);
  outtrx.trx(i).wing_angler = std.r_wing_ang(:,i);
end

outtrxfile = fullfile(expdir,dataloc_params.wingtrxfilestr);
save(outtrxfile,'-struct','outtrx');

if ~exist(perframedir,'dir'),
  mkdir(perframedir);
end

% wing_anglel <- -'wing l ang'
cfn = 'wing_anglel';
ffn = 'l_wing_ang';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = std.(ffn)(:,i)';
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

% wing_angler <- -'wing r ang'
cfn = 'wing_angler';
ffn = 'r_wing_ang';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = std.(ffn)(:,i)';
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

% wing_areal <- 'wing l len'
ffn = 'r_wing_len';
cfn = 'wing_arear';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = std.(ffn)(:,i)';
end
units.num = {'px^2'};
units.den = cell(1,0);
notes = sprintf('This is actually %s, units are actually mm',ffn);
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% wing_arear <- 'wing r len'
ffn = 'l_wing_len';
cfn = 'wing_areal';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = std.(ffn)(:,i)';
end
units.num = {'px^2'};
units.den = cell(1,0);
notes = sprintf('This is actually %s, units are actually mm',ffn);
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2
cfn = 'wing_trough_angle';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = -.5*modrange(std.l_wing_ang(:,i)'+std.r_wing_ang(:,i)',-pi,pi);
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

