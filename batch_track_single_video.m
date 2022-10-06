function batch_track_single_video(output_folder_name, input_video_file_name, input_calibration_file_name, options)
    % Runs flytracker, without further user interaction, on a single video.  Uses calibration in
    % input_calibration_file_name, and does not modify that file.  options argument
    % is optional, all other arguments are required.
    % See documentation of core_tracker() for details on options.

    % Handle case of missing options
    if ~exist('options', 'var') || isempty(options) ,
        options = [] ;
    end

    % Synthesize full paths for all the inputs and outputs
    [~, input_video_file_base_name] = fileparts(input_video_file_name) ;
    output_folder_path = absolute_filename_passing_empty(output_folder_name) ;
    output_track_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-track.mat')) ;
    output_background_file_path  = fullfile(output_folder_path, strcat(input_video_file_base_name, '-bg.mat'));
    output_calibration_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-calibration.mat'));
    output_features_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-feat.mat')) ;
    output_features_csv_folder_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-trackfeat.csv')) ;
    output_jaaba_folder_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '_JAABA')) ;
    output_segmentation_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-seg.mat')) ;
    output_options_file_path = fullfile(output_folder_path,[input_video_file_base_name,'-params.mat']);
    input_video_file_path = absolute_filename_passing_empty(input_video_file_name) ;
    input_calibration_file_path = absolute_filename_passing_empty(input_calibration_file_name) ;
    input_background_file_path = '' ;
    
    % Check that the input video and calibration files exist.  We don't do anything
    % if the calibration file does not exist.
    if ~exist(input_video_file_path, 'file') ,
        error('Input video file %s does not exist', input_video_file_path) ;
    end
    if ~exist(input_calibration_file_path, 'file') ,
        error('Calibration file %s does not exist', input_calibration_file_path) ;
    end    
    
%     % Delete the output folder, so we can start fresh
%     ensure_folder_does_not_exist(output_folder_path) ;
    
    % Call the core tracker
    core_tracker(output_track_file_path, ...
                 output_calibration_file_path, ...
                 output_background_file_path, ...
                 output_features_file_path, ...
                 output_features_csv_folder_path, ...
                 output_jaaba_folder_path, ...
                 output_options_file_path, ...
                 output_segmentation_file_path, ...
                 input_video_file_path, ...
                 input_calibration_file_path, ...
                 input_background_file_path, ...
                 options)
             
    % Declare victory
    fprintf('Success: batch_track_single_video() is about to exit!\n') ;
end
