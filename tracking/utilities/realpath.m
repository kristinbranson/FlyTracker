function result = realpath(file_name)
    if ispc() ,
        result = GetFullPath(file_name) ;
    else  
        stdout = system_from_list_with_error_handling({'realpath', file_name}) ;
        result = strtrim(stdout) ;
    end
end
