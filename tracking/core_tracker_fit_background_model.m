function working_background_file_name = core_tracker_fit_background_model(output_background_file_name, ...
                                                                          input_video_file_name, calibration, ...
                                                                          input_background_file_name, ...
                                                                          options)

    %                                       
    % Compute background model
    %
    % Returns the name of the background file that should be
    % used for subsequent processing.
    %
    
    % If user wants to use the input background file, skip background fitting.    
    if isempty(input_background_file_name) || options.force_bg_calib ,
        % proceed with background fitting
    else
        % skip background fitting, use input background file
        working_background_file_name = input_background_file_name ;
        return
    end
    
    % Delete any old output file, if it exists
    ensure_file_does_not_exist(output_background_file_name) ;
    
    % open video
    vinfo = video_open(input_video_file_name,1);
    cleaner = onCleanup(@()(video_close(vinfo))) ;
    frame_count = vinfo.n_frames ;

    % compute frame range
    sample_frame_count = options.fr_samp ;
    fr.start = 1;
    fr.step = max(1,floor((frame_count)./sample_frame_count)) ;
    fr.limit = frame_count ;
    
    % compute background model
    bg = calib_bg_estimate(vinfo, calibration.PPM, fr, options);
    if isnumeric(bg) && ~bg ,
        error('Background fitting failed') ;
    end
    
    % save background model
    ensure_parent_folder_exists(output_background_file_name) ;
    save(output_background_file_name, 'bg') ;
    working_background_file_name = output_background_file_name ;
end
