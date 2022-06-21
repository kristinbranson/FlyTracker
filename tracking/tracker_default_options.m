function options_def = tracker_default_options()

% default options
options_def.granularity = 10000;
options_def.num_chunks  = [];
options_def.num_cores   = 1;
options_def.max_minutes = inf;
options_def.fr_samp     = 100;
options_def.save_JAABA  = false;
options_def.save_xls    = false;
options_def.save_seg    = false;
options_def.f_parent_calib = '';
options_def.force_calib = false;
options_def.expdir_naming = false;
options_def.isdisplay = true;  % true iff caller wants to use the GUI display ("do_use_display" might be a better name)
options_def.force_tracking = false;
options_def.force_all = false;
options_def.force_features = false;
options_def.startframe = 1;
options_def.n_flies_is_max = false ;
