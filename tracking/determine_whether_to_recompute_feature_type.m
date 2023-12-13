function [do_recompute, output_folder_path] = ...
        determine_whether_to_recompute_feature_type(feature_type_string, folder_name_template, parent_folder_path)
    % Try to find a folder matching folder_name_template within
    % parent_folder_path.  On return, do_recompute is true iff exactly one such
    % folder can be found, and output_folder_path is the path to that folder.  If
    % more than one match is found, issue a warning stating as much (using
    % feature_type_string in the warning message to indicate which feature type is
    % problematic).  Used to determine whether to recompute JAABA/CSV features
    % after indentity corrections are done in the visualizer.
    folder_names_matching_JAABA = folder_names_matching_template(parent_folder_path, folder_name_template) ;
    if length(folder_names_matching_JAABA) == 0 ,  %#ok<ISMT>
        do_recompute = false ;
        output_folder_path = [] ;
    elseif length(folder_names_matching_JAABA) == 1 ,
        do_recompute = true ;
        output_folder_path = fullfile(parent_folder_path, folder_names_matching_JAABA{1}) ;
    else
        % Should we issue a warning here?
        warning('Not saving %s features b/c more than one folder matching "%s" template in %s', ...
                feature_type_string, folder_name_template, parent_folder_path) ;
        do_recompute = false ;
        output_folder_path = [] ;
    end
end
