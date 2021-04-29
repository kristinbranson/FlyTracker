
% Helper function to run individual tracking jobs
function flag = tracker_job(type, varargin)
   % check job type
   flag = true;
   if (strcmp(type,'track_calibrate'))
      flag = tracker_job_calibrate(varargin{:});
   elseif (strcmp(type,'track_process'))
      flag = tracker_job_process(varargin{:});
   elseif (strcmp(type,'track_combine'))
      flag = tracker_job_combine(varargin{:});
   elseif (strcmp(type,'track_consolidate'))
      tracker_job_consolidate(varargin{:});
   elseif (strcmp(type,'track_features'))
      tracker_job_features(varargin{:});
   else
      % invalid job type
      flag = false;
   end
end

% Compute background model
function flag = tracker_job_calibrate(f_vid, f_bg, f_calib, options, parent_calib, vinfo, force_calib)

  if ~exist('force_calib','var')
    force_calib = false;
  end

  flag = 0;
  if force_calib || ~exist(f_bg,'file')
    % open info file
    if nargin < 5 || isempty(parent_calib)
        D = load(f_calib); parent_calib = D.calib;
    end
    % open video
    do_close = 0;
    reset_cache_size = 0;
    if nargin < 6 || isempty(vinfo)
        vinfo = video_open(f_vid,1);
        do_close = 1;
    else
        if isfield(vinfo,'mmread')
            cache_size = vinfo.mmread.cache.cache_size;
            vinfo.mmread.cache.cache_size = 1;
            reset_cache_size = 1;
        end
    end
    % compute frame range
    num_frames = options.fr_samp;
    fr.start = 1;
    fr.step = max(1,floor((vinfo.n_frames)./num_frames));
    fr.limit = vinfo.n_frames;
    % compute background model
    bg = calib_bg_estimate(vinfo, parent_calib.PPM, fr);
    if isnumeric(bg) && ~bg
        return;
    end
    if do_close
        video_close(vinfo);
    elseif reset_cache_size
        vinfo.mmread.cache.cache_size = cache_size;
    end
    % save background model
    save(f_bg,'bg');
  end
  % write calib-file
  if (force_calib || ~exist(f_calib,'file')),
    % initialize to be the same as parent
    calib = parent_calib;
    
    if parent_calib.auto_detect,
      
      % load background
      if ~exist('bg','var')
        D = load(f_bg); bg = D.bg;
      end
      if isempty(calib.r)
        shape = 'rectangular';
      else
        shape = 'circular';
      end
      % find new chambers and update structure
      [centers, r, w, h] = calib_chamber_detect(bg, calib.n_chambers, ...
        shape, calib.r, calib.w, calib.h);
      if numel(centers)==1 && ~centers
        return;
      end
      calib.centroids = centers;
      calib.r = r;
      calib.w = w;
      calib.h = h;
      
      if isfield(parent_calib,'arena_r_mm'),
        calib.PPM = calib.r / parent_calib.arena_r_mm;
      elseif isfield(parent_calib,'arena_w_mm'),
        calib.PPM = calib.w / parent_calib.arena_w_mm;
      elseif isfield(parent_calib,'arena_h_mm'),
        calib.PPM = calib.h / parent_calib.arena_h_mm;
      end
      
      masks = cell(1,size(centers,1));
      rois = cell(1,size(centers,1));
      full_mask = zeros(size(calib.full_mask));
      for i=1:size(centers,1)
        mask = zeros(size(calib.mask));
        if calib.roi_type == 1 % rectangular
          y1 = max(1,round(centers(i,1)-h/2));
          y2 = min(size(mask,1),round(centers(i,1)+h/2));
          x1 = max(1,round(centers(i,2)-w/2));
          x2 = min(size(mask,2),round(centers(i,2)+w/2));
          mask(y1:y2,x1:x2) = 1;
          rois{i} = round([y1 x1 y2-y1+1 x2-x1+1]);
        else                   % circulars
          [x,y] = ind2sub(size(mask),1:numel(mask));
          x = x - centers(i,1);
          y = y - centers(i,2);
          valid = x.^2 + y.^2 - r^2 < r;
          mask(valid) = 1;
          rois{i} = round([centers(i,1)-r centers(i,2)-r r*2 r*2]);
        end
        masks{i} = mask;
        full_mask = full_mask | mask;
      end
      calib.masks = masks;
      calib.mask = masks{1};
      calib.full_mask = full_mask;
    end
    save(f_calib,'calib');
  end
  flag = 1;
