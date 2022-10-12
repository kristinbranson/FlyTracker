function [name, is_folder, file_size, modification_datetime] = simple_dir(template)
    s_raw = dir(template) ;
    name_raw = {s_raw.name} ;
    is_bs = ismember(name_raw, {'.', '..'}) ;
    s = s_raw(~is_bs) ;
    name = {s.name} ;
    is_folder = [s.isdir] ;
    file_size = [s.bytes] ;
    modification_datetime = datetime([s.datenum], 'ConvertFrom', 'datenum', 'TimeZone', 'local') ;
    modification_datetime.TimeZone = 'UTC' ;  
        % This does the proper conversion from the local timezone to UTC.
        % I.e. this doesn't change the time point represented, it only
        % changes the time zone it is expressed in.
end
