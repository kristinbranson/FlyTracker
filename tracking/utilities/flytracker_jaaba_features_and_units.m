function [personal_feat, enviro_feat, relative_feat, personal_units, enviro_units, relative_units] = flytracker_jaaba_features_and_units()
    % names of features to be computed
    personal_feat = {'vel','ang_vel','min_wing_ang','max_wing_ang',...
                     'mean_wing_length','axis_ratio','fg_body_ratio','contrast'};
    enviro_feat   = {'dist_to_wall'};
    relative_feat = {'dist_to_other','angle_between','facing_angle','leg_dist'};         
    % units of features to be computed
    personal_units = {'mm/s','rad/s','rad','rad','mm','ratio','ratio',''};
    enviro_units = {'mm'};
    relative_units = {'mm','rad','rad','mm'};
end