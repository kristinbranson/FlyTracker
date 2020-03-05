function outexpdirs = PrepareSimTrx4JAABA(trxfiles,expdir0,varargin)

if ~iscell(trxfiles),
  trxfiles = {trxfiles};
end

[rootoutdir,dataloc_params,analysis_protocol,settingsdir,forcecompute] = ...
  myparse(varargin,'rootoutdir','',...
  'dataloc_params',[],...
  'analysis_protocol','current',...
  'settingsdir','/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/settings',...
  'forcecompute',false);

if isempty(dataloc_params),
  dataloc_params = ReadParams(fullfile(settingsdir,analysis_protocol,'dataloc_params.txt'));
  dataloc_params.flytrackertrackstr = 'movie-track.mat';
end

if isempty(rootoutdir),
  outexpdirs = cell(size(trxfiles));
  for moviei = 1:numel(trxfiles),
    [p,n] = fileparts(trxfiles{moviei});
    outexpdirs{moviei} = fullfile(p,n);
  end
else
  outexpdirs = cell(size(trxfiles));
  for moviei = 1:numel(trxfiles),
    [~,n] = fileparts(trxfiles{moviei});
    outexpdirs{moviei} = fullfile(rootoutdir,n);
  end
  assert(numel(unique(outexpdirs))==numel(outexpdirs));
end
for moviei = 1:numel(outexpdirs),
  if ~exist(outexpdirs{moviei},'dir'),
    mkdir(outexpdirs{moviei});
  end
end

td0 = load(fullfile(expdir0,dataloc_params.trxfilestr));
meddt = nanmedian(diff([td0.timestamps]));
t0 = min([td0.trx.firstframe]);

for moviei = 1:numel(outexpdirs),

  outexpdir = outexpdirs{moviei};
  intrxfile = trxfiles{moviei};
  
  outtrxfile = fullfile(outexpdir,dataloc_params.trxfilestr);
  td = load(intrxfile);
  outtd = struct;
  T = size(td.x,1);
  t1 = t0 + T - 1;
  outtd.timestamps = td0.timestamps(1) + meddt*(0:t1-1);
  outtd.trx = repmat(td0.trx(1),[1,size(td.x,2)]);
  medarea = nanmedian(td.a.*td.b,1);
  [~,order] = sort(medarea);
  nmale = round(size(td.x,2)/2);
  
  for i = 1:size(td.x,2),
    outtd.trx(i).firstframe = t0;
    outtd.trx(i).endframe = t0 + T - 1;
    outtd.trx(i).off = 1 - outtd.trx(i).firstframe;
    outtd.trx(i).nframes = T;
    outtd.trx(i).fps = 1/meddt;
    outtd.trx(i).id = i;
    if ismember(i,order(1:nmale)),
      outtd.trx(i).sex = 'm';
    else
      outtd.trx(i).sex = 'f';
    end
    outtd.trx(i).timestamps = outtd.timestamps(outtd.trx(i).firstframe:outtd.trx(i).endframe);
    outtd.trx(i).dt = diff(outtd.trx(i).timestamps);
    outtd.trx(i).x = td.x(:,i)';
    outtd.trx(i).y = td.y(:,i)';
    outtd.trx(i).theta = td.theta(:,i)';
    outtd.trx(i).a = td.a(:,i)';
    outtd.trx(i).b = td.b(:,i)';
    outtd.trx(i).x_mm = outtd.trx(i).x / outtd.trx(i).pxpermm;
    outtd.trx(i).y_mm = outtd.trx(i).y / outtd.trx(i).pxpermm;
    outtd.trx(i).a_mm = outtd.trx(i).a / outtd.trx(i).pxpermm;
    outtd.trx(i).b_mm = outtd.trx(i).b / outtd.trx(i).pxpermm;
    outtd.trx(i).theta_mm = outtd.trx(i).theta;
    
    outtd.trx(i).xwingl = outtd.trx(i).x + td.l_wing_len(:,i)'.*cos(outtd.trx(i).theta+pi+td.l_wing_ang(:,i)');
    outtd.trx(i).ywingl = outtd.trx(i).y + td.l_wing_len(:,i)'.*sin(outtd.trx(i).theta+pi+td.l_wing_ang(:,i)');
    outtd.trx(i).xwingr = outtd.trx(i).x + td.r_wing_len(:,i)'.*cos(outtd.trx(i).theta+pi+td.r_wing_ang(:,i)');
    outtd.trx(i).ywingr = outtd.trx(i).y + td.r_wing_len(:,i)'.*sin(outtd.trx(i).theta+pi+td.r_wing_ang(:,i)');

  end
  save(outtrxfile,'-struct','outtd');
  
end

%% compute some wing-related features from FlyTracker outputs
% wing-related features:
% wing_anglel <- -'wing l ang'
% wing_angler <- -'wing r ang'
% wing_areal <- 'wing l len'
% wing_arear <- 'wing r len'
% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2

for moviei = 1:numel(trxfiles),

  outexpdir = outexpdirs{moviei};
  intrxfile = trxfiles{moviei};
  SimTrx2WingTracking(outexpdir,intrxfile,expdir0,'dataloc_params',dataloc_params);
  
end

%% run FBComputePerFrameFeatures on outputs

for moviei = 1:numel(trxfiles),

  outexpdir = outexpdirs{moviei};
  FlyBowlComputePerFrameFeatures(outexpdir,'forcecompute',forcecompute);
  
end