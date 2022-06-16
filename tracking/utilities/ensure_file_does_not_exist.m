function ensure_file_does_not_exist(raw_file_path)
    file_path = absolute_filename(raw_file_path) ;
    if isempty(file_path) ,
        error('File path cannot be empty') ;
    elseif strcmp(file_path, '/') ,
        error('Not going to rm -rf /, sorry') ;        
    elseif exist(file_path, 'file') ,
        system_from_list_with_error_handling({'rm', '-rf', file_path}) ;
    else
        % do nothing, all is well
    end
end
