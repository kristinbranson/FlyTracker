function result = folder_names_matching_template(parent_folder_name, template)
    % Return folder names matching the template within parent_folder_name
    s_from_file_index = dir(fullfile(parent_folder_name, template)) ;
    name_from_file_index = { s_from_file_index.name } ;   
    is_folder_from_file_index = [ s_from_file_index.isdir ] ;   
    result = name_from_file_index(is_folder_from_file_index) ;
end
