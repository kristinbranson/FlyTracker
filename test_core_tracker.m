script_folder_name = fileparts(mfilename('fullpath')) ;
read_only_input_folder_name = fullfile(script_folder_name, 'yoshi-short-test-video-core-tracker-read-only') ;
input_folder_name = fullfile(script_folder_name, 'yoshi-short-test-video-core-tracker') ;

% Delete the input folder, re-copy from read-only version
if exist(input_folder_name, 'file') ,
    system_from_list_with_error_handling({'rm', '-rf', input_folder_name}) ;
end
system_from_list_with_error_handling({'cp', '-R', '-T', read_only_input_folder_name, input_folder_name}) ;

video_file_name = fullfile(input_folder_name, 'movie_14-PAEL-test-01_cam_1.ufmf') ;
calibration_file_name = fullfile(input_folder_name, 'calibration.mat') ;
background_model_file_name = fullfile(input_folder_name, 'movie_14-PAEL-test-01_cam_1.background.mat') ;
track_file_name = fullfile(input_folder_name, 'movie_14-PAEL-test-01_cam_1.track.mat') ;

% Set options
default_num_cores = get_maximum_core_count() ;
options = struct() ;
options.num_cores   = default_num_cores ;
options.num_chunks  = default_num_cores*2 ;
options.save_JAABA  = false ;
options.save_xls    = false ;
options.save_seg    = false ;
options.n_flies_is_max = true;
options.isdisplay = false;   % i.e. do_use_display
%options.max_minutes = 1 ;

% Run it, with timing
tic_id = tic() ;
core_tracker(track_file_name, video_file_name, calibration_file_name, background_model_file_name, options)
elapsed_time = toc(tic_id) ;
fprintf('Elapsed time to track was %g seconds.\n', elapsed_time) ;
