function learn_data = feat_augment_data(data, names)
    [logfeat, normfeat] = feat_augment_log_and_norm() ;
    epsi = 0.001;        
    % use floowing wavelets to take 1st and 2nd derivatives of features    
    wavelets = [0 0.5 -0.5 0 0;            % tight 1st deriv gauss
                0 0.25 -0.5 0.25 0];       % tight 2nd deriv gauss
    n_flies = size(data,1);    
    n_frames = size(data,2);
    n_feats = size(data,3);
    learn_data = zeros(n_flies,n_frames,n_feats*3);    
    % augment each feature for all flies
    for s=1:n_flies
        for i=1:n_feats
            % median normalize certain features
            if ismember(names{i},normfeat)
                denom = nanmedian(data(s,:,i));
                if denom ~= 0 && ~isnan(denom)
                    data(s,:,i) = data(s,:,i)/denom;
                end
            end
            % take the log of certain features
            if ismember(names{i},logfeat)
                if strcmp(names{i},'ang_vel')
                    data(s,:,i) = log10(data(s,:,i)+epsi*0.001);
                else
                    data(s,:,i) = log10(data(s,:,i)+epsi);
                end
            end
            learn_data(s,:,i) = data(s,:,i);
            % apply wavelets to each feature vector
            idx = n_feats + (i-1)*2;
            responses = conv(learn_data(s,:,i),wavelets(1,:),'valid');
            buff_left = floor((n_frames-numel(responses))/2);
            buff_right = ceil((n_frames-numel(responses))/2);
            learn_data(s,1:buff_left,idx+1) = responses(1);
            learn_data(s,buff_left+1:end-buff_right,idx+1) = responses;
            learn_data(s,end-buff_right+1:end,idx+1) = responses(end);
            responses = conv(learn_data(s,:,i),wavelets(2,:),'valid');
            buff_left = floor((n_frames-numel(responses))/2);
            buff_right = ceil((n_frames-numel(responses))/2);
            learn_data(s,1:buff_left,idx+2) = responses(1);
            learn_data(s,buff_left+1:end-buff_right,idx+2) = responses;
            learn_data(s,end-buff_right+1:end,idx+2) = responses(end);
        end      
    end    
end