end

% Run detect,match,segment, and link, to obtain tracks for frame range (fr)
function flag = tracker_job_process(f_vid, f_bg, f_calib, f_trks, fr, vinfo)  
  flag = 0;
  % skip if output file exists
  if (exist(f_trks{end},'file'))
     flag = 1;
     return;
  end  
  % open video 
  do_close = 0;
  if nargin < 6 || isempty(vinfo)
    vinfo = video_open(f_vid);
    do_close = 1;
  end
  % load background model
  bg = load(f_bg); bg = bg.bg;
  % load information file
  calib = load(f_calib); calib = calib.calib;
  calib.mask = zeros(size(calib.mask));
  valid = find(calib.valid_chambers);
  n_chambers = numel(valid);  
  for c=1:n_chambers
      calib.mask = calib.mask | calib.masks{valid(c)};
  end
  calib_main = calib;
  % run detector
  dets = track_detect(vinfo,bg,calib,fr);
  if isnumeric(dets) && ~dets, return; end
  % close video
  if do_close, video_close(vinfo); end
  % process each chamber separately          
  for c=1:n_chambers      
      % skip if output file exists
      if (exist(f_trks{c},'file'))
         continue;
      end  
      % extract relevant detections
      if n_chambers == 1
          dets_c = dets;
          chamber_str = '';
      else
          chamber_str = ['c' num2str(c) ' - '];
          dets_c = dets{c};
      end
      calib = calib_main;
      % check whether detections agree with specified number of flies      
      n_frames = numel(dets_c.frame_ids);
      count_num_flies = zeros(1,n_frames);
      ferts = zeros(1,n_frames);
      for i=1:n_frames
          props = dets_c.frame_data{i}.body_props;       
          count_num_flies(i) = numel(props);
          ferts(i) = sum(detection_fertility(dets_c.frame_data{i},calib.params));
      end
      count_guess = prctile(sort(count_num_flies),95);
      fert_guess = prctile(sort(ferts),95);
      if isfield(calib,'n_flies_is_max'),
        n_flies_is_max = calib.n_flies_is_max;
      else
        n_flies_is_max = false;
      end
      if count_guess < calib.n_flies && (count_guess == fert_guess || n_flies_is_max),
        if count_guess ~= fert_guess,
          warning('Counting number of flies: count_guess %d != fert_guess %d. ',count_guess,fert_guess);
        end
        calib.n_flies = count_guess;
      end
      fprintf('n. flies = %d\n',calib.n_flies);
      % match detections into tracklets
      trks = track_match(dets_c,calib,chamber_str);
      if isnumeric(trks) && ~trks, return; end
      % segment foreground into bodyparts (wings, legs)
      trks = track_segment(trks,calib,1,chamber_str);
      if isnumeric(trks) && ~trks, return; end
      % link tracklets      
      trks = track_link(trks,calib);
      % save tracks
      save(f_trks{c},'trks','-v7.3')
  end
  % indicate that everything worked
  flag = 1;
end

