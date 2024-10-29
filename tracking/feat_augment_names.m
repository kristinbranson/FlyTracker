function aug_names = feat_augment_names(names)
    [logfeat, normfeat] = feat_augment_log_and_norm() ;
    % update names to match their augmentation
    simple_aug_names = cell(1,0) ;
    diff_aug_names = cell(1,0) ;
    for i=1:numel(names)      
        name = names{i} ;
        if ismember(names{i},normfeat)
            aug_name = ['norm_' name];
        elseif ismember(names{i},logfeat)
            aug_name = ['log_' name];
        else
            aug_name = names{i} ;
        end        
        simple_aug_names{1,i} = aug_name ;
        diff_aug_names{1,end+1} = [aug_name '_diff1'];  %#ok<AGROW> 
        diff_aug_names{1,end+1} = [aug_name '_diff2'];  %#ok<AGROW> 
    end
    aug_names = horzcat(simple_aug_names, diff_aug_names) ;
end
