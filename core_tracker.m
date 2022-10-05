function core_tracker(output_track_file_name, ...
                      output_calibration_file_name, ...
                      output_background_file_name, ...
                      output_features_file_name, ...
                      output_features_csv_folder_name, ...
                      output_jaaba_folder_name, ...
                      output_options_file_name, ...
                      output_segmentation_file_name, ...
                      input_video_file_name, ...
                      input_calibration_file_name, ...
                      input_background_file_name, ...
                      input_options)
    
    % Track (and calibrate) videos in a 'batch' style, without a graphical
    % interface.
    %
    % core_tracker(output_track_file_name, ...
    %              output_calibration_file_name, ...
    %              output_background_file_name, ...
    %              output_features_file_name, ...
    %              output_features_csv_folder_name, ...
    %              output_jaaba_folder_name, ...
    %              output_options_file_name, ...
    %              output_segmentation_file_name, ...
    %              input_video_file_path, ...
    %              input_calibration_file_name, ...
    %              input_background_file_name, ...
    %              options)
    %
    % output_track_file_name indicates where the tracks themselves will be saved,
    % as a Matlab .mat file.  Any pre-existing file will be overwritten.
    %
    % output_calibration_file_name indicates where the output calibration
    % information will be saved, as a Matlab .mat file.  Any pre-existing file will
    % be overwritten.  Note that this file is only output if 1)
    % options.force_arena_calib is true, or 2) options.force_calib is true, or 3)
    % the input_calibration_file_name indicates that the arena calibration should be
    % performed for each video (auto_detect==true).  If none of these conditions
    % hold, output_calibration_file_name can be empty.
    %
    % output_background_file_name indicates where the output background model
    % will be saved, as a Matlab .mat file.  Any pre-existing file will
    % be overwritten.  Note that this file is only output if 1) the 
    % input_background_file_name argument is empty, or 2) options.force_bg_calib is
    % true, or 3) options.force_calib is true.  If none of these conditions hold, 
    % output_background_file_name can be empty.
    %
    % output_features_file_name indicates where the track per-frame features will be saved,
    % as a Matlab .mat file.  Any pre-existing file will be overwritten.
    %
    % output_features_csv_folder_name indicates where the track per-frame features
    % will be saved, as folder of .csv files, one per fly.  Any pre-existing folder
    % tree at this location will will be deleted.  This folder will only be written
    % (and any pre-existing folder tree only deleted) if options.save_xls is true.
    % Otherwise output_features_csv_folder_name can be empty.  (Yes,
    % options.save_csvs would probably be a better name at this point.)
    %
    % output_jaaba_folder_name indicates where the track per-frame features will be
    % saved, as a folder in the format JAABA expects.  Any pre-existing folder tree
    % at this location will will be deleted.  This folder will only be written (and
    % any pre-existing folder tree only deleted) if options.save_JAABA is true.
    % Otherwise output_jaaba_folder_name can be empty.
    %
    % output_options_file_name indicates where the "working options" will be saved,
    % as a Matlab .mat file.  The "working options" are a sanitized version of the
    % options provided by the options argument (see below).  Any pre-existing file
    % at this location will be overwritten.
    %
    % output_segmentation_file_name indicates where the segmentation will be saved,
    % as Matlab .mat file.  Any pre-existing file at this location will will be
    % overwritten.  This file will only be written if options.save_seg is true.
    % Otherwise output_segmentation_file_name can be empty.
    %
    % input_video_file_name is the name of the video to be tracked.  Currently .avi
    % and .ufmf files are supported.  This input is required.
    %
    % input_calibration_file_name is the name of the calibration file (a .mat file)
    % to be used for tracking.  This input is required.  Note that under certain
    % conditions (see above, under output_calibration_file_name) the arena
    % calibration will be re-done using input_video_file_name, and that arena
    % calibration will be used for tracking.
    %
    % input_background_file_name is the name of the file providing the background
    % model (as a .mat file) to be used for tracking.  Note that under certain
    % conditions (see above, under output_background_file_name), the background
    % model will be calculated from input_video_file_name, and that background model
    % will be used during tracking. One such condition is if
    % input_background_file_name is empty.
    % 
    % options is a scalar struct specifying various options for the tracker.  Allowed 
    % fields are:
    %
    %       max_minutes     - maximum number of minutes to process (default: inf)
    %       num_cores       - number of workers to process jobs in parallel (default: 1)
    %       granularity     - number of video frames per job (default: 10,000)
    %       num_chunks      - number of chunks to process (default: num_frames/granularity)
    %       save_JAABA      - write JAABA folders from features (default: false)
    %       save_xls        - save tracks and features to a folder of .csv files (default: false)
    %       save_seg        - save segmentation from tracking process (default: false)
    %       fr_samp         - Number of frames to sample when computing
    %                         background model. (default: 100)
    %       isdisplay       - Whether graphical display should be used for waitbars
    %                         etc.  If false, progress is shown on standard output.
    %                         (default: true)
    %       startframe      - Frame to start tracking on. Default = 1
    %       force_bg_calib  - If true, background calibration is done using the video 
    %                         indicated by input_video_file_name, and any background
    %                         model specified in input_background_file_name is
    %                         ignored. (default: false)
    %       force_arena_calib  - If true, arena calibration is done using the video 
    %                            indicated by input_video_file_name, and any arena
    %                            model specified in input_calibration_file_name is
    %                            not used for tracking. (default: false)
    %       force_calib     - If true, both force_bg_calib and force_arena_calib are taken to 
    %                         be true, regardless of their actual values, and both
    %                         background calibration and arena calibration are done
    %                         using the video indicated by input_video_file_name.
    %                         (default: false)
    %       arena_r_mm      - Radius of the arena in mm. If non-empty, this will be used to
    %                         set the resolution (PPM, pixels per millimeter) if a
    %                         circular arena is automatically detected, overriding
    %                         any value provided in input_calibration_file_name.
    %                         (default: [])
    %       n_flies         - Number of flies.  If non-empty, overrides number of flies given 
    %                         in input_calibration_file_name.  (default: [])
    %       n_flies_is_max  - Whether n_flies is an upper limit on the number
    %                         of flies or an actual count. (default: false)
    %       expdir_naming   - Not used by core_tracker().  Present only to keep
    %                         options structure consistent with those of tracker().
    % 
    % If any of these fields are missing from options, the default value is used. If
    % options contains extra fields not specified here, a warning is issued and they
    % are ignored.
    
    % Deal with args
    if ~exist('options', 'var') || isempty(input_options) ,       
        input_options = [] ; 
    end
    
    % Fill in unspecified options, delete unused fields
    working_options = sanitize_tracker_options(input_options) ;
        
    % Convert all the input file/folder names to absolute paths
    output_track_file_path = absolute_filename_passing_empty(output_track_file_name) ;
    output_calibration_file_path = absolute_filename_passing_empty(output_calibration_file_name) ;
    output_background_file_path = absolute_filename_passing_empty(output_background_file_name) ;
    output_features_file_path = absolute_filename_passing_empty(output_features_file_name) ;
    output_features_csv_folder_path = absolute_filename_passing_empty(output_features_csv_folder_name) ;
    output_jaaba_folder_path = absolute_filename_passing_empty(output_jaaba_folder_name) ;
    output_options_file_path = absolute_filename_passing_empty(output_options_file_name) ;
    output_segmentation_file_path = absolute_filename_passing_empty(output_segmentation_file_name) ;
    input_video_file_path = absolute_filename_passing_empty(input_video_file_name) ;
    input_calibration_file_path = absolute_filename_passing_empty(input_calibration_file_name) ;
    input_background_file_path = absolute_filename_passing_empty(input_background_file_name) ;    
    
    % Delete any old output files
    ensure_file_does_not_exist(output_track_file_path) ;
    ensure_file_does_not_exist(output_background_file_path) ;
    ensure_file_does_not_exist(output_features_file_path) ;
    if working_options.save_xls ,
        ensure_folder_does_not_exist(output_features_csv_folder_path) ;
    end
    if working_options.save_JAABA ,
        ensure_folder_does_not_exist(output_jaaba_folder_path) ;
    end    
        
    % make sure we don't try to use more workers than available
    working_options.num_cores = set_up_parpool_for_flytracker(working_options) ;
    
    % load calibration file
    if ~exist(input_calibration_file_path,'file')  ,
        error([input_calibration_file_path ' not found: run calibrator first or input a valid calibration file.']) ;
    end
    calibration = load_anonymous(input_calibration_file_path);
    
    % If certain things are defined in options, want those to override values in
    % calibration
    if isfield(working_options, 'n_flies') && ~isempty(working_options.n_flies) ,
        calibration.n_flies = working_options.n_flies ;
    end
    if isfield(working_options, 'arena_r_mm') && ~isempty(working_options.arena_r_mm) ,
        calibration.arena_r_mm = working_options.arena_r_mm ;
    end
    if isfield(working_options, 'n_flies_is_max') && ~isempty(working_options.n_flies_is_max) ,
        calibration.n_flies_is_max = working_options.n_flies_is_max ;
    end
    
    % compute maximum number of frames to process
    max_frames = round(working_options.max_minutes*calibration.FPS*60) ;
    endframe = working_options.startframe + max_frames - 1;
    min_chunksize = 100;
    
    % break down the track file name
    [~, track_file_base_name, ~] = fileparts(output_track_file_path) ;        

    % Synthesize the temporary track file folder name
    scratch_folder_path = get_scratch_folder_path() ;
    temp_track_folder_name = tempname(scratch_folder_path) ;
    
    % delete any old temporary folder, if it exists
    ensure_file_does_not_exist(temp_track_folder_name) ;
    
    % Create the temp output folder, and make sure it gets deleted when done
    ensure_folder_exists(temp_track_folder_name) ;   
    cleaner = onCleanup(@()(ensure_folder_does_not_exist(temp_track_folder_name))) ;
    
    % display progress
    
