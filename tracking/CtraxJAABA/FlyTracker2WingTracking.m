function FlyTracker2WingTracking(expdir,varargin)

[dataloc_params,analysis_protocol,datalocparamsfilestr,settingsdir,perframe_params] = ...
  myparse(varargin,'dataloc_params',[],...
  'analysis_protocol','current',...
  'datalocparamsfilestr','dataloc_params.txt',...
  'settingsdir','/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/settings',...
  'perframe_params',[]);
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

nwingsdetected = cell(1,nflies);
% remove nans
for i = 1:nflies,
  
  [ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel),...
    ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthl),...
    outtrx.trx(i).xwingl,outtrx.trx(i).ywingl,ismissingl] = ...
    FixWingNaNs(ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel),...
    ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthl),i);
  
  [ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),...
    ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthr),...
    outtrx.trx(i).xwingr,outtrx.trx(i).ywingr,ismissingr] = ...
    FixWingNaNs(ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),...
    ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthr),i);
  nwingsdetected{i} = double(~ismissingl) + double(~ismissingr);

end

% minus sign is important here!
for i = 1:numel(outtrx.trx),
  outtrx.trx(i).wing_anglel = -ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel);
  outtrx.trx(i).wing_angler = -ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler);
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
  data{i} = -ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[fn,'.mat']),'data','units');

% wing_angler <- -'wing r ang'
fn = 'wing_angler';
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = -ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
save(fullfile(perframedir,[fn,'.mat']),'data','units');

% fakectrax: wing_arear <- 'wing r len'
% ow: wing_lengthr <- wing r len
ffn = 'wing_lengthr';
if perframe_params.fakectrax,
  cfn = 'wing_arear';
  units.num = {'px^2'};
  units.den = cell(1,0);
  notes = sprintf('This is actually %s, units are actually mm',ffn);
else
  cfn = ffn;
  units.num = {'px'};
  units.den = cell(1,0);
  notes = '';
end  
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% fakectrax: wing_areal <- 'wing l len'
% ow: wing_lengthl <- wing l len
ffn = 'wing_lengthl';
if perframe_params.fakectrax,
  cfn = 'wing_areal';
  units.num = {'px^2'};
  units.den = cell(1,0);
  notes = sprintf('This is actually %s, units are actually mm',ffn);
else
  cfn = ffn;
  units.num = {'px'};
  units.den = cell(1,0);
  notes = '';
end  
data = cell(1,nflies);
for i = 1:nflies,
  data{i} = ftd.trk.data(i,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
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

% n wings detected
cfn = 'nwingsdetected';
data = nwingsdetected;
% data = cell(1,nflies);
% for i = 1:nflies,
%   data{i} = 2+zeros(1,outtrx.trx(i).nframes);
% end
units.num = {'unit'};
units.den = cell(1,0);
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

  function [angle,l,x,y,ismissing] = FixWingNaNs(angle,l,i)
    
    ismissing_angle = isnan(angle);
    ismissing_l = isnan(l);
    
    % fill with zeros
    angle(ismissing_angle) = 0;
    
    % interpolate
    if any(ismissing_l),
      l(ismissing_l) = interp1(find(~ismissing_l),l(~ismissing_l),find(ismissing_l));
    end
    
    ismissing = ismissing_l | ismissing_angle;
    
    x = outtrx.trx(i).x + l.*cos(outtrx.trx(i).theta + pi-angle);
    y = outtrx.trx(i).y + l.*sin(outtrx.trx(i).theta + pi-angle);

  end

end