% Join output of multiple chunks into a single file
function flag = tracker_job_combine(f_res, f_trk_list, f_calib, options, chamber_str)
  flag = 0;
  if exist(f_res,'file')
      flag = 1;
      return;
  end
  % load info
  calib = load(f_calib); calib = calib.calib;
  im_size = size(calib.mask);
  save_seg = 1; 
  if isfield(options,'save_seg'), save_seg = options.save_seg; end  
  % initialize waitbar
  steps = 0;  
  n_steps = numel(f_trk_list) + 1 + save_seg;
  display_available = feature('ShowFigureWindows');
  waitstr = [chamber_str 'Combining tracks'];
  if display_available
     multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
     waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
  end      

  % COMBINE TRACKS
  % count number of sequences and number of frames
  n_seq = 0;
  n_frm = options.startframe-1;
  n_seq_guess = numel(f_trk_list)*calib.n_flies;
  n_frm_guess = numel(f_trk_list)*options.granularity;      
  endframe_guess = n_frm_guess + options.startframe-1;
  % initialize combined tracks
  trk.frame_ids      = zeros([1 endframe_guess]);
  trk.frame_ids(1:options.startframe-1) = 1:options.startframe-1;
  trk.frame_seq_list = cell([endframe_guess 1]);
  trk.sequences      = cell([endframe_guess 1]);
  flags = [];
  if save_seg
      frame_data = cell([endframe_guess 1]);
  end      
  s = 0;
  f = options.startframe-1;
  for n = 1:numel(f_trk_list)
     % load partial track
     f_trk_curr = f_trk_list{n};
     trk_curr = load(f_trk_curr);
     trk_curr = trk_curr.trks;
     % find swaps
     flags = [flags; trk_curr.flags];
     % update counts
     n_seq = n_seq + numel(trk_curr.sequences);
     n_frm = n_frm + numel(trk_curr.frame_ids);
     % store frame ids
     trk.frame_ids((f+1):(f+numel(trk_curr.frame_ids))) = ...
        trk_curr.frame_ids;
     % store frame sequence list, adjusting offsets
     for fnum = 1:numel(trk_curr.frame_seq_list)
        trk.frame_seq_list{f+fnum} = trk_curr.frame_seq_list{fnum} + s;
     end
     % store sequences, adjusting start and end times
     for snum = 1:numel(trk_curr.sequences)
        seq = trk_curr.sequences{snum};
        seq.time_start = seq.time_start + f;
        seq.time_end   = seq.time_end + f;
        trk.sequences{s+snum} = seq;
     end
     % store segmentation
     if save_seg
        frame_data((f+1):(f+numel(trk_curr.frame_ids))) = trk_curr.frame_data;
     end
     % update indices
     s = s + numel(trk_curr.sequences);
     f = f + numel(trk_curr.frame_ids);
     % update waitbar
     steps = steps + 1;
     if display_available   
        abort = multiWaitbar(waitstr,steps/n_steps);
        if abort, return; end
     end 
  end
  % update trk in case n_frm_guess and n_seq_guess were off
  trk.frame_ids      = trk.frame_ids(1:n_frm);  
  trk.frame_seq_list = trk.frame_seq_list(1:n_frm);
  trk.sequences      = trk.sequences(1:n_seq);
  if save_seg 
      frame_data = frame_data(1:n_frm);
  end
  % link tracks
  trk = track_link(trk,calib);
  % make sure flag sequences correspond to the linked sequences
  chunk = options.granularity;
  valid = find(mod(trk.stitch_gaps(:,2),chunk) == 0 & ...
      trk.stitch_gaps(:,1)-trk.stitch_gaps(:,2) == 1);  %look only at chunk intersections
  for v=1:numel(valid)
    i = valid(v);
    inds = find(flags(:,3) > chunk*v & flags(:,4) <= chunk*(v+1));
    [~,seq_idx] = sort(trk.stitch_seq_map{i}(calib.n_flies+1:end));
    map = trk.stitch_seqs{i}(calib.n_flies+1:end);
    seq_map = map(seq_idx);
    flags(inds,1:2) = seq_map(flags(inds,1:2));
  end
  % order sequences such that the lower id is first 
  flagSeqs = flags(:,1:2);
  flags(:,1:2) = [min(flagSeqs,[],2) max(flagSeqs,[],2)];                     
  trk.flags = flags; %%TODO union with current trk.flags?
  % check whether coordinates need to be adjusted to roi
  adjust = 0;
  if isfield(trk_curr,'roi') 
      shift = [trk_curr.roi(2)-1 trk_curr.roi(1)-1];
      roi_size = [trk_curr.roi(3)-trk_curr.roi(1)+1 ...
          trk_curr.roi(4)-trk_curr.roi(2)+1];
      if sum(roi_size==im_size) < 2  
        adjust = 1;
      end
  end      
  % gather sequences to data matrix
  n_objs = numel(trk.sequences);
  n_frames = numel(trk.frame_ids);
  trk.names = trk_curr.names;
  n_feats = numel(trk.names);  
  trk.data = nan(n_objs,n_frames,n_feats);
  for s=1:n_objs
      frames = trk.sequences{s}.time_start:trk.sequences{s}.time_end;
      trk.data(s,frames,:) = trk.sequences{s}.track;
  end
  % adjust roi cropped coordinates
  if adjust
      trk.data(:,:,[1 10 12 18:2:28]) = trk.data(:,:,[1 10 12 18:2:28]) + shift(1);
      trk.data(:,:,[2 11 13 19:2:29]) = trk.data(:,:,[2 11 13 19:2:29]) + shift(2);
  end
  % remove unnecessary fields from trk
  trk_full = trk; trk = [];
  trk.names = trk_full.names;
  trk.data  = trk_full.data;      
  trk.flags = trk_full.flags;      
  if sum(abs(trk_full.frame_ids - (0:size(trk.data,2)-1))) ~= 0
      trk.frame_ids = trk_full.frame_ids;          
  end
  % update waitbar
  steps = steps + 1;
  if display_available   
     abort = multiWaitbar(waitstr,steps/n_steps);
     if abort, return; end
  end  
  
  % COMBINE SEGMENTATION
  if save_seg
      seg = cell(n_frm,1);
      for f=options.startframe:n_frm
          flies = cell(1,numel(trk_full.sequences));
          for c=1:numel(trk_full.sequences)
              flies{c}.body = [];
              flies{c}.wings = [];
              flies{c}.legs = [];
              flies{c}.rem = [];
              fr = f-trk_full.sequences{c}.time_start + 1;
              if fr < 1, continue; end
              if fr > numel(trk_full.sequences{c}.obj_list), continue; end
              obj_id = trk_full.sequences{c}.obj_list(fr);
              if obj_id == 0, continue; end
              flies{c}.body = frame_data{f}.body_cc.PixelIdxList{obj_id};
              flies{c}.wings = frame_data{f}.seg.body_wing_pixels{obj_id};
              flies{c}.legs = frame_data{f}.seg.body_leg_pixels{obj_id};
              fg_id = frame_data{f}.body_fg(obj_id);
              fg_pix = frame_data{f}.fg_cc.PixelIdxList{fg_id};
              fg_pix = setdiff(fg_pix,flies{c}.body);
              fg_pix = setdiff(fg_pix,flies{c}.wings);
              fg_pix = setdiff(fg_pix,flies{c}.legs);
              flies{c}.rem = fg_pix;
              % adjust roi cropped coordinates
              if adjust
                  [I,J] = ind2sub(roi_size, flies{c}.body);
                  flies{c}.body = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.wings);
                  flies{c}.wings = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.legs);
                  flies{c}.legs = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.rem);
                  flies{c}.rem = sub2ind(im_size,I+shift(2),J+shift(1));
              end
          end
          seg{f} = flies;
      end          
      clear frame_data
      % update waitbar
      steps = steps + 1;
      if display_available   
         abort = multiWaitbar(waitstr,steps/n_steps);
         if abort, return; end
      end       
  end   
  
  % AUTOMATIC ID CORRECTION
  try
      [trk,swaps] = track_auto_id(trk);  
  catch err
      disp(err)
      disp('Warning: Could not auto correct ids, classifier binaries may be missing for your OS.')
      swaps = [];
  end
  if size(swaps,1) > 0 && save_seg
      % udpate segmentation according to swaps
      for i=1:size(swaps,1)
        fly1 = swaps(i,1);
        fly2 = swaps(i,2);
        frame = swaps(i,3);
        for f=frame:numel(seg)
            tmp = seg{f}{fly1};
            seg{f}{fly1} = seg{f}{fly2};
            seg{f}{fly2} = tmp;
        end
      end      
  end
  % order flies based on their size
  areas = nanmean(trk.data(:,:,6),2);
  [~,sortids] = sort(areas,'ascend');
  trk.data = trk.data(sortids,:,:);
  if save_seg
      for f=options.startframe:n_frames
        seg{f} = seg{f}(sortids);
      end
  end
  map = zeros(size(sortids));
  map(sortids) = 1:numel(sortids);
  trk.flags(:,1:2) = map(trk.flags(:,1:2)); 
  % save files
  save(f_res,'trk'); %save([f_res(1:end-10) '-swaps.mat'],'swaps');  
  if save_seg      
     save([f_res(1:end-10) '-seg.mat'],'seg','-v7.3'); 
  end    
  % delete temp chunk files
  for n=1:numel(f_trk_list)
      f_trk_curr = f_trk_list{n};
      delete(f_trk_curr);
  end          
  % close waitbar
  if display_available
    multiWaitbar(waitstr,'Close');
    drawnow
  end  
  % indicate that everything worked
  flag = 1;
