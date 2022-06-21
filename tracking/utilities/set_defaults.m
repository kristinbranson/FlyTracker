%% Help functions
% Set default values for parameter fields not specified by the user.
%
%    params = set_defaults(params, params_def)
%
% copies any fields specified in params_def but not params into params.  If
% params is empty, then params is set to params_def.
function params = set_defaults(params, params_def)
    if isempty(params) ,
        % return default parameters
        params = params_def ;
    else
        % set default values for any unspecified parameters
        original_field_names = fieldnames(params) ;
        canonical_field_names = fieldnames(params_def) ;
        missing_names = setdiff(canonical_field_names, original_field_names) ;        
        extra_names = setdiff(original_field_names, canonical_field_names) ;
        for n = 1:numel(missing_names) ,
            name = missing_names{n} ;
            params.(name) = params_def.(name) ;
        end
        for i = 1 : length(extra_names) ,
            name = extra_names{i} ;
            warning('FlyTracker:extraOption', 'Ignoring unused field "%s" from options', name) ;
            params = rmfield(params, name) ;                        
        end
    end
end
