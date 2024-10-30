function core_tracker_compute_features(output_feature_file_name, output_features_csv_folder_name, output_jaaba_folder_name, ...
                                       input_video_file_name, input_tracking_file_name, calibration, ...
                                       options)
                                   
  %
  % Compute features from tracking data
  %

  % write feat file  
  trk = load_anonymous(input_tracking_file_name) ;
  if isfield(options, 'do_compute_relative_features') ,
    do_compute_relative_features = options.do_compute_relative_features ;
  else
    do_compute_relative_features = true ;  % for backwards-compatibility
  end
  feat = feat_compute(trk, calibration, do_compute_relative_features) ;
  save(output_feature_file_name,'feat','-v7.3') ;

  % save csv files
  if options.save_xls
      names = [trk.names feat.names] ;
      data = nan(size(trk.data,1),size(trk.data,2),numel(names)) ;
      data(:,:,1:size(trk.data,3)) = trk.data ;
      data(:,:,size(trk.data,3)+(1:size(feat.data,3))) = feat.data ;
      write_csvs(output_features_csv_folder_name, data, names) ;
  end  
  
  % write JAABA folders
  if options.save_JAABA
      % augment features (with log, norms, and derivatives)
      writeJAABA(input_tracking_file_name, input_video_file_name, trk, feat, calibration, output_jaaba_folder_name, ...
                 options.save_JAABA_trk_mat_file, options.save_JAABA_perframe_features, options.save_JAABA_movie_link_or_copy) ;
  end
 
end
