% PrepareFlyTracker4FixErrors(intrxfile,inflytrackerfile,inbgfile,incalibfile,inannfile,outtrxfile,outcalibfile)
% intrxfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie_JAABA/trx.mat';
% inflytrackerfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie-track.mat'
% inbgfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie-bg.mat'
% incalibfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/calibration.mat'
% inannfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie.ufmf.ann'
% outtrxfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie_JAABA/tofixtrx.mat'
% outcalibfile = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027/movie_JAABA/tofixcalibration.mat'
function PrepareFlyTracker4FixErrors(intrxfile,inflytrackerfile,inbgfile,incalibfile,inannfile,outtrxfile,outcalibfile)

td = load(intrxfile);
trx = td.trx;
nflies = numel(trx);

fnsremove = {'dt','xwingl','ywingl','xwingr','ywingr','x_mm','y_mm','a_mm','b_mm','theta_mm'};
fns = fieldnames(trx);
trx = rmfield(trx,intersect(fns,fnsremove));

ftd = load(inflytrackerfile);

%% add in wing features

fidx = struct;
fidx.wing_anglel = find(strcmp(ftd.trk.names,'wing l ang'));
fidx.wing_angler = find(strcmp(ftd.trk.names,'wing r ang'));
fidx.wing_lengthl = find(strcmp(ftd.trk.names,'wing l len'));
fidx.wing_lengthr = find(strcmp(ftd.trk.names,'wing r len'));

for i = 1:numel(trx),
  trx(i).wing_anglel = ftd.trk.data(i,trx(i).firstframe:trx(i).endframe,fidx.wing_anglel);
  trx(i).wing_angler = ftd.trk.data(i,trx(i).firstframe:trx(i).endframe,fidx.wing_angler);
  trx(i).wing_lengthl = ftd.trk.data(i,trx(i).firstframe:trx(i).endframe,fidx.wing_lengthl);
  trx(i).wing_lengthr = ftd.trk.data(i,trx(i).firstframe:trx(i).endframe,fidx.wing_lengthr);
end

fns = fieldnames(trx);

%% everything should be columns
istrajfn = false(1,numel(fns));
for i = 1:numel(fns),
  fn = fns{i};
  % string
  if ischar(trx(1).(fn)),
    continue;
  end
  % scalars 
  if max(cellfun(@numel,{trx.(fn)})) == 1,
    continue;
  end
  
  % figure out which dimension corresponds to frames, if any
  sz1 = cellfun(@size,{trx.(fn)},'Uni',0);
  nd = max(cellfun(@numel,sz1));
  sz = nan(nflies,nd);
  for j = 1:nflies,
    sz(j,1:numel(sz1{j})) = sz1{j};
  end
  offnframes = cat(1,trx.nframes)-sz;
  % only one dimension that matches number of frames
  idx = find(all(offnframes==0,1));
  if numel(idx) ~= 1,
    % offsets between 0 and 3 allowed as long as they match for all flies
    idx = find(offnframes(1,:)>=0 & offnframes(1,:) <= 3 & all(offnframes==offnframes(1,:),1));
    if numel(idx) ~= 1,
      continue;
    end
  end
  istrajfn(i) = true;
  if idx == 2,
    continue;
  end
  if idx == 1,
    order = [2,1,3:nd];
  else
    order = [1,idx,2:idx-1,idx+1:nd];
  end
  fprintf('Reordering field %s to %s\n',fn,num2str(order));
  for j = 1:nflies,
    trx(j).(fn) = permute(trx(j).(fn),order);
  end
  
end

%% split trajectories at nans

trajfns = fns(istrajfn);
trajfns = setdiff(trajfns,{'timestamps'});

newtrx = [];
for i = 1:nflies,
  datacurr = trx(i).x;
  ismissing = isnan(datacurr);
  if ~any(ismissing),
    trkcurr = trx(i);
    trkcurr.id = numel(newtrx)+1;
    newtrx = structappend(newtrx,trkcurr);
    continue;
  end
  [t0s,t1s] = get_interval_ends(~ismissing);
  t1s = t1s-1;
  t0s = t0s + trx(i).firstframe-1;
  t1s = t1s + trx(i).firstframe-1;
  for j = 1:numel(t0s),
    trkcurr = fix_GetPartOfTrack(trx(i),t0s(j),t1s(j),trajfns);
    trkcurr.id = numel(newtrx)+1;
    fprintf('Fly %d, interval %d -> new trajectory %d with %d frames (%d to %d)\n',...
      i,j,trkcurr.id,trkcurr.nframes,trkcurr.firstframe,trkcurr.endframe);
    newtrx = structappend(newtrx,trkcurr);
  end
end


%% save output

td.trx = newtrx;
save(outtrxfile,'-struct','td');

%% parameters, replacing ann file

bgd = load(inbgfile);
calibd = load(incalibfile);
calibd.bg_mean = bgd.bg.bg_mean;
if bgd.bg.invert,
  calibd.bg_mean = 1 - calibd.bg_mean;
end
[calibd.ann.center_dampen,calibd.ann.angle_dampen,calibd.ann.ang_dist_wt,...
  calibd.ann.max_jump,calibd.ann.model_type,calibd.ann.bgthresh,...
  calibd.ann.maxmajor,calibd.ann.meanmajor,...
  calibd.ann.n_bg_std_thresh_low] = ...
  read_ann(inannfile,'center_dampen','angle_dampen','ang_dist_wt','max_jump',...
  'bg_type','n_bg_std_thresh_low','maxmajor','meanmajor','n_bg_std_thresh_low');
if calibd.ann.bgthresh >= 1,
  calibd.bg_mean = calibd.bg_mean * 255;
end
calibd.bg_mean = permute(calibd.bg_mean,[2,1,3]);
save(outcalibfile,'-struct','calibd');
