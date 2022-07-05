
% Detect flies in video frames.
%
% To detect flies, use:
%
%    detections = feat_compute(vinfo, bg, calib, [frame_range], [imgs], [calibrating])
%
% where [] denotes an optional parameter and:
%
%    vinfo       - video structure, obtained from video_open
%    bg          - bg structure, obtained from calib_bg_estimate
%    calib       - calibration structure, obtained from calibrator or tracker_job_calibrate
%    frame_range - range of frames to process (see description in calib_bg_estimate)
%    imgs        - images to process, if provided then vinfo is ignored
%    calibrating - indicator on whether called from calibrator (default 0)
%
% returns:
%
%    detections. - detection structure
%       frame_ids  - frame id (0-indexed) for frames processed
%       frame_data - cell array containing each frame's detection data:
%           .fg_cc         - connected components of foreground mask
%           .fg_props      - properties of fg_cc
%           .body_cc       - connected components of body mask
%           .body_props    - properties of body_cc
%           .fg_body       - indicates which bodies are contained in a fg
%           .body_fg       - indicates which fg a body belongs to
%           .body_contrast - mean gradient in image cropped around body          
%       roi        - region of interest defined by mask, all coordinates in
%                    frame_data are in terms of the roi
%       If calibration has multiple chambers, detections is a cell array of
%       detections for each chamber.
%
function detections = track_detect(vinfo, bg, calib, frame_range, imgs, calibrating, options)
    % Process args
    % set frame range
    if nargin < 4 || isempty(frame_range) ,
       frame_range.start = 0;
       frame_range.step  = 1;
       frame_range.limit = vinfo.n_frames;
    end    
    % if imgs provded, update frame range
    if nargin < 5 || isempty(imgs) ,
        use_imgs = 0;
        show_progress = 1;
    else
        use_imgs = 1;
        frame_range.start = 0;
        frame_range.step = 1;
        frame_range.limit = numel(imgs);
        show_progress = 0;
    end
    if nargin < 6 || isempty(calibrating) ,
        calibrating = 0 ;
    end
    if ~exist('options', 'var') || isempty(options) ,
        options = tracker_default_options() ;
    end
    
    % copy info from calibration    
    params      = calib.params; 
    mask        = calib.mask;
    [I,J]       = find(calib.mask);
    roi         = [min(I),min(J),max(I),max(J)];
    
    % initialize detections
    detections.frame_ids = ...
       (frame_range.start):(frame_range.step):(frame_range.limit-1);
    detections.frame_data = cell([numel(detections.frame_ids) 1]);
    % store region of interest
    detections.roi = roi;
    n_frames = numel(detections.frame_ids);
    % check for nonempty input
    if (n_frames == 0), return; end

    % check whether image needs to be inverted        
    params.invert = bg.invert;

    % only consider parts of the image that are within the mask
    bg = bg.bg_mean;
    bg = bg.*mask;
    bg = bg(roi(1):roi(3),roi(2):roi(4));       
    
    if show_progress
        % initialize waitbar
        do_use_display = options.isdisplay && feature('ShowFigureWindows') ;
        waitstr = 'Detecting flies';
        waitstep = max(1,floor(n_frames/100));
        if frame_range.limit < vinfo.n_frames || frame_range.start > 0
            waitstr = [waitstr ': frames ' num2str(frame_range.start) ...
             '-' num2str(frame_range.limit) ' / ' num2str(vinfo.n_frames)];         
        end
        if calibrating
            waitstr = 'Finalizing calibration';
        end        
        if do_use_display
            multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
            waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
        else
            percent = 0;
            fprintf(1,[waitstr ': %d%%'], percent);             
        end 
    end
    
    % Loop through all frames and detect flies
    for id_num = 1:n_frames            
        id = detections.frame_ids(id_num);
        if use_imgs
            img = imgs{id_num};
            if params.invert
                img = 1-img;
            end
            img = img .* mask;
            img = img(roi(1):roi(3),roi(2):roi(4));
        else   
            try
                img = video_read_frame(vinfo,id);
                if params.invert
                    img = 1-img;
                end
                % convert image to grayscale 
                if (size(img,3)>1), img = rgb2gray(img); end
                img = img .* mask;
                img = img(roi(1):roi(3),roi(2):roi(4));
            catch
                disp(['Warning: unable to read frame ' num2str(id+1)])
                img = bg;
            end
        end    
        if show_progress
            if do_use_display && mod(id_num,waitstep) == 0
                abort = multiWaitbar(waitstr,id_num/n_frames);
                if abort, detections = 0; return; end
            elseif mod(id_num,waitstep) == 0
                for d=1:numel(num2str(percent))+1
                   fprintf(1,'\b');
                end
                percent = round(id_num/n_frames*100);
                fprintf(1,'%d%%',percent);
            end  
        end
        
        % EXTRACT FOREGROUND ----------------------------------------------
        im_fg = max((bg - img),[],3);
        im_fg = im_fg./max(.1,bg); % to account for the difference when on food
        im_fg = im_fg/max(max(im_fg(:)),max(img(:))); % normalize
        im_fg_strong = (im_fg > params.fg_th_strong);
        im_fg_weak   = (im_fg > params.fg_th_weak);     
        fg_mask = imreconstruct(im_fg_strong, im_fg_weak);         
        
        fg_inds = find(fg_mask);
        % check that foreground is nonempty
        if (numel(fg_inds) < params.fg_min_size)
            % no detections in current frame
            empty_cc = bwconncomp(zeros(size(fg_mask)));
            empty_props = regionprops(empty_cc, params.r_props);
            detect.fg_cc      = empty_cc;   	% foreground components
            detect.fg_props   = empty_props;	% foreground properties 
            detect.body_cc    = empty_cc;       % body components
            detect.body_props = empty_props; 	% body properties
            detect.fg_body    = cell([0 1]);	% bodies in each fg comp
            detect.body_fg    = zeros([0 1]); 	% fg comp for each body            
            detect.body_contrast = 0;
            % store detections
            detections.frame_data{id_num} = detect;
            continue
        end

        % EXTRACT BODY ----------------------------------------------------
        % check if modeling foreground with different body components
        if (params.fly_comp > 1)
            % compute body mask using image pixels under fg mask
            body_mask = im_fg > params.body_th_weak & fg_mask;
            if calib.PPM >= 3
                body_mask = imdilate(imerode(body_mask,params.strels{2}),params.strels{2});
            end
            body_mask = fg_mask & imfill(body_mask,'holes');          
        else
            body_mask = fg_mask;
        end
        % partition body components
        body_cc    = bwconncomp(body_mask);
        body_props = regionprops(body_cc, params.r_props);                 
        % partition foreground components
        fg_cc      = bwconncomp(fg_mask);
        fg_label   = labelmatrix(fg_cc);
        fg_props   = regionprops(fg_cc, params.r_props);   
        
        % assemble detections in frame
        n_fg_comp   = numel(fg_cc.PixelIdxList);
        n_body_comp = numel(body_cc.PixelIdxList);
        detect.fg_cc      = fg_cc;                  % foreground components
        detect.fg_props   = fg_props;               % foreground properties 
        detect.body_cc    = body_cc;                % body components
        detect.body_props = body_props;             % body properties
        detect.fg_body    = cell([n_fg_comp 1]);    % bodies in each fg comp
        detect.body_fg    = zeros([n_body_comp 1]); % fg comp for each body
        for b = 1:n_body_comp
            p_idx = detect.body_cc.PixelIdxList{b}(1);
            f = fg_label(p_idx);
            detect.fg_body{f} = [detect.fg_body{f} b];
            detect.body_fg(b) = f;
        end
        
        % merge non-atomic bodies with bodies sharing their foreground
        % (they may get split again during matching if necessary)
        atomic = is_atomic_detection(detect,params);        
        while any(atomic==0)
            do_merge = find(~atomic);
            obj_id = do_merge(1);
            detect = merge_bodies(detect,params,obj_id);
            atomic = is_atomic_detection(detect,params);
        end
        
        % fill empty foregrounds and delete redundant ones
        detect = fill_empty_foregrounds(detect, params);
        
        % add information about body contrast 
        contrast = nan(1,detect.body_cc.NumObjects);
        full_gradient = imgradient(im_fg);
        buff = params.fg_mask_buff;
        for b=1:detect.body_cc.NumObjects
            pos = round(detect.body_props(b).Centroid);
            x_sub = max(1,pos(2)-buff):min(size(img,1),pos(2)+buff);
            y_sub = max(1,pos(1)-buff):min(size(img,2),pos(1)+buff);
            gradient = full_gradient(x_sub,y_sub);
            contrast(b) = mean(gradient(:));                     
        end         
        detect.body_contrast = contrast;

        % store detections
        detections.frame_data{id_num} = detect;          
    end  
    
    % if multiple chambers, split detections amongst valid masks    
    if ~calibrating
        masks = calib.masks(calib.valid_chambers==1);
        if numel(masks) > 1
            detections = mask_detections(detections,masks);
        end
    end
    
    % close waitbar
    if show_progress
       if do_use_display
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
end

