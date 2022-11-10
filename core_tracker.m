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
    % as a Matlab .mat file.  If there is a pre-existing file at this location, 
    % tracking will be skipped unless options.do_recompute_tracking is true.
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
    %       do_delete_intermediate_results  - 
    %                         If true, per-chunk tracking results, and other
    %                         intermediate result, are deleted once tracking is
    %                         complete or errors out.  If false, these intermediates
    %                         are left in place.  This is sometimes useful when
    %                         debugging. (default: true)
    %       do_use_scratch_folder_for_intermediates -
    %                         If true, intermediate results are stored under
    %                         /scratch (on a cluster node) or /tmp.  If false, 
    %                         intermediate results are stored in folder that is a
    %                         sibling of the tracking output file, named 
    %                         <track-file-name>.intermediates.  (default: true)
    %       do_recompute_tracking -
    %                         If true, tracking is computed even if output_track_file_name
    %                         already exists.  Otherwise, tracking is skipped if 
    %                         output_track_file_name already exists.
    %       arena_size_fractional_search_range -
    %                         If arena calibration is done, the range of
    %                         possible arena sizes to consider when fitting,
    %                         relative to the arena size in the input
    %                         calibration.  E.g. if this is 0.1, then for a
    %                         circular arena, arena radii of r/1.1 to r*1.1 will
    %                         be considered, where r is the arena radius in the
    %                         input calibration.  Set to 0 to fix the arena
    %                         size.  (default: 0.1)
    %
    % If any of these fields are missing from options, the default value is used. If
    % options contains extra fields not specified here, a warning is issued and they
    % are ignored.
    
    % Deal with args
    if ~exist('input_options', 'var') || isempty(input_options) ,       
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
    
    % Make sure the input calibration file path is valid, and the file exists
    if isempty(input_calibration_file_path) ,
        error('input_calibration_file_path cannot be empty') ;
    end
    if ~logical(exist(input_calibration_file_path, 'file')) ,
        error('Input calibration file (%s) does not exist', input_calibration_file_path) ;
    end
    
    % Make sure corresponding input, output calbration files are distinct
    if logical(exist(output_calibration_file_path, 'file')) ,
        canonical_input_calibration_file_path = realpath(input_calibration_file_path) ;
        canonical_output_calibration_file_path = realpath(output_calibration_file_path) ;
        if strcmp(canonical_input_calibration_file_path, canonical_output_calibration_file_path) ,
            error('Output calibration file path ("%s") must be different from input calibration file path ("%s")', ...
                  output_calibration_file_path, ...
                  input_calibration_file_path) ;
        end
    end

    % Check the input/output background paths
    if isempty(input_background_file_path) ,
        % this is ok, in principle
    else
        if ~logical(exist(input_background_file_path, 'file')) ,
            error('Input background file (%s) does not exist', input_background_file_path) ;
        end
        % If we get to here, input background file was specified and exists
        if exist(output_background_file_path, 'file') ,
            % Both input and output files exist, so make sure they're distinct
            canonical_input_background_path = realpath(input_background_path) ;
            canonical_output_background_path = realpath(output_background_path) ;
            if strcmp(canonical_input_background_path, canonical_output_background_path) ,
                error('Output background file path ("%s") must be different from input background file path ("%s")', ...
                      output_background_file_path, ...
                      input_background_file_path) ;
            end
        end
    end       
        
    % make sure we don't try to use more workers than available
    working_options.num_cores = set_up_parpool_for_flytracker(working_options) ;
    
    % load calibration file
    if ~exist(input_calibration_file_path,'file')  ,
        error([input_calibration_file_path ' not found: run calibrator first or input a valid calibration file.']) ;
    end
    input_calibration = load_anonymous(input_calibration_file_path);
    
    % If certain things are defined in options, want those to override values in
    % calibration
    pre_fitting_calibration = input_calibration ;
    if isfield(working_options, 'n_flies') && ~isempty(working_options.n_flies) ,
        pre_fitting_calibration.n_flies = working_options.n_flies ;
    end
    if isfield(working_options, 'arena_r_mm') && ~isempty(working_options.arena_r_mm) ,
        pre_fitting_calibration.arena_r_mm = working_options.arena_r_mm ;
    end
    if isfield(working_options, 'n_flies_is_max') && ~isempty(working_options.n_flies_is_max) ,
        pre_fitting_calibration.n_flies_is_max = working_options.n_flies_is_max ;
    end
    
    % compute background from video if needed
    working_background_file_name = ...
        core_tracker_fit_background_model(output_background_file_path, ...
                                          input_video_file_path, pre_fitting_calibration, ...
                                          input_background_file_path, ...
                                          working_options) ;

    % compute arena model from background model, if needed
    post_fitting_calibration = ...
        core_tracker_fit_arena(output_calibration_file_path, ...
                               working_background_file_name, ...
                               pre_fitting_calibration, ...
                               working_options) ;
    
    % Do the tracking proper
    core_core_tracker(output_track_file_path, ...
                      working_background_file_name, ...
                      output_segmentation_file_path, ...
                      input_video_file_path, ...
                      working_options, ...
                      post_fitting_calibration) ;
    
    % compute features and learning files if specified
    core_tracker_compute_features(output_features_file_path, output_features_csv_folder_path, output_jaaba_folder_path, ...
                                  input_video_file_path, output_track_file_path, post_fitting_calibration, ...
                                  working_options) ;
                              
    % Save the working options
    options = working_options ;
    save(output_options_file_path, 'options') ;
end
