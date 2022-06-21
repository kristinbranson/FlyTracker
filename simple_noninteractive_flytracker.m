function simple_noninteractive_flytracker(output_folder_name, input_file_name, calibration_file_name, options)
    % Runs flytracker, without further user interaction, on a single video.  Uses calibration in
    % calibration_file_name, and does not modify the calibration.  options argument
    % is optional, all other arguments are required.

    % Handle case of missing options
    if ~exist('options', 'var') || isempty(options) ,
        options = struct() ;
    end
    
    % Check that the input video and calibration files exist.  We don't do anything
    % if the calibration file does not exist.
    if ~exist(input_file_name, 'file') ,
        error('Input video file %s does not exist') ;
    end
    if ~exist(calibration_file_name, 'file') ,
        error('Calibration file %s does not exist') ;
    end    
    
    % Package up the info about input/output videos into the funny structure that
    % tracker() wants.
    [input_file_folder, input_file_leaf_name] = fileparts2(input_file_name) ;
    videos_struct = struct() ;
    videos_struct.dir_in = input_file_folder ;
    videos_struct.dir_out = output_folder_name ;
    videos_struct.filter  = input_file_leaf_name ;
    
    % Call the tracker.  Calling it with args means it will run noninteractively.
    % (Although currently it still shows graphical progress bars and such.)
    run_tracker(videos_struct, options, calibration_file_name) ;
end