function detect_new = merge_bodies(detect,params,obj_id)
    % initialize new detection to be the same
    detect_new = detect;
    % find closest body blob and merge with them
    fg_id = detect.body_fg(obj_id);
    bods = detect.fg_body{fg_id};
    other_bods = setdiff(bods,obj_id); other_bods = other_bods(:)';
    body_cc = detect.body_cc;     
    body_props = detect.body_props;
    if numel(bods) > 1            
        img = zeros(detect.body_cc.ImageSize);
        img(detect.body_cc.PixelIdxList{obj_id}) = 1;
        dist_map = bwdist(img);
        min_dists = zeros(1,numel(other_bods));
        for b = 1:numel(other_bods)
            bod = other_bods(b);
            dists = dist_map(detect.body_cc.PixelIdxList{bod});
            min_dists(b) = min(dists);            
        end
        [~,min_idx] = min(min_dists);
        bod = other_bods(min_idx);
        body_cc.PixelIdxList{bod} = ...
                union(body_cc.PixelIdxList{bod}, ...
                  body_cc.PixelIdxList{obj_id},'rows');
        body_props = regionprops(body_cc, params.r_props);  
    end
    % remove blob from list of bodies
    inds = [1:obj_id-1 obj_id+1:body_cc.NumObjects];        
    body_cc.NumObjects = detect.body_cc.NumObjects-1;
    body_cc.PixelIdxList = body_cc.PixelIdxList(inds);
    body_props = body_props(inds);
    detect_new.body_cc = body_cc;
    detect_new.body_props = body_props;
    detect_new.body_fg = detect.body_fg(inds);
    for fg=1:detect.fg_cc.NumObjects
        detect_new.fg_body{fg} = find(detect_new.body_fg==fg);
    end
