function set_up_parpool_for_flytracker(options)
    n_cores = get_maximum_core_count() ;  % works on LSF node    
    options.num_cores = min(n_cores,options.num_cores);
    % open parallel pool if not already open
    if options.num_cores > 1
        try
            open_pool = 1;
            if ~isempty(gcp('nocreate'))
                par = gcp;
                n_workers = par.NumWorkers;
                if n_workers == options.num_cores
                    open_pool = 0;
                else
                    delete(gcp);
                end
            end
            if open_pool
                parpool(options.num_cores);
            end
        catch
            options.num_cores = 1;
            str = 'Could not open parallel pool. Using single thread.';
            disp(str);
        end
    end
end
