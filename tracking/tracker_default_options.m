function options = tracker_default_options()
    % default options
    options.granularity = 10000;
    options.num_chunks  = [];
    options.num_cores   = 1;
    options.max_minutes = inf;
    options.fr_samp     = 100;
    options.save_JAABA  = false;
    options.save_xls    = false;
    options.save_seg    = false;
    options.force_calib = false;
    options.force_bg_calib = false ;
    options.force_arena_calib = false ;
    options.expdir_naming = false;
    options.isdisplay = true;  % true iff caller wants to use the GUI display ("do_use_display" might be a better name)
    options.startframe = 1;
    options.n_flies = [] ;
    options.arena_r_mm = [] ;
    options.n_flies_is_max = false ;
    options.do_delete_intermediate_results = true ;  % setting this to false is sometimes useful when debugging
    options.do_use_scratch_folder_for_intermediates = true ;  
        % Setting this to false creates a folder that is sibling to the output file for
        % intermediate results.  Sometimes useful when debugging.
    options.do_recompute_tracking = false ;
    options.min_fractional_arena_size = 0.9 ;
    options.max_fractional_arena_size = 1.1 ;
    options.do_compute_relative_features = true ;  % whether to compute relative features when n==2.    
                                                   % true for backward compatibility.
    options.save_JAABA_trk_mat_file = true ;  % whether to save the JABBA/CTRAX trk.mat.  Only relevant if save_JAABA is true.  
                                              % true for backward compatibility.
    options.save_JAABA_perframe_features = true ;  % whether to save the JABBA perframe feature folder and .mat files.  Only relevant if save_JAABA is true.  
                                                   % true for backward compatibility.
    options.save_JAABA_movie_link_or_copy = true ;  % whether to create a link/copt of the movie in the movie_JAABA folder.  
                                                    % Only relevant if save_JAABA is true.  true for backward compatibility.
end
