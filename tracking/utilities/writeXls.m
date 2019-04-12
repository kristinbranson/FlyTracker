

function writeXls(savename,data,names)    
    warning off
    [~,msg] = xlswrite([savename '.xls'],ones(10));
    use_xls = ~(numel(msg.message)>8 && ...
                strcmp(msg.message(1:9),'Could not'));
    n_flies = size(data,1);
    n_frames = size(data,2);
    n_feats = size(data,3);
    if use_xls
        delete([savename '.xls'])
        % write to xls
        for i=1:n_flies
            sheet = ['fly' num2str(i)];
            dat = data(i,:,:);
            dat = reshape(dat,n_frames,n_feats);
            xlswrite([savename '.xls'],names,sheet);
            xlswrite([savename '.xls'],dat,sheet,'A2');
        end
    else    
        delete([savename '.csv'])
        % write to csv folder
        if ~exist(savename,'dir')
            mkdir(savename);
        end
        for i=1:n_flies
            dat = data(i,:,:);
            dat = reshape(dat,n_frames,n_feats);
            filename = fullfile(savename,['fly' num2str(i) '.csv']);
            fid = fopen(filename,'w');
            fprintf(fid, '%s,', names{1:end-1});
            fprintf(fid, '%s\n', names{end});
            fclose(fid);
            dlmwrite(filename,dat,'-append');
        end
    end
    warning on
end

