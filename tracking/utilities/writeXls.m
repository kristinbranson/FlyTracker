function writeXls(output_file_or_folder_name, data, names)
    % Try to write the features to a .xls file, but fall back to writing a folder full of
    % .csv files (one per fly) if xlswrite() is not working (e.g. on Linux).
    original_warning_state = warning('off') ;
    cleaner =  onCleanup(@()(warning(original_warning_state))) ;
    xls_file_name = strcat(output_file_or_folder_name, '.xls') ;
    [~, msg] = xlswrite(xls_file_name, ones(10)) ;
    did_xls_writing_test_fail = contains(msg.message,'could not', 'IgnoreCase', true) || contains(msg.message,'unable', 'IgnoreCase', true) ;
    use_xls = ~did_xls_writing_test_fail ;
    n_flies = size(data,1);
    n_frames = size(data,2);
    n_feats = size(data,3);
    if use_xls ,
        ensure_file_does_not_exist(xls_file_name) ;  % delete test file
        % write to xls
        for i=1:n_flies
            sheet = ['fly' num2str(i)];
            fly_data = data(i,:,:);
            fly_data = reshape(fly_data,n_frames,n_feats);
            xlswrite(xls_file_name,names,sheet);
            xlswrite(xls_file_name,fly_data,sheet,'A2');
        end
    else    
        csv_folder_name = strcat(output_file_or_folder_name, '.csv') ;
        ensure_folder_does_not_exist(csv_folder_name) ;
        ensure_folder_exists(csv_folder_name) ;
        % write to folder of .csv files
        for i=1:n_flies
            fly_data = data(i,:,:);
            fly_data = reshape(fly_data,n_frames,n_feats);
            fly_file_path = fullfile(csv_folder_name, ['fly' num2str(i) '.csv']);
            fid = fopen(fly_file_path,'w');
            fprintf(fid, '%s,', names{1:end-1});
            fprintf(fid, '%s\n', names{end});
            fclose(fid);
            dlmwrite(fly_file_path,fly_data,'-append');
        end
    end
end