end

% Join results of multiple chambers 
function tracker_job_consolidate(f_res, f_res_list, options)
  n_chambers = numel(f_res_list);      
  save_seg = 0;  
  if isfield(options,'save_seg'), save_seg = options.save_seg; end
  
  % CONSOLIDATE TRACKS
  D = load(f_res_list{1});
  trk.names = D.trk.names;
  n_frames = size(D.trk.data,2);
  n_fields = size(D.trk.data,3);
  flies = zeros(1,n_chambers);
  all_data = cell(1,n_chambers);
  flags_c = cell(1,n_chambers);
  flies_in_chamber = cell(1,n_chambers);
  n_flags = 0;
  for i=1:n_chambers
      D = load(f_res_list{i});
      all_data{i} = D.trk.data;
      flags_c{i} = D.trk.flags;
      flies(i) = size(D.trk.data,1);
      n_flags = n_flags + size(flags_c{i},1);
  end
  n_flies = sum(flies);
  % combine data and store ids of flies in chambers
  trk.data = zeros(n_flies,n_frames,n_fields);                
  count = 0;
  for i=1:n_chambers
      for t=1:flies(i)
          count = count + 1;
          for f=1:n_fields
            trk.data(count,:,f) = all_data{i}(t,:,f);
          end
          flies_in_chamber{i} = [flies_in_chamber{i} count];
      end
  end
  trk.flies_in_chamber = flies_in_chamber; 
  % combine flags
  flags = zeros(n_flags,6);
  count = 0;
  for i=1:n_chambers
      c_count = size(flags_c{i},1);
      flags_c{i}(:,1:2) = flies_in_chamber{i}(flags_c{i}(:,1:2));
      flags(count+(1:c_count),:) = flags_c{i};
      count = count + c_count;
  end
  trk.flags = flags;
  % save tracks
  save(f_res,'trk');
  % delete previous files
  for i=1:n_chambers
      delete(f_res_list{i});
  end          

  % CONSOLIDATE SEGMENTATION 
  if save_seg
    f_res_seg = [f_res(1:end-10) '-seg.mat']; 
    try
        segfile = [f_res_list{1}(1:end-10) '-seg.mat'];
        D = load(segfile); 
        n_frames = numel(D.seg);
        seg = cell(n_frames,1);
        for i=1:n_chambers
            segfile = [f_res_list{i}(1:end-10) '-seg.mat'];
            D = load(segfile);
            for f=1:n_frames
                seg{f} = [seg{f} D.seg{f}];
            end
        end
        save(f_res_seg,'seg','-v7.3')

        % delete previous files
        for i=1:n_chambers
            segfile = [f_res_list{i}(1:end-10) '-seg.mat'];
            delete(segfile);
        end
    catch
        disp('could not write segmentation file')
    end
  end  
