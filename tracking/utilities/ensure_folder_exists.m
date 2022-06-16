function ensure_folder_exists(raw_folder_path)
    folder_path = absolute_filename(raw_folder_path) ;
    ensure_folder_exists_helper(folder_path) ;
end



function ensure_folder_exists_helper(folder_path)
    if exist(folder_path, 'file') ,
        if exist(folder_path, 'dir') ,
            % do nothing, all is well, return
        else
            error('Want to create folder %s, but a file (not a folder) already exists at that location', folder_path) ;
        end
    else
        parent_folder_path = fileparts(folder_path) ;
        ensure_folder_exists_helper(parent_folder_path) ;
        mkdir(folder_path) ;
    end        
end
