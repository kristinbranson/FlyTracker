function result = absolute_filename_passing_empty(filename)
    % Like absolute_filename(), but empty input leads to '' as output.
    if isempty(filename) ,
        result = '' ;
    else
        result = absolute_filename(filename) ;
    end
end
