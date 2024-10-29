
% Compute features from raw tracking data.
%
% To compute features, use:
%
%    feat = feat_compute(trk, calib)
%
% where:
%
%    trk         - tracking structure, obtained from previous steps of
%                   tracker (stored in *-track.mat)
%    calib       - calibration structure, obtained from calibration step
%                   (stored in calibration.mat)
%
% returns:
%
%    feat.       - feature structure
%       names    - names of all features
%       units    - units of each feature
%       data     - n_flies x n_frames x n_features matrix containing the 
%                   feature values of all flies at each frame
%
% All features are computed to be independent of resolution (FPS,PPM)
%
function feat = feat_compute(trk, calib, do_compute_relative)
    if ~exist('do_compute_relative', 'var') || isempty(do_compute_relative) ,
      do_compute_relative = true ;  % true for backwards-compatibility
    end
    % store video resolution parameters for later normalization
    pix_per_mm = calib.PPM;
    FPS = calib.FPS;
    % names, units of features to be computed
    [personal_feat, enviro_feat, relative_feat, personal_units, enviro_units, relative_units] = feat_names_and_units() ;
    % kernel for smoothing output    
    smooth_kernel = [1 2 1]/4;
    % note which flies share a chamber ("buddies") to keep track of whether 
    %  features of buddy have been computed
    n_flies = size(trk.data,1);
    if isfield(trk,'flies_in_chamber')
        obj_count = zeros(size(trk.flies_in_chamber));
        for c=1:numel(obj_count)
            obj_count(c) = numel(trk.flies_in_chamber{c});
        end
        n_objs = max(obj_count);
        if do_compute_relative && (n_objs == 2)
            buddy = zeros(1,n_flies);
            for i=1:numel(trk.flies_in_chamber)
                flies = trk.flies_in_chamber{i};
                if numel(flies) == 2
                    buddy(flies(1)) = flies(2);
                    buddy(flies(2)) = flies(1);
                end
            end            
            bud_complete = false(size(buddy));
        end
    else
        n_objs = n_flies;
        if do_compute_relative && (n_objs == 2)
            buddy = [2 1];
            bud_complete = false(size(buddy));
        end
    end
    % initialize features
    n_frames = size(trk.data,2);
    n_trkfeat = size(trk.data,3);
    n_feats = numel(personal_feat) + do_compute_relative*(n_objs==2)*numel(relative_feat) + numel(enviro_feat);
    track = trk.data(:,:,:);
    features = nan(n_flies,n_frames,n_feats);    
    % compute distance to chambers for all pixels
    mask = zeros(size(calib.mask));
    for i=1:numel(calib.masks)
        mask = mask | calib.masks{i};
    end
    dists = bwdist(1-mask);    
    % interpolate track values
    for s=1:size(trk.data,1)
        for f_ind=1:n_trkfeat
            vec = track(s,:,f_ind);
            invalid = isnan(vec);
            cc = bwconncomp(invalid);
            for c=1:cc.NumObjects
                fr_start = cc.PixelIdxList{c}(1)-1;
                fr_end   = cc.PixelIdxList{c}(end)+1;
                frs = fr_start:fr_end;
                if fr_start < 1 || fr_end > n_frames
                    continue
                end
                piece = (vec(fr_end)-vec(fr_start))/(numel(frs)-1);
                coeffs = 0:(numel(frs)-1);
                vec(frs) = vec(fr_start) + coeffs * piece;
            end
            track(s,:,f_ind) = vec;
        end
    end
    % Compute features for all flies
    for s=1:n_flies
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% PERSONAL FEATURES
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % VELOCITY & ACCELERATION
        %  smooth out pos data
        x = track(s,:,1);
        y = track(s,:,2);
        x(2:end-1) = conv(x,smooth_kernel,'valid');
        y(2:end-1) = conv(y,smooth_kernel,'valid');
        %  calculate velocity
        x_diff = diff(x);
        y_diff = diff(y);
        pos_diff = (x_diff.^2 + y_diff.^2).^0.5;
        vel = [pos_diff(1) pos_diff] * FPS/pix_per_mm;
        features(s,:,1) = vel;
        
        % ANGULAR VELOCITY & ACCELERATION
        %  make angle data continuous
        ori = track(s,:,3);
        theta2 = ori(2:end);
        theta1 = ori(1:end-1);
        ori_diff = abs(mod(theta1+pi/2-theta2,pi)-pi/2);
        ang_vel = [ori_diff(1) ori_diff] * FPS;
        ang_vel(2:end-1) = conv(ang_vel,smooth_kernel,'valid');
        features(s,:,2) = ang_vel; % should be invariant of turning left or right

        % WING ANGLES
        ang1 = abs(track(s,:,14));
        ang1(2:end-1) = conv(ang1,smooth_kernel,'valid');
        len1 = track(s,:,15);
        ang2 = abs(track(s,:,16));   
        ang2(2:end-1) = conv(ang2,smooth_kernel,'valid');
        len2 = track(s,:,17);
        mean_wing_lengths = nanmean([len1(:) len2(:)],2);
        min_angles = nanmin([ang1(:) ang2(:)],[],2);
        max_angles = nanmax([ang1(:) ang2(:)],[],2);        
        mean_wing_lengths(2:end-1) = conv(mean_wing_lengths,smooth_kernel,'valid');
        features(s,:,3) = min_angles;
        features(s,:,4) = max_angles;      
        features(s,:,5) = mean_wing_lengths / pix_per_mm;

        % AXIS RATIO
        axis_ratio = track(s,:,4)./track(s,:,5);
        axis_ratio(2:end-1) = conv(axis_ratio,smooth_kernel,'valid');
        features(s,:,6) = axis_ratio;
        
        % FG / BODY RATIO
        fg_body_ratio = track(s,:,7)./track(s,:,6);      
        fg_body_ratio(2:end-1) = conv(fg_body_ratio,smooth_kernel,'valid');
        features(s,:,7) = fg_body_ratio;
        
        % BODY CONTRAST
        body_contrast = track(s,:,8);
        body_contrast(2:end-1) = conv(body_contrast,smooth_kernel,'valid');
        features(s,:,8) = body_contrast;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% RELATIVE TO CHAMBER
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        x = min(max(1,round(x)),size(mask,2));
        y = min(max(1,round(y)),size(mask,1));
        inds = sub2ind(size(mask),y,x);
        wall_dist = dists(inds);
        features(s,:,9) = wall_dist / pix_per_mm;        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% RELATIVE TO OTHER FLY
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        center = [track(s,:,1)' track(s,:,2)'];
        vec_rot = [cos(ori)' -sin(ori)'];
        if do_compute_relative && n_objs==2
            if bud_complete(s), continue; end % only need to calculate these once
            bud = buddy(s);
            if bud==0, continue; end % this fly has no buddy
            %  DISTANCE TO OTHER FLY (+ VELOCITY & ACCELERATION)
            center2 = [track(bud,:,1)' track(bud,:,2)'];
            vec_between = center2-center;
            norm_between = (vec_between(:,1).^2 + vec_between(:,2).^2).^.5;
            dist_between = norm_between;
            dist_between(2:end-1) = conv(dist_between,smooth_kernel,'valid');
            features(s,:,10) = dist_between / pix_per_mm;
            features(bud,:,10) = features(s,:,10);
                       
            % compute angles
            ori2 = track(bud,:,3);
            vec_rot2 = [cos(ori2)' -sin(ori2)'];
            angle_between = acos(dot(vec_rot,vec_rot2,2));
            vec_between = vec_between./repmat(norm_between,1,2);
            facing_angle1 = acos(dot(vec_rot,vec_between,2));
            facing_angle2 = acos(dot(vec_rot2,-vec_between,2));          
    
            % ANGLE BETWEEN FLIES
            angle_between(2:end-1) = conv(angle_between,smooth_kernel,'valid');
            features(s,:,11) = angle_between;
            features(bud,:,11) = features(s,:,11);

            % FACING ANGLE 
            facing_angle1(2:end-1) = conv(facing_angle1,smooth_kernel,'valid');
            facing_angle2(2:end-1) = conv(facing_angle2,smooth_kernel,'valid');
            features(s,:,12) = facing_angle1;
            features(bud,:,12) = facing_angle2;

            % LEG DIST TO OTHER FLY & BODY WING DIST TO OTHER FLY
            fg_dist = track(s,:,9);
            fg_dist(2:end-1) = conv(fg_dist,smooth_kernel,'valid');
            features(s,:,13) = fg_dist / pix_per_mm;
            features(bud,:,13) = features(s,:,13);
            
            bud_complete(s) = 1;
            bud_complete(bud) = 1;
        end       
    end    
    % store variables in feat structure
    names = [personal_feat enviro_feat];   
    units = [personal_units enviro_units];
    if do_compute_relative && n_objs==2
        names = [names relative_feat];
        units = [units relative_units];
    end
    feat.names = names;
    feat.units = units;
    feat.data = features;
end
