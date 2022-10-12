function test_simple_noninteractive_flytracker()
    this_script_folder_name = fileparts(mfilename('fullpath')) ;
    flytracker_folder_path = fileparts(this_script_folder_name) ;
    flydisco_folder_path =  fileparts(flytracker_folder_path) ;
    flytracker_test_files_folder_path = fullfile(flydisco_folder_path, 'flytracker-test-files') ;
    read_only_input_folder_name = fullfile(flytracker_test_files_folder_path, 'yoshi-short-test-video-read-only') ;
    working_folder_name = fullfile(flytracker_test_files_folder_path, 'yoshi-short-test-video') ;
    
    % Delete the input folder, re-copy from read-only version
    if exist(working_folder_name, 'file') ,
        system_from_list_with_error_handling({'rm', '-rf', working_folder_name}) ;
    end
    system_from_list_with_error_handling({'cp', '-R', '-T', read_only_input_folder_name, working_folder_name}) ;
    
    % Specify input, output paths
    input_video_file_name = fullfile(working_folder_name, 'movie_14-PAEL-test-01_cam_1.ufmf') ;
    input_calibration_file_name = fullfile(working_folder_name, 'calibration.mat') ;
    output_folder_name = fullfile(working_folder_name, 'movie_14-PAEL-test-01_cam_1.flytracker') ;
    
    % Set options
    default_num_cores = get_maximum_core_count() ;
    options = struct() ;
    options.num_cores   = default_num_cores ;
    options.num_chunks  = default_num_cores*2 ;
    options.save_JAABA  = true ;
    options.save_xls    = true ;
    options.save_seg    = true ;
    options.n_flies_is_max = true;
    options.isdisplay = false;   % i.e. do_use_display
    %options.max_minutes = 1 ;
    options.force_bg_calib = true ;
    options.force_arena_calib = true ;
    
    % Run it, with timing
    tic_id = tic() ;
    simple_noninteractive_flytracker(output_folder_name, input_video_file_name, input_calibration_file_name, options) ;
    elapsed_time = toc(tic_id) ;
    fprintf('Elapsed time to track was %g seconds.\n', elapsed_time) ;
end
