script_folder_name = fileparts(mfilename('fullpath')) ;
read_only_folder_name = fullfile(script_folder_name, 'yoshi-short-test-videos-read-only') ;
working_folder_name = fullfile(script_folder_name, 'yoshi-short-test-videos') ;

% Delete the input folder, re-copy from read-only version
if exist(working_folder_name, 'file') ,
    system_from_list_with_error_handling({'rm', '-rf', working_folder_name}) ;
end
system_from_list_with_error_handling({'cp', '-R', '-T', read_only_folder_name, working_folder_name}) ;

input_file_name = fullfile(working_folder_name, 'movie_14-PAEL-test-01_cam_1.ufmf') ;
output_folder_name = replace_extension(input_file_name, '.flytracker-output') ;
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
run_tracker(videos_struct, options, calibration_file_name) ;
elapsed_time = toc(tic_id) ;
fprintf('Elapsed time to track was %g seconds.\n', elapsed_time) ;
