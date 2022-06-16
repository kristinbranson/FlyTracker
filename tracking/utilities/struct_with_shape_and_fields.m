function result = struct_with_shape_and_fields(shape, field_names) 
    if isempty(field_names) ,
        empty = struct([]) ;
        result = reshape(empty, shape) ;
    else        
        empty = cell(shape) ;  %#ok<NASGU>
        argument_list_as_string = '' ;
        field_count = length(field_names) ;
        for i = 1 : field_count ,
            field_name = field_names{i} ;            
            if i<field_count ,
                part_for_this_field = sprintf('''%s'', empty, ', field_name) ;
            else
                part_for_this_field = sprintf('''%s'', empty', field_name) ;
            end
            argument_list_as_string = horzcat(argument_list_as_string, part_for_this_field) ;  %#ok<AGROW>
        end
        expression = sprintf('struct(%s)', argument_list_as_string) ;
        result = eval(expression) ;
    end
end
