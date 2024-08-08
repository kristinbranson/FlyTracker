function trks = track_choose_orientations(trks,calib)

if isfield(trks,'names'),
  oriidx = find(strcmp(trks.names,'ori'));
else
  oriidx = 3;
end

for s = 1:numel(trks.sequences),
  seq = trks.sequences{s};
  duration = seq.time_end-seq.time_start+1;

  orientations = seq.track(:,oriidx);

  % orientations = nan(duration,1);
  % for t = seq.time_start:seq.time_end,
  %   ti = t-seq.time_start+1;
  %   fd = trks.frame_data{t};
  %   bodyi = find(trks.frame_seq_list{t}==s);
  %   if isempty(bodyi),
  %     continue;
  %   end
  %   orientations(ti) = fd.body_props(bodyi).Orientation/180*pi;
  % end

  appearancecost = seq.appearancecost;
  weight_theta = nan(size(orientations));
  weight_theta(:) = calib.params.choose_orientations_weight_theta;
  [new_orientations,~] = choose_orientations_generic(orientations,weight_theta,appearancecost);
  % for t = seq.time_start:seq.time_end,
  %   ti = t-seq.time_start+1;
  %   bodyi = find(trks.frame_seq_list{t}==s);
  %   if isempty(bodyi),
  %     continue;
  %   end
  %   trks.frame_data{t}.body_props(bodyi).Orientation = new_orientations(ti)*180/pi;
  % end  
  trks.sequences{s}.track(:,oriidx) = new_orientations;
  % if isfield(trks,'frame_data'),
  %   keyboard;
  % end
end
