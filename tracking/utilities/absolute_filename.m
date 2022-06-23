function filename_abs = absolute_filename(filename)
    % Convert a filename to an absolute path.
    if is_filename_absolute(filename)
        filename_abs = filename ;
    else
        filename_abs = fullfile(pwd(), filename) ;
    end

end
