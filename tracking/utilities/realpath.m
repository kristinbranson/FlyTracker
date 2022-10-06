function result = realpath(file_name)
    stdout = system_from_list_with_error_handling({'realpath', file_name}) ;
    result = strtrim(stdout) ;
end
