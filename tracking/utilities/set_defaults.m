%% Help functions
% Set default values for parameter fields not specified by the user.
%
%    params = set_defaults(params, params_def)
%
% copies any fields specified in params_def but not params into params.  If
% params is empty, then params is set to params_def.
function params = set_defaults(params, params_def)
   if (isempty(params))
      % return default parameters
      params = params_def;
   else
      % set default values for any unspecified parameters
      names = setdiff(fieldnames(params_def),fieldnames(params));
      for n = 1:numel(names)
         params = setfield(params, names{n}, getfield(params_def, names{n}));
      end
   end
end
