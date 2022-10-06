function core_tracker_compute_features(output_feature_file_name, output_features_csv_folder_name, output_jaaba_folder_name, ...
                                       input_video_file_name, input_tracking_file_name, calibration, ...
                                       options)
                                   
  %
  % Compute features from tracking data
  %

  % write feat file  
  trk = load_anonymous(input_tracking_file_name) ;
  feat = feat_compute(trk, calibration) ;
  save(output_feature_file_name,'feat','-v7.3') ;

  % save csv files
  if options.save_xls
      %output_xls_file_name = [input_tracking_file_name(1:end-10) '-trackfeat'];
      names = [trk.names feat.names] ;
      data = nan(size(trk.data,1),size(trk.data,2),numel(names)) ;
      data(:,:,1:size(trk.data,3)) = trk.data ;
      data(:,:,size(trk.data,3)+(1:size(feat.data,3))) = feat.data ;
      write_csvs(output_features_csv_folder_name, data, names) ;
  end  
  
  % write JAABA folders
  if options.save_JAABA
      % JAABA_dir = [input_tracking_file_name(1:end-10) '-JAABA'];
      % augment features (with log, norms, and derivatives)
      feat = feat_augment(feat);
      writeJAABA(input_tracking_file_name, input_video_file_name, trk, feat, calibration, output_jaaba_folder_name) ;
  end
 
end
