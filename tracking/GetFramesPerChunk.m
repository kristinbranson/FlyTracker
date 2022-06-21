function runinfo = GetFramesPerChunk(vinfo,options,f_calib)

   if ischar(vinfo),
     vinfo = video_open(vinfo);
   end
   if nargin < 2,
     options = [];
   end
   if nargin < 3,
     [dir_in] = fileparts(vinfo.filename);
     f_calib = fullfile(dir_in, 'calibration.mat');
   end
   D = load(f_calib); parent_calib = D.calib;
   
   % this might be wrong if the number of cores is different between the
   % current machine and the original machine tracking was run on

   % default options
   options_def = tracker_default_options();

   % fill in specified options
   if ((nargin < 2) || (isempty(options))), options = options_def; end
   options = set_defaults(options, options_def);
   if options.force_all,
     options.force_calib = true;
     options.force_tracking = true;
     options.force_features = true;
   end
   
   % make sure we don't try to use more workers than available
   n_cores = feature('numCores');
   options.num_cores = min(n_cores,options.num_cores);
   
   % collect video information

   % use given vinfo rather than videos
   [path,filename,ext] = fileparts(vinfo.filename);
   videos.dir_in = path;
   if ~isfield(videos,'dir_out'), videos.dir_out = path; end
   videos.filter = [filename ext];
   vid_files = {[filename ext]};

   % make sure there are videos to process
   n_vids = numel(vid_files);

   % compute maximum number of frames to process
   max_frames = round(options.max_minutes*parent_calib.FPS*60);
   endframe = options.startframe + max_frames - 1;
   min_chunksize = 100;
   
   runinfo = struct;
   runinfo.vid_files = vid_files;
   runinfo.frs_per_chunk = cell(1,n_vids);
   
   % package jobs to be run in sequence
   for n = 1:n_vids
      f_vid = fullfile(videos.dir_in, vid_files{n});
      assert(exist(f_vid,'file')>0);
      % load video
      do_close = 0;
      if nargin < 4 || isempty(vinfo)
        vinfo = video_open(f_vid);
        do_close = 1;
      end
      % get length of video 
      endframe = min(vinfo.n_frames,endframe); 
      n_frames = endframe - options.startframe + 1;  
      % compute number of chunks to process
      if ~isempty(options.num_chunks)
          n_chunks = options.num_chunks;
          chunksize = ceil(n_frames/n_chunks);
          options.granularity = max(chunksize,min_chunksize);
      end
      n_chunks = ceil(n_frames./options.granularity);

      % set frame range
      frs = cell(1,n_chunks);
      for c=1:n_chunks
         fr.start = options.startframe-1+(c-1).*options.granularity;
         fr.step  = 1;
         fr.limit = min(fr.start + options.granularity, endframe);
         frs{c} = fr;
      end
      runinfo.frs_per_chunk{n} = frs;
      
      % close video
      if do_close
        video_close(vinfo);
        vinfo = [];
      end
   end