%     % check whether video has already been tracked
%     track_file_name = fullfile(output_folder_name, [input_video_file_base_name '-track.mat']) ;
    
    % load video to get frame count
    vinfo = video_open(input_video_file_path) ;
    frame_count = vinfo.n_frames ;
    video_close(vinfo) ;
    
    % get length of video
    endframe = min(frame_count, endframe) ;
    n_frames = endframe - working_options.startframe + 1;
    
    % compute background from video if needed
    if isempty(input_background_file_path) || working_options.force_bg_calib , 
        ensure_file_does_not_exist(output_background_file_path) ;        
        did_succeed = core_tracker_fit_background_model(output_background_file_path, ...
                                                        input_video_file_path, input_calibration_file_path, ...
                                                        working_options) ;
        if ~did_succeed ,
            error('Background fitting failed') ;
        end
        working_background_file_name = output_background_file_path ;
    else
        working_background_file_name = input_background_file_path ;
    end

    % compute arena model from background model, if needed
    %tic_id = tic() ;
    if working_options.force_arena_calib || calibration.auto_detect ,
        ensure_file_does_not_exist(output_calibration_file_path) ;        
        did_succeed = core_tracker_fit_arena(output_calibration_file_path, ...
                                             working_background_file_name, input_calibration_file_path, ...
                                             working_options) ;       
        if ~did_succeed ,
            error('Calibration failed') ;
        end
        working_calibration_file_name = output_calibration_file_path ;
    else
        working_calibration_file_name = input_calibration_file_path ;        
    end
    %elapsed_time = toc(tic_id) ;
    %fprintf('Elapsed time to refit arena model was %g seconds.\n', elapsed_time) ;
    
    % compute number of chunks to process
    if ~isempty(working_options.num_chunks)
        chunk_count = working_options.num_chunks;
        chunk_size = ceil(n_frames/chunk_count);
        working_options.granularity = max(chunk_size,min_chunksize) ;
    end
    chunk_count = ceil(n_frames./working_options.granularity) ;
    % loop through all chambers
    valid = find(calibration.valid_chambers);
    chamber_count = numel(valid);
    % process tracks for all chambers

    % Set the frame range for each chunk
    start_step_limit_from_chunk_index = struct_with_shape_and_fields([1 chunk_count], {'start', 'step', 'limit'}) ;
    for chunk_index = 1:chunk_count ,
        start_step_limit = struct() ;
        start_step_limit.start = working_options.startframe - 1 + (chunk_index-1) .* working_options.granularity ;
        start_step_limit.step  = 1 ;
        start_step_limit.limit = min(start_step_limit.start + working_options.granularity, endframe) ;
        start_step_limit_from_chunk_index(chunk_index) = start_step_limit ;
    end    
    
    % Determine the temp file name for each (chamber, chunk) pair
    atomic_track_file_name_from_chamber_index_from_chunk_index = cell(chamber_count, chunk_count) ;
    for chunk_index = 1:chunk_count ,
        atomic_track_file_name_from_chamber_index = cell(1, chamber_count) ;
        for chamber_index = 1:chamber_count ,
            chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
            % determine output filename
            atomic_track_file_leaf_name = ...
                [track_file_base_name chamber_affix '-trk' '-' num2str(start_step_limit_from_chunk_index(chunk_index).start,'%010d') '.mat'] ;
            atomic_track_file_name = ...
                fullfile(temp_track_folder_name, atomic_track_file_leaf_name) ;
            atomic_track_file_name_from_chamber_index{chamber_index} = atomic_track_file_name ;
            atomic_track_file_name_from_chamber_index_from_chunk_index{chamber_index, chunk_index} = atomic_track_file_name ;
        end
    end
    
    % For each chunk, run the tracker
    if working_options.num_cores > 1 ,
        did_succeed_from_chunk_index = zeros(1,chunk_count) ;
        parfor chunk_index = 1:chunk_count ,
            % store job parameters
            did_succeed = ...
                tracker_job_process(input_video_file_path, working_background_file_name, working_calibration_file_name, ...
                                    atomic_track_file_name_from_chamber_index_from_chunk_index(:,chunk_index)', ...
                                    start_step_limit_from_chunk_index(chunk_index), ...
                                    working_options) ;
            did_succeed_from_chunk_index(chunk_index) = did_succeed;
        end
        if ~all(did_succeed_from_chunk_index)
            error('Some chunks failed') ;
        end
    else
        for chunk_index = 1:chunk_count ,
            % store job parameters
            did_succeed = ...
                tracker_job_process(input_video_file_path, working_background_file_name, working_calibration_file_name, ...
                                    atomic_track_file_name_from_chamber_index_from_chunk_index(:,chunk_index)', ...
                                    start_step_limit_from_chunk_index(chunk_index), ...
                                    working_options) ;
            if ~did_succeed , 
                error('Error while tracking chunk %d', chunk_index) ;
            end
        end
    end

    %
    % For each chamber, combine results for all chunks
    %
    
    % Synthesize file name for each per-chamber track file
    per_chamber_track_file_name_from_chamber_index = cell(1,chamber_count) ;
    for chamber_index=1:chamber_count
        chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
        per_chamber_track_file_name = fullfile(temp_track_folder_name, [track_file_base_name chamber_affix '-track.mat']);        
        per_chamber_track_file_name_from_chamber_index{chamber_index} = per_chamber_track_file_name;
    end    
    
    % Synthesize file name for each per-chamber seg file
    per_chamber_segmentation_file_name_from_chamber_index = cell(1,chamber_count) ;
    for chamber_index=1:chamber_count
        chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
        per_chamber_segmentation_file_name = fullfile(temp_track_folder_name, [track_file_base_name chamber_affix '-seg.mat']);        
        per_chamber_segmentation_file_name_from_chamber_index{chamber_index} = per_chamber_segmentation_file_name;
    end    
    
    % For each chamber, do the heavy lifting of combining results for all chunks
    for chamber_index=1:chamber_count
        atomic_track_file_name_from_chunk_index = atomic_track_file_name_from_chamber_index_from_chunk_index(chamber_index,:) ;
        per_chamber_track_file_name = per_chamber_track_file_name_from_chamber_index{chamber_index} ;   
        per_chamber_segmentation_file_name = per_chamber_segmentation_file_name_from_chamber_index{chamber_index} ;
        core_tracker_job_combine(per_chamber_track_file_name, per_chamber_segmentation_file_name, ...
                                 atomic_track_file_name_from_chunk_index, working_calibration_file_name, working_options) ;
    end
    
    %
    % Finally, combine tracks from chambers
    %
    core_tracker_job_consolidate(output_track_file_path, ...
                                 output_segmentation_file_path, ...
                                 per_chamber_track_file_name_from_chamber_index, ...
                                 per_chamber_segmentation_file_name_from_chamber_index, ...
                                 working_options) ;
    
    % compute features and learning files if specified
    core_tracker_compute_features(output_features_file_path, output_features_csv_folder_path, output_jaaba_folder_path, ...
                                  input_video_file_path, output_track_file_path, working_calibration_file_name, ...
                                  working_options) ;
                              
    % Save the working options
    options = working_options ;
    save(output_options_file_path, 'options') ;
end
