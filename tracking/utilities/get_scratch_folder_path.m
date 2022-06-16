function result = get_scratch_folder_path()
    host_name = get_host_name() ;
    if ispc() ,
        result = tempdir() ;
    elseif isequal(host_name, 'taylora-ws1') ,
        result = tempdir() ;
    else
        % We assume we're on a cluster node
        user_name = get_user_name() ;
        result = fullfile('/scratch', user_name) ;
    end
end
