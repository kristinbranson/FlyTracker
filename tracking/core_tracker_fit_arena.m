function did_succeed = core_tracker_fit_arena(output_calibration_file_name, ...
                                              working_background_file_name, input_calibration_file_name, ...
                                              options)
    
    did_succeed = 0;
    
    bg = load_anonymous(working_background_file_name) ;
    input_calibration = load_anonymous(input_calibration_file_name) ;
    calibration = input_calibration ;
    if isempty(calibration.r) ,
        shape = 'rectangular';
    else
        shape = 'circular';
    end
    % find new chambers and update structure
    [centers, r, w, h] = calib_chamber_detect(bg, calibration.n_chambers, ...
                                              shape, calibration.r, calibration.w, calibration.h, ...
                                              options);
    if numel(centers)==1 && ~centers
        return;
    end
    calibration.centroids = centers;
    calibration.r = r;
    calibration.w = w;
    calibration.h = h;
    
    if isfield(calibration,'arena_r_mm'),
        calibration.PPM = calibration.r / calibration.arena_r_mm;
    elseif isfield(calibration,'arena_w_mm'),
        calibration.PPM = calibration.w / calibration.arena_w_mm;
    elseif isfield(calibration,'arena_h_mm'),
        calibration.PPM = calibration.h / calibration.arena_h_mm;
    end
    
    masks = cell(1,size(centers,1));
    rois = cell(1,size(centers,1));
    full_mask = zeros(size(calibration.full_mask));
    for i=1:size(centers,1)
        mask = zeros(size(calibration.mask));
        if calibration.roi_type == 1 % rectangular
            y1 = max(1,round(centers(i,1)-h/2));
            y2 = min(size(mask,1),round(centers(i,1)+h/2));
            x1 = max(1,round(centers(i,2)-w/2));
            x2 = min(size(mask,2),round(centers(i,2)+w/2));
            mask(y1:y2,x1:x2) = 1;
            rois{i} = round([y1 x1 y2-y1+1 x2-x1+1]);
        else                   % circulars
            [x,y] = ind2sub(size(mask),1:numel(mask));
            x = x - centers(i,1);
            y = y - centers(i,2);
            valid = x.^2 + y.^2 - r^2 < r;
            mask(valid) = 1;
            rois{i} = round([centers(i,1)-r centers(i,2)-r r*2 r*2]);
        end
        masks{i} = mask;
        full_mask = full_mask | mask;
    end
    calibration.masks = masks;
    calibration.mask = masks{1};
    calibration.full_mask = full_mask;
    calib = calibration ;
    save(output_calibration_file_name, 'calib') ;
    did_succeed = 1;
end
