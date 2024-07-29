function test_all(do_try)
    % Setting do_try to false is useful for debugging
    
    if ~exist('do_try', 'var') || isempty(do_try) ,
        do_try = true ;
    end
    
    % get the name of all the test functions
    this_script_file_path = horzcat(mfilename('fullpath'), '.m') ;
    [this_script_folder_path, this_script_file_name] = fileparts2(this_script_file_path) ;
    raw_test_file_names = simple_dir(fullfile(this_script_folder_path,'*.m')) ;
    test_file_names = setdiff(raw_test_file_names, this_script_file_name) ;
    
    % run each of the tests
    test_count = length(test_file_names) ;
    did_pass_from_test_index = false(1, test_count) ;
    for test_index = 1 : test_count ,
        test_file_name = test_file_names{test_index} ;
        test_function_name = test_file_name(1:end-2) ;
        if do_try ,
            try                
                feval(test_function_name) ;
                did_pass_from_test_index(test_index) = true ;
            catch me
                fprintf('Test %s() errored:\n', test_function_name) ;
                fprintf('%s', me.getReport()) ;
            end
        else
            feval(test_function_name) ;
            did_pass_from_test_index(test_index) = true ;
        end
    end    
    pass_count = sum(did_pass_from_test_index) ;
    if pass_count == test_count ,
        fprintf('All tests passed (%d/%d).\n', pass_count, test_count) ;
    else
        fprintf('Some tests failed.  %d/%d tests passed.\n', pass_count, test_count) ;
    end
end
