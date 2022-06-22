function write_csvs(output_csv_folder_name, data, names)    
    % Write features to a folder full of csv files, one file per fly.
    ensure_folder_does_not_exist(output_csv_folder_name) ;
    ensure_folder_exists(output_csv_folder_name) ;
    n_flies = size(data,1) ;
    n_frames = size(data,2) ;
    n_feats = size(data,3) ;
    fly_file_name_template = synthesize_fly_file_name_template(n_flies) ;
    for fly_index = 1:n_flies ,
        data_for_fly = data(fly_index,:,:) ;
        data_for_fly = reshape(data_for_fly, n_frames, n_feats) ;
        fly_file_name = sprintf(fly_file_name_template, fly_index) ;
        fly_file_path = fullfile(output_csv_folder_name, fly_file_name) ;
        fid = fopen(fly_file_path,'w');
        fprintf(fid, '%s,', names{1:end-1});
        fprintf(fid, '%s\n', names{end});
        fclose(fid);
        dlmwrite(fly_file_path, data_for_fly, '-append') ;
    end
end



function result = synthesize_fly_file_name_template(n_flies)
    % Synthesize an sprintf template for the fly file name
    % e.g. 25 -> 'fly%02d.csv'
    % e.g. 1000 -> 'fly%04d.csv'
    digit_count = get_digit_count(n_flies) ;
    result = horzcat('fly%0', num2str(digit_count), 'd.csv') ;
end



function result = get_digit_count(n)
    result = length(num2str(n)) ;
end