end

function detect = fill_empty_foregrounds(detect, params)
    empty_fgs = zeros(1,detect.fg_cc.NumObjects);
    for f=1:numel(empty_fgs)
        empty_fgs(f) = numel(detect.fg_body{f}) == 0;
    end
    empty_fgs = find(empty_fgs);
    valid = true(1,detect.fg_cc.NumObjects);
    for f=empty_fgs
        area = detect.fg_props(f).Area;
        ratio = detect.fg_props(f).MajorAxisLength/detect.fg_props(f).MinorAxisLength;
        if area > params.mean_area && area < params.fg_max_size && ratio < 3
            pixel = round(detect.fg_props(f).Centroid);
            pixelIdx = sub2ind_faster(detect.fg_cc.ImageSize,pixel(2),pixel(1));
            detect.body_cc.NumObjects = detect.body_cc.NumObjects+1;
            detect.body_cc.PixelIdxList{end+1} = pixelIdx;
            detect.body_fg(end+1) = f;
            detect.fg_body{f} = detect.body_cc.NumObjects;
            detect.body_props(end+1).Area = 1;
            detect.body_props(end).MajorAxisLength = 1;
            detect.body_props(end).MinorAxisLength = 1;
            detect.body_props(end).Centroid = pixel;
            detect.body_props(end).Orientation = 0;
        else
            valid(f) = 0;
        end
    end
    % delete invalid foregrounds
    if any(~valid)
        detect.fg_cc.NumObjects = sum(valid);
        detect.fg_cc.PixelIdxList = detect.fg_cc.PixelIdxList(valid);
        detect.fg_props = detect.fg_props(valid);
        detect.fg_body = detect.fg_body(valid);
        for fg=1:detect.fg_cc.NumObjects
            bods = detect.fg_body{fg};
            detect.body_fg(bods) = fg;
        end
    end
end

function masked_detections = mask_detections(detections,masks)
    masked_detections = cell(size(masks));
    for m=1:numel(masks)
        mask = masks{m};
        dets = detections;
        transl = dets.roi(1:2);
        for i=1:numel(dets.frame_ids)
            det = dets.frame_data{i};
            % map fgs to mask space
            tmp = [det.fg_props.Centroid];
            x = tmp(1:2:end)+transl(2)-1;
            y = tmp(2:2:end)+transl(1)-1;
            fg_inds = sub2ind_faster(size(mask),round(y),round(x));
            % check which fgs are within the mask
            fg_valid = find(mask(fg_inds)==1);
            % keep only bodies corresponding to valid fgs
            body_valid = find(ismember(det.body_fg,fg_valid));
            % map foregrounds to new foregrounds
            fg_map = zeros(1,det.fg_cc.NumObjects);
            fg_map(fg_valid) = 1:numel(fg_valid);
            % update detection
            det.fg_cc.NumObjects = numel(fg_valid);
            det.fg_cc.PixelIdxList = det.fg_cc.PixelIdxList(fg_valid);
            det.fg_props = det.fg_props(fg_valid);
            det.body_cc.NumObjects = numel(body_valid);
            det.body_cc.PixelIdxList = det.body_cc.PixelIdxList(body_valid);
            det.body_props = det.body_props(body_valid);
            det.body_fg = fg_map(det.body_fg(body_valid));
            det.fg_body = cell(size(fg_valid));
            for f=1:numel(fg_valid)
                det.fg_body{f} = find(det.body_fg==f);
            end
            det.body_contrast = det.body_contrast(body_valid);  
            dets.frame_data{i} = det;
        end
        masked_detections{m} = dets;
    end
end
