function did_succeed = core_tracker_fit_background_model(output_background_file_name, ...
                                                         input_video_file_name, input_calibration_file_name, ...
                                                         options)
    
    % Compute background model
    
    did_succeed = 0;
    % open info file
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
    bg = calib_bg_estimate(vinfo, input_calibration_file_name.PPM, fr);
    if isnumeric(bg) && ~bg ,
        return
    end
    % save background model
    save(output_background_file_name,'bg');
    did_succeed = 1;
end
