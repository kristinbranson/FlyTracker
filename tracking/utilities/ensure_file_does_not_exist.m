function ensure_file_does_not_exist(raw_file_path)
    if isempty(raw_file_path) ,
        error('File path cannot be empty') ;
    end
    file_path = absolute_filename(raw_file_path) ;
    if isempty(file_path) ,
        error('File path cannot be empty') ;
    elseif exist(file_path, 'file') ,
        delete(file_path)
    else
        % do nothing, all is well
    end
end
