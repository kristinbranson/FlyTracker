function n_cores_to_use = set_up_parpool_for_flytracker(options)
    n_cores_on_host = get_maximum_core_count() ;  % works on LSF node    
    n_cores_to_use = min(n_cores_on_host, options.num_cores) ;
    % open parallel pool if not already open
    if n_cores_to_use > 1
        try
            open_pool = 1;
            if ~isempty(gcp('nocreate'))
                par = gcp;
                n_workers = par.NumWorkers;
                if n_workers == n_cores_to_use
                    open_pool = 0;
                else
                    delete(gcp);
                end
            end
            if open_pool
                parpool(n_cores_to_use);
            end
        catch
            str = 'Could not open parallel pool. Using single thread.';
            disp(str);
        end
    end
end
