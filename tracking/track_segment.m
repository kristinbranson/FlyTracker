
% Segment foreground pixels into wings and legs, and disambiguate body
% orientation based on: a) wing positions, b) velocity, c) consistency
%
% To segment detections, use:
%
%   trks = track_segment(trks, calib, [show progress], [chamber_str])
%
% where [] denotes an optional parameter and:
%
%    trks              - traklets obtained from track_match
%    calib             - calibration obtained from calibrator or tracker_job_calibrate
%    show_progress     - display progress indicator (default 1)
%    chamber_str       - indicates which chamber is being processed (default '')
%
% returns:
%
%    trks              - same as the input but with the following changes:
%         .frame_data     - now contains .seg with fly segmentations
%         .sequences      - now containes .track which holds the fly's raw
%                           tracking data (position, orientation, 
%                           wing positions, leg positions, ...)
%         .names          - new field containing names of fields in .track                        
%
function trks = track_segment(trks, calib, show_progress, chamber_str)
    params = calib.params;
    params.mean_axis_ratio = params.mean_major_axis/params.mean_minor_axis;    
    n_frames = numel(trks.frame_data);
    if nargin < 3 || isempty(show_progress)
        show_progress = 1;
    end    
    if nargin < 4
        chamber_str = '';
    end
    
    % check whether trks have been matched
    trks_matched = isfield(trks,'sequences');
        
    % set waitbar
    if show_progress
        display_available = feature('ShowFigureWindows');
        waitstr = 'Segmenting flies';
        waitstr = [chamber_str waitstr ': frames ' num2str(trks.frame_ids(1)) ...
                        '-' num2str(trks.frame_ids(end)+1)];
        waitstep = max(1,floor(n_frames/100));  
        if display_available
            multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
            waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
        else
            percent = 0;
            fprintf(1,[waitstr ': %d%%'], percent); 
        end     
    end
    
    % compute velocities (to use for orientation and wing disambiguation)
    if trks_matched
        n_seq = numel(trks.sequences);
        velocities = cell(1,n_seq);
        orientations = cell(1,n_seq);
        for s=1:n_seq
            frms = trks.sequences{s}.time_start:trks.sequences{s}.time_end;
            pose = zeros(numel(frms),3);
            for i=1:numel(frms)
                fr = frms(i);
                obj_id = trks.sequences{s}.obj_list(i);
                pose(i,1:2) = trks.frame_data{fr}.body_props(obj_id).Centroid;
                pose(i,3) = trks.frame_data{fr}.body_props(obj_id).Orientation;
            end
            x = pose(:,1);   y = pose(:,2);   oris = pose(:,3)*pi/180;
            dx = zeros(size(x));   dy = zeros(size(y));
            dx(2:end-1) = (x(3:end)-x(1:end-2))/2;
            dy(2:end-1) = (y(3:end)-y(1:end-2))/2;
            vel = (dx.^2 + dy.^2).^.5;
            velocities{s} = [vel dx dy];
            
            % adjust ori backward to velocity
            inds = find(vel>params.vel_thresh);
            if isempty(inds), [~,inds] = max(vel); end
            for i=inds(1):-1:1
                ori = oris(i);
                vec_rot = [cos(ori) -sin(ori)];
                if i==inds(1)
                    % use velocity to determine orientation
                    vector = [dx(i) dy(i)];
                    vector = vector / norm(vector);
                elseif i<numel(vel)
                    % use consistency with next frame
                    ori_prev = oris(i+1);
                    vector = [cos(ori_prev) -sin(ori_prev)];
                end
                angle = acos(dot(vec_rot,vector)) /pi*180;                
                if angle > 90
                    ori = ori + (-1)^(ori>0)*pi;
                    oris(i) = ori;
                end
            end
            % adjust ori forward according to velocity
            inds(end+1) = numel(vel)+1;
            for ind=1:numel(inds)-1
                for i=inds(ind):inds(ind+1)-1
                    ori = oris(i);
                    vec_rot = [cos(ori) -sin(ori)];
                    if i==inds(1)
                        % use velocity to determine orientation
                        vector = [dx(i) dy(i)];
                        vector = vector / norm(vector);
                    elseif i>1
                        % use consistency with previous frame
                        ori_prev = oris(i-1);
                        vector = [cos(ori_prev) -sin(ori_prev)];
                    end
                    angle = acos(dot(vec_rot,vector)) /pi*180;                
                    if angle > 90
                        ori = ori + (-1)^(ori>0)*pi;
                        oris(i) = ori;
                    end
                end
            end
            orientations{s} = oris;         
        end
        seq_bod = zeros(0,2);
    end

    for i=1:n_frames
        detect = trks.frame_data{i};  
        n_fgs = detect.fg_cc.NumObjects;
        n_bods = detect.body_cc.NumObjects;
        
        % initialize variables to be computed
        b_wing_pixels = cell([n_bods 1]);
        b_wing_pts    = cell([n_bods 1]);
        b_leg_pixels  = cell([n_bods 1]);
        b_leg_pts     = cell([n_bods 1]);
        min_fg_dist   = zeros([n_bods 1]);

        % update waitbar
        if show_progress
            if display_available && mod(i,waitstep) == 0 
                abort = multiWaitbar(waitstr,i/n_frames);
                if abort, trks = 0; return; end
            elseif mod(i,waitstep) == 0
                for d=1:numel(num2str(percent))+1
                   fprintf(1,'\b');
                end
                percent = round(i/n_frames*100);
                fprintf(1,'%d%%',percent);                                 
            end           
        end        
        
        % map bodies to sequences
        if trks_matched
            seqs = trks.frame_seq_list{i};
            seq_bod_prev = seq_bod;
            seq_bod = zeros(numel(seqs),2);
            for s=1:numel(seqs)            
                t_s = trks.sequences{seqs(s)}.time_start;
                bod = trks.sequences{seqs(s)}.obj_list(i-t_s+1);
                seq_bod(s,:) = [seqs(s) bod];
            end
        end
        
        % Compute expensive features only on videos whose resolution 
        % allows for reasonable detection of wings and legs.
        %  (3 pixels per mm is an absolute minimum)
        if calib.PPM < 3 && trks_matched
            bods = 1:detect.body_cc.NumObjects;
            for b=1:numel(bods)
                % check whether velocity can determine orientation                    
                seq_id = seq_bod(seq_bod(:,2)==bods(b),1);
                fr_idx = i - trks.sequences{seq_id}.time_start+1;
                vel = velocities{seq_id}(fr_idx,1);
                ori = orientations{seq_id}(fr_idx);
                rot_vec = [cos(ori) -sin(ori)];
                vector = rot_vec;
                % disambiguate using velocity or previous frame                        
                if vel > params.vel_thresh*.5
                    % use velocity
                    vector = velocities{seq_id}(fr_idx,2:3);
                    vector = vector / norm(vector);
                elseif i>1
                    % use previous orientation
                    if fr_idx > 1
                        ori_prev = orientations{seq_id}(fr_idx-1); 
                    else
                        detect_prev = trks.frame_data{i-1};
                        cmx = detection_match_costs(detect_prev,detect,calib.PPM);
                        idx_prev = [];
                        if numel(cmx) > 0
                            [~,m_bwd] = match(cmx);
                            bod_prev = m_bwd(bods(b));
                            idx_prev = find(seq_bod_prev(:,2)==bod_prev);
                        end
                        if isempty(idx_prev) 
                            ori_prev = ori;
                        else
                            seq_prev = seq_bod_prev(idx_prev,1);                                
                            fr_prev = i-1 - trks.sequences{seq_prev}.time_start+1;
                            ori_prev = orientations{seq_prev}(fr_prev);   
                        end
                    end
                    vector = [cos(ori_prev) -sin(ori_prev)];                           
                end
                angle = acos(dot(rot_vec,vector)) /pi*180;                
                if angle > 90
                    ori = ori + (-1)^(ori>0)*pi;
                    orientations{seq_id}(fr_idx) = ori;
                end   
                % store disambiguated orientation
                detect.body_props(bods(b)).Orientation = ori/pi*180;                    
            end
        elseif calib.PPM >= 3
            % find shortest fg distance between a fly and all other flies
            bod_dists = nan(n_bods);
            for b1 = 1:n_bods
                pos1 = detect.body_props(b1).Centroid;
                for b2 = b1+1:n_bods
                    pos2 = detect.body_props(b2).Centroid;
                    bod_dists(b1,b2) = (sum((pos1-pos2).^2))^.5;
                    bod_dists(b2,b1) = bod_dists(b1,b2);
                end
            end
            fg_dists = nan(n_bods);        
            fg_pixels = cell(n_fgs,2);
            for fg_idx=1:n_fgs
                [I,J] = ind2sub(detect.fg_cc.ImageSize,detect.fg_cc.PixelIdxList{fg_idx});
                fg_pixels{fg_idx} = [I(:) J(:)];
            end  
            for b1 = 1:n_bods
                fg_idx = detect.body_fg(b1);
                [~,b2] = nanmin(bod_dists(b1,:));
                fg_idx2 = detect.body_fg(b2);
                if fg_idx==fg_idx2
                    fg_dists(b1,b2) = 0;
                    fg_dists(b2,b1) = 0;
                else
                    fg_im = zeros(detect.fg_cc.ImageSize);
                    fg_im(detect.fg_cc.PixelIdxList{fg_idx2}) = 1;
                    fg_dist = bwdist(fg_im);
                    fg_dists(b1,b2) = min(fg_dist(detect.fg_cc.PixelIdxList{fg_idx}));
                    fg_dists(b2,b1) = fg_dists(b1,b2);
                end
            end            
            min_fg_dist = nanmin(fg_dists);

            % segment legs and wings from foreground
            imsize = detect.fg_cc.ImageSize;
            zeroim = zeros(imsize);
            buff = params.fg_mask_buff;
            for fg_idx = 1:n_fgs
                % extract foreground image
                pixels = fg_pixels{fg_idx};
                I = pixels(:,1); J = pixels(:,2);
                bbox = [max(1,min(I)-buff) min(imsize(1),max(I)+buff), ... 
                        max(1,min(J)-buff) min(imsize(2),max(J)+buff)];
                temp_im = zeroim;
                temp_im(detect.fg_cc.PixelIdxList{fg_idx}) = 1;
                fg_im = temp_im(bbox(1):bbox(2),bbox(3):bbox(4));
                % extract body image for that foreground
                bods = detect.fg_body{fg_idx};
                temp_im = zeroim;
                for bod=1:numel(bods)
                    temp_im(detect.body_cc.PixelIdxList{bods(bod)}) = bods(bod);
                end
                bod_im = temp_im(bbox(1):bbox(2),bbox(3):bbox(4));            
                fg_size = size(fg_im);

                % create body index map
                body_map = zeros(fg_size);
                for b = 1:numel(bods)
                    % get pixels in body
                    pix = find(bod_im == bods(b));
                    [x, y] = ind2sub(fg_size,pix);                    
                    try % create convex hull
                        k = convhull(x,y);
                        % compute interior + boundary of hull
                        x_min = min(x); x_max = max(x);
                        y_min = min(y); y_max = max(y);
                        xs = repmat((x_min:x_max).',[1 (y_max-y_min+1)]);
                        ys = repmat((y_min:y_max),  [(x_max-x_min+1) 1]);
                        in = inpolygon(xs,ys,x(k),y(k));
                        pix_in = sub2ind_faster(fg_size,xs(in),ys(in));                    
                    catch
                        pix_in = pix;
                    end
                    % dilate body
                    temp_map = zeros(fg_size);
                    temp_map(pix_in) = 1;
                    temp_map = imdilate(temp_map, params.strels{4});
                    % update boundary map
                    body_map(logical(temp_map)) = b;
                end
                % compute distance from bodies
                [bdist, blabel] = bwdist(body_map > 0);            

                % EXTRACT LEGS --------------------------------------------
                % erode and dilate foreground
                fg_e  = imerode(fg_im, params.strels{3});
                fg_ed = imdilate(fg_e, params.strels{4}); %making this bigger than for erode ensures that there won't be dummy legs along the border
                if numel(bods)>1
                    % check whether legs are the only thing connecting the 
                    % flies (fg_ed should then have 2 components)
                    fg_cc = bwconncomp(fg_ed);                    
                    if fg_cc.NumObjects==numel(bods)
                        fg_ed_im = zeros(fg_size);                        
                        for c=1:fg_cc.NumObjects
                            pix = fg_cc.PixelIdxList{c};
                            counts = hist(body_map(pix),1:numel(bods));
                            [~,idx] = max(counts); %bod = bods(idx);
                            fg_ed_im(fg_cc.PixelIdxList{c}) = idx;%bod;
                        end
                        fg_ed_im = imdilate(fg_ed_im,params.strels{1});
                    else
                        fg_ed_im = [];
                    end
                end
                % identify legs and joints
                is_leg = zeros(fg_size);
                fg_is_leg = ((fg_im-fg_e) & (~fg_ed));
                fg_body_dist = bwdist(fg_ed);
                fg_is_joint = (fg_body_dist < params.joint_dist_th) & fg_is_leg;
                % build leg pixel map
                cc = bwconncomp(fg_is_leg);
                valid = false(1,cc.NumObjects);
                for c = 1:(cc.NumObjects)
                    inds = cc.PixelIdxList{c};
                    area_joint = sum(fg_is_joint(inds));
                    if numel(inds)-area_joint >= area_joint && area_joint > 0 && area_joint <= params.joint_area_max
                        is_leg(inds) = 1;
                        valid(c) = 1;
                    end
                end
                cc.NumObjects = sum(valid);
                cc.PixelIdxList = cc.PixelIdxList(valid);
                % compute body -> leg adjacency
                bl_adjacency = cell([numel(bods) 1]);
                leg_sz = zeros(1,cc.NumObjects); % leg size
                leg_nb = zeros(1,cc.NumObjects); % #adjacent bodies
                for l = 1:cc.NumObjects
                    pix = cc.PixelIdxList{l};                    
                    leg_sz(l) = numel(pix);
                    if numel(bods)>1 && ~isempty(fg_ed_im)
                        bodies = unique(fg_ed_im(pix));
                        bodies = bodies(bodies>0);
                    else
                        bodies = unique(body_map(blabel(pix)));
                    end
                    leg_nb(l) = numel(bodies);
                    for nb = 1:numel(bodies)
                        b = bodies(nb);
                        bl_adjacency{b} = [bl_adjacency{b} l];
                    end
                end    
                % assign legs to bodies
                for b = 1:numel(bods)
                    ls = bl_adjacency{b};
                    if numel(ls) > 6
                        % use only 6 largest legs (that connect to fewest flies)
                        [~,sort_sz] = sort(leg_sz(ls),'descend');
                        [~,sort_nb] = sort(leg_nb(ls(sort_sz)),'ascend');
                        sortids = sort_sz(sort_nb);
                        ls = ls(sortids(1:6));
                    end
                    leg_pxls = vertcat(cc.PixelIdxList{ls});
                    [I,J] = ind2sub(fg_size,leg_pxls);                
                    leg_pxls = sub2ind_faster(imsize,I+bbox(1)-1,J+bbox(3)-1);
                    b_leg_pixels{bods(b)} = leg_pxls;
                    
                    % store extremal points of legs
                    pos = detect.body_props(bods(b)).Centroid;
                    pos(1) = pos(1)-bbox(3)+1; pos(2) = pos(2)-bbox(1)+1;  
                    pts = cell([numel(ls) 1]);
                    for lg=1:numel(ls)
                        l = ls(lg);
                        pix = cc.PixelIdxList{l};
                        [I,J] = ind2sub(fg_size,pix);
                        dists = (I-pos(2)).^2 + (J-pos(1)).^2;
                        [~, ind] = max(dists);
                        [x, y] = ind2sub(fg_size, pix(ind));
                        x = x+bbox(1)-1;
                        y = y+bbox(3)-1;
                        pts{lg} = [y x];
                    end
                    b_leg_pts{bods(b)} = pts;
                end              

                % EXTRACT WINGS -------------------------------------------
                % get body/wing map
                fg_is_body_wing = fg_im & (~is_leg) & fg_ed;
                % remove central bodies
                fg_is_wing = fg_is_body_wing & (body_map == 0);
                % compute connected wing components
                wing_cc = bwconncomp(fg_is_wing);
                % compute body -> wing adjacency
                bw_adjacency = cell([numel(bods) 1]);
                wb_adjacency = cell([wing_cc.NumObjects 1]);
                for w = 1:(wing_cc.NumObjects)
                    pix = wing_cc.PixelIdxList{w};
                    inds = bdist(pix) <= params.joint_dist_th;
                    pix = pix(inds);
                    bodies = unique(body_map(blabel(pix)));
                    for nb = 1:numel(bodies)
                        b = bodies(nb);
                        bw_adjacency{b} = [bw_adjacency{b} w];
                        wb_adjacency{w} = [wb_adjacency{w} b];
                    end
                end
                % assign wings to bodies
                for b = 1:numel(bods)
                    % get body pose
                    pos = detect.body_props(bods(b)).Centroid;
                    pos(1) = pos(1)-bbox(3)+1; pos(2) = pos(2)-bbox(1)+1;  
                    ori = detect.body_props(bods(b)).Orientation/180*pi;
                    major_ax = detect.body_props(bods(b)).MajorAxisLength/2;
                    minor_ax = detect.body_props(bods(b)).MinorAxisLength/2;
                    area = detect.body_props(bods(b)).Area;
                    % check whether velocity can determine orientation                    
                    if trks_matched
                        seq_id = seq_bod(seq_bod(:,2)==bods(b),1);
                        fr_idx = i - trks.sequences{seq_id}.time_start+1;
                        vel = velocities{seq_id}(fr_idx,1);
                        ori = orientations{seq_id}(fr_idx);
                        rot_vec = [cos(ori) -sin(ori)];
                        vector = rot_vec;
                        % disambiguate using velocity or previous frame                        
                        if vel > params.vel_thresh*.5 && numel(bods) == 1
                            % use velocity
                            vector = velocities{seq_id}(fr_idx,2:3);
                            vector = vector / norm(vector);
                        elseif i>1
                            % use previous orientation
                            if fr_idx > 1
                                ori_prev = orientations{seq_id}(fr_idx-1); 
                            else
                                detect_prev = trks.frame_data{i-1};                                
                                cmx = detection_match_costs(detect_prev,detect,calib.PPM);
                                idx_prev = [];
                                if numel(cmx) > 0
                                    [~,m_bwd] = match(cmx);
                                    bod_prev = m_bwd(bods(b));
                                    idx_prev = find(seq_bod_prev(:,2)==bod_prev);
                                end
                                if isempty(idx_prev) 
                                    ori_prev = ori;
                                else                                    
                                    seq_prev = seq_bod_prev(idx_prev,1);                                
                                    fr_prev = i-1 - trks.sequences{seq_prev}.time_start+1;
                                    ori_prev = orientations{seq_prev}(fr_prev);   
                                end
                            end
                            vector = [cos(ori_prev) -sin(ori_prev)];                           
                        end
                        angle = acos(dot(rot_vec,vector)) /pi*180;                
                        if angle > 90
                            ori = ori + (-1)^(ori>0)*pi;
                            orientations{seq_id}(fr_idx) = ori;
                        end   
                    end
                    rot_vec = [cos(ori) -sin(ori)];
                    % check how wing fit with pose
                    ws = bw_adjacency{b};
                    ws_sz = zeros(size(ws));
                    ws_dist = zeros(size(ws));
                    ws_ang = zeros(size(ws));
                    ws_shared = zeros(size(ws));
                    for wn = 1:numel(ws)
                        % wing size
                        ws_sz(wn) = numel(wing_cc.PixelIdxList{ws(wn)});
                        % wing distance
                        [I,J] = ind2sub(fg_size,wing_cc.PixelIdxList{ws(wn)});                    
                        dists = (I-pos(2)).^2 + (J-pos(1)).^2;
                        ws_dist(wn) = sqrt(max(dists));
                        % wing angle
                        wingCenter = [mean(J) mean(I)];
                        %vectorw = wingCenter - pos; vectorw = vectorw/norm(vectorw);
                        vectorw = pos-wingCenter; vectorw = vectorw/norm(vectorw);
                        ws_ang(wn) = acos(dot(rot_vec,vectorw));
                        % shared?
                        ws_shared(wn) = numel(wb_adjacency{ws(wn)}) > 1;
                    end
                    [ws_sz, inds] = sort(ws_sz,'descend');
                    ws_dist = ws_dist(inds); ws_ang = ws_ang(inds); 
                    % only consider wings that are large enough and not too
                    % far from the bodies center
                    valid = find(ws_sz >= params.wing_area_min & ...
                                ws_dist < params.max_major_axis*1.2);                            
                    ws_ang = ws_ang(valid); 
                    ws_sz = ws_sz(valid);
                    ws_dist = ws_dist(valid); 
                    ws_shared = ws_shared(valid);
                    inds = inds(valid);
                    % check whether wings can be trusted
                    if numel(inds)>0 && ...                                % >0 valid wings
                       sum(ws_shared) == 0 && ...                          % wings not shared with other body
                       max(ws_dist) > major_ax*1.05 && ...                 % longest wing longer than 1/2 fly
                       max(ws_sz) > params.wing_area_min*2 && ...          % wing area large enough to differentiate                
                       max(ws_ang)-min(ws_ang) < pi/2 && ...               % wings not on opposite sites of minor axis                              
                       area > params.mean_area*.8 && ...                   % body in resting position
                       major_ax/minor_ax > params.mean_axis_ratio*.8       % body in resting position
                        trust_wings = true;
                    else
                        trust_wings = false;
                    end
                    if trust_wings
                        % use wings and disambiguate orientation
                        if mean(ws_ang) > params.max_body_wing_ang
                            ori = ori + (-1)^(ori>0)*pi; 
                            rot_vec = [cos(ori) -sin(ori)];
                            if trks_matched                                
                                orientations{seq_id}(fr_idx) = ori;
                            end
                        end
                    elseif n_frames > 1 
                        % keep only wings that agree with orientation
                        valid = ws_ang < params.max_body_wing_ang;
                        inds = inds(valid);
                    end
                    if numel(inds)>2, inds = inds(1:2); end
                    ws = ws(inds);                                       
                    wing_pix = vertcat(wing_cc.PixelIdxList{ws});
                    
                    % if only one wing, split it along the fly's major axis
                    if numel(ws) == 1
                        wing_img = zeros(fg_size);
                        wing_img(wing_pix) = 1;
                        center = detect.body_props(bods(b)).Centroid;
                        center(1) = center(1) - bbox(3)+1;
                        center(2) = center(2) - bbox(1)+1;
                        rad = calib.PPM*10;
                        x1 = center(1)-rot_vec(1)*rad; y1 = center(2)-rot_vec(2)*rad;
                        x2 = center(1)+rot_vec(1)*rad; y2 = center(2)+rot_vec(2)*rad;
                        [y,x] = ind2sub(fg_size,wing_pix);
                        dx = x2-x1; dy = y2-y1;
                        dists = abs(dx*(y1-y) - dy*(x1-x)) / sqrt(dx^2+dy^2);
                        wing_img(wing_pix(dists<.75)) = 0;       
                        new_wing_cc = bwconncomp(wing_img);                        
                        sz = zeros(1,new_wing_cc.NumObjects);
                        for nw=1:new_wing_cc.NumObjects
                            sz(nw) = numel(new_wing_cc.PixelIdxList{nw});
                        end
                        [~,inds] = sort(sz,'descend');
                        if numel(inds)>2, inds = inds(1:2); end
                        ws = wing_cc.NumObjects+(1:numel(inds));
                        wing_cc.PixelIdxList(ws) = new_wing_cc.PixelIdxList(inds);
                        wing_cc.NumObjects = wing_cc.NumObjects + numel(inds);                        
                        wing_pix = wing_pix(dists>.75);
                    end
                    [I,J] = ind2sub(fg_size,wing_pix);
                    wing_pxls = sub2ind_faster(imsize,I+bbox(1)-1,J+bbox(3)-1);
                    b_wing_pixels{bods(b)} = wing_pxls;

                    % find extremal points of wings
                    pts = cell([numel(ws) 1]);
                    for wn = 1:numel(ws)
                        w = ws(wn);
                        pix = wing_cc.PixelIdxList{w};
                        [I,J] = ind2sub(fg_size,pix);
                        dists = (I-pos(2)).^2 + (J-pos(1)).^2;
                        [~, ind] = max(dists);
                        [x, y] = ind2sub(fg_size, pix(ind));
                        x = x+bbox(1)-1;
                        y = y+bbox(3)-1;
                        pts{wn} = [y x];
                    end
                    b_wing_pts{bods(b)} = pts;
                    
                    % store disambiguated orientation
                    detect.body_props(bods(b)).Orientation = ori/pi*180;                    
                end           
            end    
        end
        
        % store foreground distances
        detect.body_min_dist = min_fg_dist;
        % store segmentation wing information
        detect.seg.body_wing_pixels = b_wing_pixels;
        detect.seg.body_wing_coords = b_wing_pts;
        % store segmentation leg information 
        detect.seg.body_leg_pixels = b_leg_pixels;
        detect.seg.body_leg_coords = b_leg_pts;
        % store detections
        trks.frame_data{i} = detect;    
    end
    
    % close waitbar
    if show_progress
       if display_available
           multiWaitbar(waitstr,'Close');
           drawnow
       else
           for d=1:numel(num2str(percent))+1
              fprintf(1,'\b');
           end
           percent = 100;
           fprintf(1,'%d%% \n',percent);               
       end   
    end            
    if ~trks_matched, return; end
    
    % map data to feature array for each sequence
    trks = extract_raw_features(trks);
end

function trks = extract_raw_features(trks)  
    trks.names = {'pos x','pos y','ori', ...                               % pose
     'major axis len','minor axis len', ...                                % pose cont.
     'body area','fg area','img contrast', ...                             % surroundings
     'min fg dist', ...                                                    % fg dist to nearest fly
     'wing l x','wing l y','wing r x','wing r y', ...                      % wing positions
     'wing l ang' 'wing l len' 'wing r ang' 'wing r len', ...              % wingangles and lengths
     'leg 1 x','leg 1 y','leg 2 x','leg 2 y', 'leg 3 x','leg 3 y',...      % leg positions
     'leg 4 x','leg 4 y', 'leg 5 x','leg 5 y','leg 6 x','leg 6 y',...      % leg positions cont.
     'leg 1 ang','leg 2 ang','leg 3 ang', ...                              % leg angles
     'leg 4 ang','leg 5 ang','leg 6 ang'};                                 % leg angles cont.
  
    n_feat = numel(trks.names);
    % initialize coordinate arrays
    for s = 1:numel(trks.sequences)
       seq_size = numel(trks.sequences{s}.obj_list);
       trks.sequences{s}.track = nan([seq_size n_feat]);
    end

    for f = 1:numel(trks.frame_ids);
       % get list of active sequences
       seq_list = trks.frame_seq_list{f};
       for s = 1:numel(seq_list)
          % get object in frame
          seq_id = seq_list(s);
          t_ind = f - trks.sequences{seq_id}.time_start + 1;
          obj_id = trks.sequences{seq_id}.obj_list(t_ind);
          % store coordinates in sequence
          % - position
          pos = trks.frame_data{f}.body_props(obj_id).Centroid;
          trks.sequences{seq_id}.track(t_ind,1:2) = pos;
          % - orientation
          ori = trks.frame_data{f}.body_props(obj_id).Orientation*pi/180;
          trks.sequences{seq_id}.track(t_ind,3) = ori;
          % - body axes
          trks.sequences{seq_id}.track(t_ind,4) = ...
            trks.frame_data{f}.body_props(obj_id).MajorAxisLength;
          trks.sequences{seq_id}.track(t_ind,5) = ...
            trks.frame_data{f}.body_props(obj_id).MinorAxisLength;
          % - body size
          trks.sequences{seq_id}.track(t_ind,6) = ...
            trks.frame_data{f}.body_props(obj_id).Area;
          % - fg size
          fg_id = trks.frame_data{f}.body_fg(obj_id);
          trks.sequences{seq_id}.track(t_ind,7) = ...
            trks.frame_data{f}.fg_props(fg_id).Area;
          % - contrast
          trks.sequences{seq_id}.track(t_ind,8) = ...
            trks.frame_data{f}.body_contrast(obj_id);        
          % - distance to closest foreground (for touch detection)
          trks.sequences{seq_id}.track(t_ind,9) = ...
            trks.frame_data{f}.body_min_dist(obj_id);        
          % - wings (ordered by left and right)
          wings = trks.frame_data{f}.seg.body_wing_coords{obj_id};  
          [angles,lengths] = get_relative_pos(pos,ori,wings);
          if numel(wings)==1 && angles(1) > 0
              % set this as the right wing
              trks.sequences{seq_id}.track(t_ind,12:13) = wings{1};
              trks.sequences{seq_id}.track(t_ind,16) = angles(1);
              trks.sequences{seq_id}.track(t_ind,17) = lengths(1);
          else
              % set most negative angle wing to be the left one
              [~,sortids] = sort(angles,'ascend');
              for i=1:numel(wings)
                  w = sortids(i);
                  trks.sequences{seq_id}.track(t_ind,9+(i-1)*2+(1:2)) = wings{w};
                  trks.sequences{seq_id}.track(t_ind,13+(i-1)*2+1) = angles(w);
                  trks.sequences{seq_id}.track(t_ind,13+(i-1)*2+2) = lengths(w);                  
              end
          end
          % - legs (ordered from top left leg to top right)
          legs = trks.frame_data{f}.seg.body_leg_coords{obj_id};
          angles = get_relative_pos(pos,ori,legs);
          [~,sortids] = sort(angles,'ascend');
          for i=1:numel(legs)
              l = sortids(i);
              trks.sequences{seq_id}.track(t_ind,17+(i-1)*2+(1:2)) = legs{l};
              trks.sequences{seq_id}.track(t_ind,29+i) = angles(l);
          end
       end
    end  
end

function [angles,lengths] = get_relative_pos(pos,ori,points)
    % pos: (x,y) center position of reference object
    % ori: orientation (rad) of reference object
    % points; cell array of (x,y) positions of points
    angles = zeros(1,numel(points));
    lengths = zeros(1,numel(points));
    vec_rot = [cos(ori) -sin(ori)];
    for i=1:numel(points)
        vector = [pos(1)-points{i}(1) pos(2)-points{i}(2)]';
        len = norm(vector);
        vector = vector / len;
        perpDot = vector(1) * vec_rot(2) - vector(2) * vec_rot(1);
        angles(i) = atan2(perpDot,dot(vector,vec_rot));
        lengths(i) = len;
    end
end
