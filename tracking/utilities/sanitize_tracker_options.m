function options = sanitize_tracker_options(input_options)
    % Set default values for parameter fields not specified by the user.
    %
    %    params = sanitize_options(params, params_def)
    %
    % copies any fields specified in params_def but not params into params.  If
    % params is empty, then params is set to params_def.
    default_options = tracker_default_options() ;
    if isempty(input_options) ,
        % return default parameters
        options = default_options ;
    else
        % set default values for any unspecified parameters
        original_field_names = fieldnames(input_options) ;
        canonical_field_names = fieldnames(default_options) ;
        missing_names = setdiff(canonical_field_names, original_field_names) ;        
        extra_names = setdiff(original_field_names, canonical_field_names) ;
        options = input_options ;
        for n = 1:numel(missing_names) ,
            name = missing_names{n} ;
            options.(name) = default_options.(name) ;
        end
        for i = 1 : length(extra_names) ,
            name = extra_names{i} ;
            if strcmp(name, 'force_tracking') ,
                warning('FlyTracker:oldOption', 'Translating old-style option field "force_tracking" to new-style "do_recompute_tracking" field') ;
                options.do_recompute_tracking = input_options.force_tracking ;
            else
                warning('FlyTracker:extraOption', 'Ignoring unused field "%s" from options', name) ;
                options = rmfield(options, name) ;
            end
        end
    end    
    
    % Make sure forced calibration options are consistent
    if options.force_calib ,
        options.force_bg_calib = true ;
        options.force_arena_calib = true ;
    end
end
