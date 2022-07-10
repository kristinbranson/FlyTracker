function flag = tracker_job_process(f_vid, f_bg, f_calib, f_trks, fr, options)  
  % Run detect,match,segment, and link, to obtain tracks for frame range (fr)
  flag = 0;
  % skip if output file exists
  if (exist(f_trks{end},'file'))
     flag = 1;
     return;
  end  
  % open video 
  vinfo = video_open(f_vid);
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
  dets = track_detect(vinfo, bg, calib, fr, [], false, options) ;
  video_close(vinfo) ;
  if isnumeric(dets) && ~dets, return; end
  % close video
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
      trks = track_match(dets_c, calib, chamber_str, options);
      if isnumeric(trks) && ~trks, return; end
      % segment foreground into bodyparts (wings, legs)
      trks = track_segment(trks, calib, 1, chamber_str, options);
      if isnumeric(trks) && ~trks, return; end
      % link tracklets      
      trks = track_link(trks,calib);
      % save tracks
      save(f_trks{c},'trks','-v7.3')
  end
  % indicate that everything worked
  flag = 1;
end
