function ensure_parent_folder_exists(raw_file_path)
    file_path = absolute_filename(raw_file_path) ;
    parent_folder_path = fileparts(file_path) ;
    ensure_folder_exists(parent_folder_path) ;
end
