function result = load_anonymous(file_name)
    % Loads the unique variable in file_name, in a way that is transparent to the
    % caller.
    s = load(file_name, '-mat') ;
    variable_names = fieldnames(s) ;
    variable_count = length(variable_names) ;
    if variable_count == 0 ,
        error('File %s has no variables in it') ;
    elseif variable_count == 1 ,
        variable_name = variable_names{1} ;
        result = s.(variable_name) ;
    else
        error('File %s has more than one variable in it') ;
    end
end
