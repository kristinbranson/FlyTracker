function options = sanitize_tracker_options(options)
    % Set default values for parameter fields not specified by the user.
    %
    %    params = sanitize_options(params, params_def)
    %
    % copies any fields specified in params_def but not params into params.  If
    % params is empty, then params is set to params_def.
    default_options = tracker_default_options() ;
    if isempty(options) ,
        % return default parameters
        options = default_options ;
    else
        % set default values for any unspecified parameters
        original_field_names = fieldnames(options) ;
        canonical_field_names = fieldnames(default_options) ;
        missing_names = setdiff(canonical_field_names, original_field_names) ;        
        extra_names = setdiff(original_field_names, canonical_field_names) ;
        for n = 1:numel(missing_names) ,
            name = missing_names{n} ;
            options.(name) = default_options.(name) ;
        end
        for i = 1 : length(extra_names) ,
            name = extra_names{i} ;
            warning('FlyTracker:extraOption', 'Ignoring unused field "%s" from options', name) ;
            options = rmfield(options, name) ;                        
        end
    end    
    
    % Make sure forced calibration options are consistent
    if options.force_calib ,
        options.force_bg_calib = true ;
        options.force_arena_calib = true ;
    end
end