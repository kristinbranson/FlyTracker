function flag = core_tracker_calibrate(output_calibration_file_name, output_background_file_name, ...
                                       input_video_file_name, input_background_file_name, input_calibration_file_name, ...
                                       options)
  % Compute background model

  if ~exist('force_calib','var')
    force_calib = false;
  end

  flag = 0;
  if force_calib || ~exist(input_background_file_name,'file')
    % open info file
    % open video
    do_close = 0;
    reset_cache_size = 0;
    if nargin < 6 || isempty(vinfo)
        vinfo = video_open(input_video_file_name,1);
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
    bg = calib_bg_estimate(vinfo, input_calibration_file_name.PPM, fr);
    if isnumeric(bg) && ~bg
        return;
    end
    if do_close
        video_close(vinfo);
    elseif reset_cache_size
        vinfo.mmread.cache.cache_size = cache_size;
    end
    % save background model
    save(input_background_file_name,'bg');
  end
  % write calib-file
  if (force_calib || ~exist(output_calibration_file_name,'file')),
    % initialize to be the same as parent
    calib = input_calibration_file_name;
    
    if input_calibration_file_name.auto_detect,
      
      % load background
      if ~exist('bg','var')
        D = load(input_background_file_name); bg = D.bg;
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
      
      if isfield(input_calibration_file_name,'arena_r_mm'),
        calib.PPM = calib.r / input_calibration_file_name.arena_r_mm;
      elseif isfield(input_calibration_file_name,'arena_w_mm'),
        calib.PPM = calib.w / input_calibration_file_name.arena_w_mm;
      elseif isfield(input_calibration_file_name,'arena_h_mm'),
        calib.PPM = calib.h / input_calibration_file_name.arena_h_mm;
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
    save(output_calibration_file_name,'calib');
  end
  flag = 1;
end
