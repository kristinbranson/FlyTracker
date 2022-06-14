function stdout = system_from_list_with_error_handling(command_line_as_list)
    % Run the system command, but taking a list of tokens rather than a string.
    % Each element of command_line_as_list is escaped for bash, then composed into a
    % single string, then submitted to system_with_error_handling().
    
    % Escape all the elements of command_line_as_list
    escaped_command_line_as_list = cellfun(@escape_string_for_bash, command_line_as_list, 'UniformOutput', false) ;
    
    % Build up the command line by adding space between elements
    command_line = space_out(escaped_command_line_as_list) ;

    % Actually run the command
    stdout = system_with_error_handling(command_line) ;
end



function result = space_out(list)
    result = '' ;
    count = length(list) ;
    for i = 1 : count ,
        if i==1 ,
            result = list{i} ;
        else
            result = [result ' ' list{i}] ;  %#ok<AGROW>
        end 
    end
end