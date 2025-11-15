function output_calibration = core_tracker_fit_arena(output_calibration_file_name, ...
                                                     working_background_file_name, ...
                                                     input_calibration, ...
                                                     options)
    
    % If the user wants to use the input calibration as-is, skip arena-fitting
    if ~options.force_arena_calib && ~input_calibration.auto_detect ,
        % If we're not forced, we use the input calibration
        output_calibration = input_calibration ;
        return
    end
    
    % Delete any old output file, if it exists
    ensure_file_does_not_exist(output_calibration_file_name) ;
    
    bg = load_anonymous(working_background_file_name) ;
    working_calibration = input_calibration ;
    if isempty(working_calibration.r) ,
        shape = 'rectangular';
    else
        shape = 'circular';
    end
    % find new chambers and update structure
    n_chambers_nominal = working_calibration.n_chambers ;
    [centers, r, w, h] = calib_chamber_detect(bg, n_chambers_nominal, ...
                                              shape, working_calibration.r, working_calibration.w, working_calibration.h, ...
                                              options);
    if numel(centers)==1 && ~centers
        error('Calibration failed') ;
    end
    n_chambers_found = size(centers,1) ;
    if n_chambers_found ~= n_chambers_nominal
      error('Calibration failed: Found %d chamber(s) when doing calibration, but there should be %d chamber(s).', n_chambers_found, n_chambers_nominal) ;
    end

    working_calibration.centroids = centers;
    working_calibration.r = r;
    working_calibration.w = w;
    working_calibration.h = h;
    
    if isfield(working_calibration,'arena_r_mm'),
        working_calibration.PPM = working_calibration.r / working_calibration.arena_r_mm;
    elseif isfield(working_calibration,'arena_w_mm'),
        working_calibration.PPM = working_calibration.w / working_calibration.arena_w_mm;
    elseif isfield(working_calibration,'arena_h_mm'),
        working_calibration.PPM = working_calibration.h / working_calibration.arena_h_mm;
    end
    
    masks = cell(1,size(centers,1));
    rois = cell(1,size(centers,1));
    full_mask = zeros(size(working_calibration.full_mask));
    for i=1:size(centers,1)
        mask = zeros(size(working_calibration.mask));
        if working_calibration.roi_type == 1 % rectangular
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
    working_calibration.masks = masks;
    working_calibration.mask = masks{1};
    working_calibration.full_mask = full_mask;
    output_calibration = working_calibration ;
    calib = output_calibration ;
    save(output_calibration_file_name, 'calib') ;
end
