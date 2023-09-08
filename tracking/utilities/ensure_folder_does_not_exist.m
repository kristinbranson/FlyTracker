function ensure_folder_does_not_exist(raw_file_path)
    if isempty(raw_file_path) ,
        error('File path cannot be empty') ;
    end
    file_path = absolute_filename(raw_file_path) ;
    if isempty(file_path) ,
        error('File path cannot be empty') ;
    elseif strcmp(file_path, '/') ,
        error('Not going to rm -rf /, sorry') ;        
    elseif exist(file_path, 'file') ,
        rmdir(file_path, 's')
    else
        % do nothing, all is well
    end
end
