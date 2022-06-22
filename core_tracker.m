function core_tracker(...
        output_track_file_name, output_calibration_file_name, output_background_file_name, output_features_file_name, ...
        output_features_csv_folder_name, output_jaaba_folder_name, output_options_file_name, ...
        output_segmentation_file_name, ...
        input_video_file_path, input_calibration_file_name, input_background_file_name, ...
        input_options)
    
    % Track (and calibrate) videos.
    %
    % To run tracker with interface, use:
    %
    %   tracker
    %
    % To run tracker without interface, use:
    %
    %   tracker(videos, [options], [f_calib], [vinfo])
    %
    %  where [] denotes an optional parameter (default values used if set to []) and:
    %
    %    videos.            - videos to process through tracking pipeline
    %       dir_in          - directory containing input videos
    %       dir_out         - directory in which to save results
    %       filter          - file filter (eg '*.avi') (default: '*')
    %
    %    options.           - cluster processing and output options
    %       max_minutes     - maximum number of minutes to process (default: inf)
    %       num_cores       - number of workers to process jobs in parallel? (default: 1)
    %       granularity     - number of video frames per job (default: 10,000)
    %       num_chunks      - number of chunks to process (default: num_frames/granularity)
    %       save_JAABA      - write JAABA folders from features? (default: false)
    %       save_xls        - save tracks and feats to xls? (default: false)
    %       save_seg        - save segmentation from tracking process? (default: false)
    %       f_parent_calib  - path to parent calibration file -- defines
    %                         parameters that are usually preserved within
    %                         videos of the same rig based on a calibration
    %                         file from a different video. If not
    %                         defined/empty, all parameters are estimated from
    %                         this video.
    %       fr_samp         - Number of frames to sample when computing
    %                         background model. (default: 100)
    %       isdisplay       - Whether display is available for waitbars etc.
    %       startframe      - Frame to start tracking on. Default = 1
    %       force_all       - Whether to force all computations, regardless of
    %                         whether the files these computations would
    %                         compute already exist. (default: false)
    %       force_calib     - Whether to run calibration even if calibration
    %                         mat file already exists. (default: false)
    %       force_features  - Whether to run feature computation even if
    %                         feature mat file alreay exists. (default: false)
    %       expdir_naming   - Whether to use JAABA-style experiment directory
    %                         naming scheme for files. (default: false)
    %       arena_r_mm      - Radius of the arena in mm. This will be used to
    %                         set the resolution (PPM, pixels per millimeter)
    %                         if a circular arena is automatically detected.
    %       n_flies         - Number of flies. Only used when run in
    %                         non-interactive mode to override parent
    %                         calibration. (default: not defined)
    %       n_flies_is_max  - Whether n_flies is an upper limit on the number
    %                         of flies or an actual count. (default: false)
    %
    %    f_calib            - file containing calibration data (default: [videos_dir_in]/calibration.mat)
    %    vinfo              - if specified, ignore videos and use loaded video
    
    % Deal with args
    if ~exist('input_options', 'var') || isempty(input_options) ,       
        input_options = [] ; 
    end
    
    % Fill in unspecified options, delete unused fields
    working_options = sanitize_tracker_options(input_options) ;
        
    % Delete any old output files
    ensure_file_does_not_exist(output_track_file_name) ;
    ensure_file_does_not_exist(output_calibration_file_name) ;
    ensure_file_does_not_exist(output_background_file_name) ;
    ensure_file_does_not_exist(output_features_file_name) ;
    if working_options.save_xls ,
        ensure_folder_does_not_exist(output_features_csv_folder_name) ;
    end
    if working_options.save_JAABA ,
        ensure_folder_does_not_exist(output_jaaba_folder_name) ;
    end    
        
    % make sure we don't try to use more workers than available
    set_up_parpool_for_flytracker(working_options) ;
    
    % load calibration file
    if ~exist(input_calibration_file_name,'file')  ,
        error([input_calibration_file_name ' not found: run calibrator first or input a valid calibration file.']) ;
    end
    calibration = load_anonymous(input_calibration_file_name);
    
    % If certain things are defined in options, want those to override values in
    % calibration
    if isfield(working_options, 'n_flies') ,
        calibration.n_flies = working_options.n_flies ;
    end
    if isfield(working_options, 'arena_r_mm') ,
        calibration.arena_r_mm = working_options.arena_r_mm ;
    end
    if isfield(working_options, 'n_flies_is_max') ,
        calibration.n_flies_is_max = working_options.n_flies_is_max ;
    end
    
    % compute maximum number of frames to process
    max_frames = round(working_options.max_minutes*calibration.FPS*60) ;
    endframe = working_options.startframe + max_frames - 1;
    min_chunksize = 100;
    
    % break down the track file name
    [~, track_file_base_name, ~] = fileparts(output_track_file_name) ;        

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
    if isempty(input_background_file_name) || working_options.force_bg_calib , 
        did_succeed = core_tracker_fit_background_model(output_background_file_name, ...
                                                        input_video_file_path, input_calibration_file_name, ...
                                                        working_options) ;
        if ~did_succeed ,
            error('Background fitting failed') ;
        end
        working_background_file_name = output_background_file_name ;
    else
        working_background_file_name = input_background_file_name ;
    end

    % compute arena model from background model, if needed
    %tic_id = tic() ;
    if working_options.force_arena_calib || calibration.auto_detect ,
        did_succeed = core_tracker_fit_arena(output_calibration_file_name, ...
                                             working_background_file_name, input_calibration_file_name, ...
                                             working_options) ;       
        if ~did_succeed ,
            error('Calibration failed') ;
        end
        working_calibration_file_name = output_calibration_file_name ;
    else
        working_calibration_file_name = input_calibration_file_name ;        
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
                                    start_step_limit_from_chunk_index(chunk_index)) ;
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
                                    start_step_limit_from_chunk_index(chunk_index)) ;
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
    % Finally, combine trackes from chambers
    %
    core_tracker_job_consolidate(output_track_file_name, ...
                                 output_segmentation_file_name, ...
                                 per_chamber_track_file_name_from_chamber_index, ...
                                 per_chamber_segmentation_file_name_from_chamber_index, ...
                                 working_options) ;
    
    % compute features and learning files if specified
    core_tracker_compute_features(output_features_file_name, output_features_csv_folder_name, output_jaaba_folder_name, ...
                                  input_video_file_path, output_track_file_name, working_calibration_file_name, ...
                                  working_options) ;
                              
    % Save the working options
    options = working_options ;
    save(output_options_file_name,'options') ;
end
