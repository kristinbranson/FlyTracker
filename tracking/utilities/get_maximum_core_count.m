function result = get_maximum_core_count()
    % Like feature('numcores'), but gives the right answer on an LSF worker
    % node.    
    LSF_core_count_as_string_maybe = getenv('LSB_MAX_NUM_PROCESSORS') ;
    if isempty(LSF_core_count_as_string_maybe) ,
        physical_core_count = feature('numcores') ;
        result = physical_core_count ;
    else
        LSF_core_count_as_string = LSF_core_count_as_string_maybe ;
        LSF_core_count = str2double(LSF_core_count_as_string) ;
        result = LSF_core_count ;
    end
end
