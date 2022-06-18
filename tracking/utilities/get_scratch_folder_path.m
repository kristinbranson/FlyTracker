function result = get_scratch_folder_path()
    if ispc() ,
        result = tempdir() ;
    elseif ~isempty(getenv('LSF_VERSION')) ,
        % We assume we're on a cluster node
        user_name = get_user_name() ;
        result = fullfile('/scratch', user_name) ;
    else
        result = tempdir() ;
    end
end
