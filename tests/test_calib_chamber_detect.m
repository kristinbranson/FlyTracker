function test_calib_chamber_detect()
    script_folder_name = fileparts(mfilename('fullpath')) ;
    flytracker_folder_path = fileparts(script_folder_name) ;
    flytracker_parent_folder_path =  fileparts(flytracker_folder_path) ;
    flytracker_test_files_folder_path = fullfile(flytracker_parent_folder_path, 'flytracker-test-files') ;
    read_only_input_folder_name = fullfile(flytracker_test_files_folder_path, 'test-calib-chamber-detect-read-only') ;

    bg_model_file_path = ...
        fullfile(read_only_input_folder_name, ...
                 'Innate-ELmixMCH-choice-rec1_SS87269_20xUAS-CsChrimson-mVenus-attP18_Cham1-Cam0_20220828T122342-movie-bg.mat') ;
    baseline_calibration_file_path = ...
        fullfile(read_only_input_folder_name, ...
                 'calibration-done-de-novo-from-movie_14-PAEL-test-01_cam_1.mat') ;
    bg_model = load_anonymous(bg_model_file_path) ;
    baseline_calibration = load_anonymous(baseline_calibration_file_path) ;
    n_chambers = baseline_calibration.n_chambers ;
    shape = 'circular' ;
    r0 = baseline_calibration.r ;
    w0 = [] ;
    h0 = [] ;
    options = tracker_default_options() ;
    options.isdisplay = false ;  % true iff caller wants to use the GUI display ("do_use_display" might be a better name)    
    %center0 = baseline_calibration.centroids

    % Test 1
    center_target = [520 500] ;
    r_target = 492 ;
    [center, r, ~, ~] = calib_chamber_detect(bg_model, n_chambers, shape, r0, w0, h0, options) ;
    if ~isequal(center, center_target) ,
        error('Fit center is wrong.  Should be %s, but is %s', mat2str(center_target), mat2str(center)) ;
    end
    if ~isequal(r, r_target) ,
        error('Fit radius is wrong.  Should be %s, but is %s', mat2str(r_target), mat2str(r)) ;
    end
    
    % Test 2 -- Test starting with correct value, narrow bounds
    r0 = r_target ;
    options.min_fractional_arena_size = 0.95 ;
    options.max_fractional_arena_size = 1.05 ;
    [center, r, ~, ~] = calib_chamber_detect(bg_model, n_chambers, shape, r0, w0, h0, options) ;
    if ~isequal(center, center_target) ,
        error('Fit center is wrong.  Should be %s, but is %s', mat2str(center_target), mat2str(center)) ;
    end
    if ~isequal(r, r_target) ,
        error('Fit radius is wrong.  Should be %s, but is %s', mat2str(r_target), mat2str(r)) ;
    end

    % Test 3 -- Test starting with correct value, fixed
    r0 = r_target ;
    options.min_fractional_arena_size = 1 ;
    options.max_fractional_arena_size = 1 ;
    [center, r, ~, ~] = calib_chamber_detect(bg_model, n_chambers, shape, r0, w0, h0, options) ;
    if ~isequal(center, center_target) ,
        error('Fit center is wrong.  Should be %s, but is %s', mat2str(center_target), mat2str(center)) ;
    end
    if ~isequal(r, r_target) ,
        error('Fit radius is wrong.  Should be %s, but is %s', mat2str(r_target), mat2str(r)) ;
    end
end
