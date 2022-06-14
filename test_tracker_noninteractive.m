script_folder_name = fileparts(mfilename('fullpath')) ;
read_only_input_folder_name = fullfile(script_folder_name, 'yoshi-short-test-video-read-only') ;
input_folder_name = fullfile(script_folder_name, 'yoshi-short-test-video') ;

% Delete the input folder, re-copy from read-only version
if exist(input_folder_name, 'file') ,
    system_from_list_with_error_handling({'rm', '-rf', input_folder_name}) ;
end
system_from_list_with_error_handling({'cp', '-R', '-T', read_only_input_folder_name, input_folder_name}) ;

input_file_name = fullfile(input_folder_name, 'movie_14-PAEL-test-01_cam_1.ufmf') ;
output_folder_name = replace_extension(input_file_name, '.flytracker-output') ;
calibration_file_name = fullfile(input_folder_name, 'calibration.mat') ;

% Set options
default_num_cores = get_maximum_core_count() ;
options = struct() ;
options.num_cores   = default_num_cores ;
options.num_chunks  = default_num_cores*2 ;
options.save_JAABA  = false ;
options.save_xls    = false ;
options.save_seg    = false ;
options.n_flies_is_max = true;
options.max_minutes = 1 ;

% Delete the output folder
if exist(output_folder_name, 'file') ,
    system_from_list_with_error_handling({'rm', '-rf', output_folder_name}) ;
end

% Run it, with timing
tic_id = tic() ;
simple_noninteractive_flytracker(output_folder_name, input_file_name, calibration_file_name, options)
elapsed_time = toc(tic_id) ;
fprintf('Elapsed time to track was %g seconds.\n', elapsed_time) ;
