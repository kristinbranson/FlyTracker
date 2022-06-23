function run_tracker(videos_struct, options, input_calibration_file_name)
% Track (and calibrate) videos in a 'batch' style, without a graphical
% interface.  Note that for batch use-cases, core_tracker() is now the
% recommended interface.
%
% To run tracker, use:
%
%   tracker(videos, [options], [f_calib])
%
%  where [] denotes an optional parameter (default values used if set to []) and:
%
%    videos.            - videos to process through tracking pipeline
%       dir_in          - directory containing input videos
%       dir_out         - directory in which to save results
%       filter          - file filter (eg '*.ufmf') (default: '*')
%       
%    options.           - cluster processing and output options
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
%       force_calib     - If true, arena calibration is done for each video, 
%                         regardless of setting in calibration file (default: false)
%       expdir_naming   - Whether to use JAABA-style experiment directory
%                         naming scheme for files. (default: false)
%       arena_r_mm      - Radius of the arena in mm. This will be used to
%                         set the resolution (PPM, pixels per millimeter)
%                         if a circular arena is automatically detected.
%       n_flies         - Number of flies. Only used when run in
%                         non-interactive mode to override input
%                         calibration. (default: not defined)
%       n_flies_is_max  - Whether n_flies is an upper limit on the number
%                         of flies or an actual count. (default: false)
%      
%    f_calib            - File containing calibration data.  If missing or empty,
%                         defaults to [videos.dir_in]/calibration.mat.  If
%                         running without an interface, a calibration file must
%                         be present.

    % Deal with options argument
    if nargin < 2 || isempty(options) ,
        options = [] ;
    end
    options = sanitize_tracker_options(options); 

    % Set display variables
    is_display_available = feature('ShowFigureWindows');
    fs = 72/get(0,'ScreenPixelsPerInch'); % scale fonts to resemble OSX
    do_use_display = is_display_available && options.isdisplay;
    
    % Deal with input_calibration_file_name argument
    if nargin < 3 || isempty(input_calibration_file_name) ,
        input_calibration_file_name = fullfile(videos_struct.dir_in, 'calibration.mat') ;
    end
    input_calibration_file_path = absolute_filename(input_calibration_file_name) ;    
    if ~exist(input_calibration_file_path, 'file') ,
        str = [input_calibration_file_path ' not found: run calibrator first or input a valid calibration file.'];
        if do_use_display
            customDialog('warn',str,12*fs);
        else
            disp(str);
        end
        return
    end
    
    % Set up the parallel pool (if not already set up)
    set_up_parpool_for_flytracker(options) ;
    
    % collect video information
    % convert input/output directories to absolute path form
    videos_struct.dir_in  = absolute_filename(videos_struct.dir_in);
    videos_struct.dir_out = absolute_filename(videos_struct.dir_out);
    % check video list
    if ((~isfield(videos_struct,'filter')) || (isempty(videos_struct.filter)))
        videos_struct.filter = '*';
    end
    % scan input directory for video files
    input_video_file_names = dir(fullfile(videos_struct.dir_in, videos_struct.filter));
    input_video_file_names([input_video_file_names.isdir]) = [];
    input_video_file_names = { input_video_file_names.name };
    
    % make sure there are videos to process
    input_video_count = length(input_video_file_names) ;
    if input_video_count < 1 ,
        str = ['No videos to process for: ' fullfile(videos_struct.dir_in, videos_struct.filter)];
        if do_use_display
            customDialog('warn',str,12*fs);
        else
            disp(str);
        end
        return
    end
    
    % Call the core tracking function, once per input file
    dialog_handle = [];
    for input_video_index = 1:input_video_count
        % Figure out where all the input files are, and where the output files will go
        input_video_file_name = input_video_file_names{input_video_index} ;
        [~, input_video_file_base_name, ext] = fileparts(input_video_file_name);
        input_video_file_path = fullfile(videos_struct.dir_in, input_video_file_name);
        assert(logical(exist(input_video_file_path, 'file'))) ;
        output_folder_path = get_single_video_output_folder_path(input_video_file_path, options, videos_struct);
        input_background_file_path = '' ;
        output_track_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-track.mat')) ;
        output_background_file_path  = fullfile(output_folder_path, strcat(input_video_file_base_name, '-bg.mat'));
        output_calibration_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-calibration.mat'));
        output_features_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-feat.mat')) ;
        output_features_csv_folder_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-trackfeat.csv')) ;
        output_jaaba_folder_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '_JAABA')) ;
        output_segmentation_file_path = fullfile(output_folder_path, strcat(input_video_file_base_name, '-seg.mat')) ;
        output_options_file_path = fullfile(output_folder_path,[input_video_file_base_name,'-params.mat']);
        
        % display progress
        input_video_file_leaf_name = strcat(input_video_file_base_name, ext) ;
        waitstr = ['Processing ' input_video_file_leaf_name ...
            '   (movie ' num2str(input_video_index) '/' num2str(input_video_count) ')'];
        if do_use_display ,
            if isempty(dialog_handle) || ~ishandle(dialog_handle)
                dialog_handle = customDialog('wait',waitstr,12*fs);
            else
                child = get(dialog_handle,'Children');
                set(child(1),'string',waitstr);
            end
        else
            disp(['*** ' waitstr])
        end
        
        % call the core tracking function
        core_tracker(...
            output_track_file_path, output_calibration_file_path, output_background_file_path, output_features_file_path, ...
            output_features_csv_folder_path, output_jaaba_folder_path, output_options_file_path, ...
            output_segmentation_file_path, ...
            input_video_file_path, input_calibration_file_path, input_background_file_path, ...
            core_tracker_options) ;
    end
    
    % Finish up with the dialog
    if ~isempty(dialog_handle) && ishandle(dialog_handle)
        child = get(dialog_handle,'Children');
        set(child(1),'string','Finished!');
        pause(2)
        delete(dialog_handle);
    end    
end



function result = get_single_video_output_folder_path(input_video_file_path, options, videos)
    % Synthesize the output folder path from the input video file path.    
    if options.expdir_naming,
        result = videos.dir_out ;
    else
        [~, input_video_file_base_name] = fileparts(input_video_file_path) ;
        result = fullfile(videos.dir_out, input_video_file_base_name) ;
    end
end


