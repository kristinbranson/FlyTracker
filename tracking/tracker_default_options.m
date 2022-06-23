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
end
