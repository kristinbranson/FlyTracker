function test_on_single_vnc_experiment()
    % Where does this script live?
    this_script_folder_name = fileparts(mfilename('fullpath')) ;
    flytracker_folder_path = fileparts(this_script_folder_name) ;
    flydisco_folder_path =  fileparts(flytracker_folder_path) ;
    flytracker_test_files_folder_path = fullfile(flydisco_folder_path, 'flytracker-test-files') ;
    
    % Get the absolute path to the input video
    input_video_file_path = ...
        fullfile(flytracker_test_files_folder_path, 'single-passing-test-suite-experiment-read-only', ...
                 'VNC_JHS_K_85321_RigA_20210408T130721', 'movie.ufmf') ;
    
    % Specify input calibration file
    input_calibration_file_path = fullfile(flytracker_test_files_folder_path, 'parent_calibration_bubble_dickson_VNC_20210413.mat') ;
    
    % Define the options, taken by running goldblum_analyze_experiment_folders() on
    % this same experiment
    options = struct() ;
    options.num_cores = 8 ;
    options.num_chunks = 16 ;
    options.save_JAABA = 1 ;
    options.save_xls = 0 ;
    options.save_seg = 0 ;
    options.force_arena_calib = 1 ;
    options.expdir_naming = 1 ;
    options.fr_samp = 200 ;
    options.n_flies_is_max = 1 ;
    options.n_flies = 15 ;
    options.force_tracking = 0 ;
    options.arena_r_mm = 26.689 ;
    options.do_delete_intermediate_results = false ;  % setting this to false is sometimes useful when debugging
    options.do_use_scratch_folder_for_intermediates = false ;
    % Setting this to false creates a folder that is sibling to the output file for
    % intermediate results.  Sometimes useful when debugging.
    
    % % Run main flytracker on the example video
    % main_flytracker_source_folder_path = fullfile(flydisco_folder_path, 'FlyTracker-main') ;
    % main_flytracker_output_folder_path = fullfile(this_folder_path, 'FlyTracker-main-output') ;
    % rng('default') ;  % make sure the RNG is a particular state
    % run_main_flytracker(main_flytracker_output_folder_path, input_video_file_path, main_flytracker_source_folder_path, ...
    %                     input_calibration_file_path, options) ;
    
    % Run refactored flytracker on the example video
    flytracker_output_folder_path = fullfile(flytracker_test_files_folder_path, 'test-on-single-experiment-output-folder') ;
    
    % Call the tracker.
    simple_noninteractive_flytracker(flytracker_output_folder_path, input_video_file_path, input_calibration_file_path, options)
end