end

% Compute features from tracking data
function tracker_job_features(f_vid, f_res, f_calib, options, recompute)
  if nargin < 5 || isempty(recompute)
      recompute = 0;
  end
  calib = load(f_calib); calib = calib.calib;            

  % write feat file  
  featfile = [f_res(1:end-10) '-feat.mat'];
  if ~exist(featfile,'file') || recompute
    trk = load(f_res); trk = trk.trk;    
    feat = feat_compute(trk,calib);
    save(featfile,'feat');
  end

  % save xls files
  if options.save_xls
      xlsfile = [f_res(1:end-10) '-trackfeat'];
      if ~exist(xlsfile,'dir') || ~exist([xlsfile '.xls'],'file') || recompute
         if ~exist('trk','var')
            trk = load(f_res); trk = trk.trk;
         end
         if ~exist('feat','var')
            feat = load(featfile); feat = feat.feat;
         end
         names = [trk.names feat.names];
         data = nan(size(trk.data,1),size(trk.data,2),numel(names));
         data(:,:,1:size(trk.data,3)) = trk.data;
         data(:,:,size(trk.data,3)+(1:size(feat.data,3))) = feat.data;
         writeXls(xlsfile,data,names);
      end
  end  
  
  % write JAABA folders
  if options.save_JAABA
      JAABA_dir = [f_res(1:end-10) '-JAABA'];
      if (~exist(JAABA_dir,'dir') || recompute)      
         if ~exist('trk','var')
             trk = load(f_res); trk = trk.trk;
         end
         if ~exist('feat','var')
             feat = load(featfile); feat = feat.feat;
         end
         % augment features (with log, norms, and derivatives)
         feat = feat_augment(feat);      
         writeJAABA(f_res,f_vid,trk,feat,calib);
      end     
  end
 
end
