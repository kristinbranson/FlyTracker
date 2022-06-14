function result = replace_extension(file_name, ext)
    [folder_name, base_file_name] = fileparts(file_name) ;
    result_name = strcat(base_file_name, ext) ;
    result = fullfile(folder_name, result_name) ;
end
