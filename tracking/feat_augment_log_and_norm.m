function [logfeat, normfeat] = feat_augment_log_and_norm()
    % take log of the following features
    logfeat = {'vel','ang_vel','min_wing_ang','max_wing_ang','fg_body_ratio'};    
    % normalize the following features
    normfeat = {'mean_wing_length','axis_ratio','contrast'};
end
