function test_tracker()
    this_script_folder_name = fileparts(mfilename('fullpath')) ;
    flytracker_folder_path = fileparts(this_script_folder_name) ;
    flydisco_folder_path =  fileparts(flytracker_folder_path) ;
    flytracker_test_files_folder_path = fullfile(flydisco_folder_path, 'flytracker-test-files') ;
    read_only_input_folder_name = fullfile(flytracker_test_files_folder_path, 'yoshi-short-test-video-read-only') ;
    working_folder_name = fullfile(flytracker_test_files_folder_path, 'yoshi-short-test-video') ;

    % Delete the input folder, re-copy from read-only version
    if exist(working_folder_name, 'file') ,
        %system_from_list_with_error_handling({'rm', '-rf', working_folder_name}) ;
        rmdir(working_folder_name, 's') ;
    end
    %system_from_list_with_error_handling({'cp', '-R', '-T', read_only_input_folder_name, working_folder_name}) ;
    copyfile(read_only_input_folder_name, working_folder_name) ;
    
    output_folder_name = fullfile(working_folder_name, 'test_tracker_output') ;
    calibration_file_name = fullfile(working_folder_name, 'calibration.mat') ;
    
    % Set options
    default_num_cores = get_maximum_core_count() ;
    options = struct() ;
    options.num_cores   = default_num_cores ;
    options.num_chunks  = default_num_cores*2 ;
    options.save_JAABA  = true ;
    options.save_xls    = true ;
    options.save_seg    = true ;
    options.n_flies_is_max = true;
    options.max_minutes = 1 ;
    options.isdisplay = false ;   % i.e. do_use_display
    options.expdir_naming = false ;
    
    % Delete the output folder
    ensure_folder_does_not_exist(output_folder_name)
    
    % Package up the info about input/output videos into the funny structure that
    % tracker() wants.
    videos_struct = struct() ;
    videos_struct.dir_in = working_folder_name ;
    videos_struct.dir_out = output_folder_name ;
    videos_struct.filter  = '*.ufmf' ;
    
    % Call the tracker.  Calling it with args means it will run noninteractively.
    % (Although currently it still shows graphical progress bars and such.)
    tic_id = tic() ;
    tracker(videos_struct, options, calibration_file_name) ;
    elapsed_time = toc(tic_id) ;
    fprintf('Elapsed time to track was %g seconds.\n', elapsed_time) ;
end
