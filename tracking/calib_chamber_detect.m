
% Detect chambers from bg image.
%
% To detect chambers, use:
%
%    [centers, r, w, h] = calib_chamber_detect(bg, n_chambers, [shape], [r], [w], [h])
%
% where [] denotes an optional parameter and:
%
%    bg          - bg structure, computed with calib_bg_estimate
%    n_chambers  - number of chambers to be detected
%    shape       - 'circular' or 'rectangular'. If not specified, shape is 
%                   determined based on histogram of edges in bg image
%    r           - radius of chambers (irrelevant if shape is 'rectangular'
%    w, h        - width and height of chambers (irrelevant if shape is 'circular')
%
% returns:
%
%    centers     - n_chambersx2 matrix containing chamber centers
%
function [centers, r, w, h] = calib_chamber_detect(bg, n_chambers, shape, r, w, h, options)
    % Deal with args
    if ~exist('shape', 'var')  ,
        shape = [] ;
    end
    if ~exist('r', 'var')  ,
        r = [] ;
    end
    if ~exist('w', 'var')  ,
        w = [] ;
    end
    if ~exist('h', 'var')  ,
        h = [] ;
    end
    if ~exist('options', 'var') || isempty(options) ,
        options = tracker_default_options() ;
    end
    % initialize waitbar
    do_use_display = options.isdisplay && feature('ShowFigureWindows') ;
    waitstr = 'Detecting chambers';
    if do_use_display
        multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
        waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
    else
        percent = 0;
        fprintf(1,[waitstr ': %d%%'], percent);        
    end

    % Extract blob mask from bg structure    
    img_sz = size(bg.bg_mean);
    blobs = zeros(img_sz);
    blobs(bg.blob_sum>0) = 1;
    % check whether blob image is invalid
    if sum(blobs(:)) > numel(blobs)*.5
        blobs = zeros(img_sz);
    end
    
    % Extract edge mask from bg structure
    [mag,dir] = imgradient(bg.bg_mean);
    % set threshold to be one std from mean
    thresh = mean(mag(:))+std(mag(:));
    % consider only gradients with magnitute above threshold
    mag_th = mag>thresh;
    % discard components that are too small
    cc = bwconncomp(mag_th);
    sizes = zeros(1,cc.NumObjects);
    for i=1:cc.NumObjects
        sizes(i) = numel(cc.PixelIdxList{i});
    end
    total_pix = img_sz(1)*img_sz(2);
    valid = find(sizes > total_pix*.0005);
    % store valid components as edges
    edges = zeros(img_sz);
    for i=1:numel(valid)
        edges(cc.PixelIdxList{valid(i)}) = 1;
    end
    
    % Determine shape of arena
    if ~isempty(shape)
        is_arena_circular = strcmp(shape,'circular');
    else
        % histogram gradients of magnitute above the threshold
        n = hist(mod(dir(edges>0),90),4);  %#ok<HIST> 
        n = sort(n);
        % check whether chambers are circular or rectangular
        is_arena_circular = n(2) >.2*n(3);
    end

    % Downsize larger videos for faster processing
    scale = 1;
    if max(img_sz)/n_chambers > 2^8
        scale = floor(max(img_sz)/n_chambers / 2^8);
        blobs = blobs(scale:scale:end,scale:scale:end);
        edges = edges(scale:scale:end,scale:scale:end);
    end
    
    % Determine candidate radius / (width,height) range
    min_fractional_arena_size = options.min_fractional_arena_size ;  % e.g. 0.9
    max_fractional_arena_size = options.max_fractional_arena_size ;  % e.g. 1.1
    n_rows = floor(sqrt(n_chambers));
    n_cols = ceil(n_chambers/n_rows);
    dims = size(edges); dims = sort(dims);
    split_rows = dims(1)/n_rows;
    split_cols = dims(2)/n_cols;
    if is_arena_circular
        if ~isempty(r)
            baseline_radius = round(r/scale);
            if min_fractional_arena_size == max_fractional_arena_size ,
                radius_range = round(baseline_radius*max_fractional_arena_size) ;
            else
                radius_min = round(baseline_radius*min_fractional_arena_size) ;
                radius_max = round(baseline_radius*max_fractional_arena_size) ;
                radius_range = radius_min:radius_max;
            end
        else
            radius_max = round(min(split_rows,split_cols)*.6);
            radius_min = round(radius_max*.6);
            radius_range = radius_min:radius_max;
            if numel(radius_range) > 50 ,
                step = floor((radius_max-radius_min)/50);
                radius_range = radius_min:step:radius_max;
            end
        end
        % set default output values for width and height
        w = []; h = [];
    else
        if ~isempty(w) && ~isempty(h)
            baseline_width = round(w/scale);
            baseline_height = round(h/scale);            
            if min_fractional_arena_size == max_fractional_arena_size ,
                width_range = round(baseline_width*max_fractional_arena_size) ;
                height_range = round(baseline_height*max_fractional_arena_size) ;
            else
                width_min = round(baseline_width*min_fractional_arena_size);
                width_max = round(baseline_width*max_fractional_arena_size);
                width_range = width_min:width_max;
                height_min = round(baseline_height*min_fractional_arena_size);
                height_max = round(baseline_height*max_fractional_arena_size);
                height_range = height_min:height_max;
            end
        else
            width_max = round(split_cols);
            width_min = round(width_max*.7);
            width_range = width_min:width_max;
            height_max = round(split_rows);
            height_min = round(height_max*.7);
            height_range = height_min:height_max;
            [width_range,height_range] = consolid_range(edges,width_range,height_range);
        end
        % set default output value for radius
        r = [];
    end

    % Search for optimal chamber dimensions
    if is_arena_circular
        max_responses = zeros(1,numel(radius_range));
        count = 0;
        for r=radius_range
            % generate mask for circle of proposed radius and convolve the image
            masks = make_circle_masks(r);
            edge_mask = masks{1};
            blob_mask = masks{2};
            edge_response = conv2fft(edges,edge_mask,'same');
            blob_response = conv2fft(blobs,blob_mask,'same');
            response = edge_response + blob_response;
            count = count + 1;
            max_responses(count) = max(response(:));
            % update waitbar
            if do_use_display 
                abort = multiWaitbar(waitstr,count/numel(radius_range));
                if abort, centers = 0; return; end
            else
                for d=1:numel(num2str(percent))+1
                   fprintf(1,'\b');
                end
                percent = round(count/numel(radius_range)*100);
                fprintf(1,'%d%%',percent);                
            end
        end
        % pick the radius with highest response
        [~,best_r] = max(max_responses);
        r = radius_range(best_r);
        % compute the response of the best radius again
        masks = make_circle_masks(r);
        edge_mask = masks{1};
        blob_mask = masks{2};
    else
        max_responses = zeros(numel(width_range),numel(height_range));
        count = 0;
        for i=1:numel(width_range)
            w = width_range(i);
            for j=1:numel(height_range)
                h = height_range(j);
                % generate mask for rectangle of proposed width and height
                %  and convolve the image
                masks = make_rect_masks(w,h);
                edge_mask = masks{1};
                blob_mask = masks{2};
                edge_response = conv2fft(edges,edge_mask,'same');
                blob_response = conv2fft(blobs,blob_mask,'same');
                response = edge_response + blob_response;
                max_responses(i,j) = max(response(:));
                count = count+1;
                % update waitbar
                if do_use_display 
                    abort = multiWaitbar(waitstr,count/(numel(width_range)*numel(height_range)));
                    if abort, centers = 0; return; end
                else
                    for d=1:numel(num2str(percent))+1
                       fprintf(1,'\b');
                    end
                    percent = round(count/(numel(width_range)*numel(height_range))*100);
                    fprintf(1,'%d%%',percent);                      
                end            
            end
        end
        max_resp = max(max_responses(:));
        [i,j] = find(max_responses==max_resp);
        w = width_range(i(1));
        h = height_range(j(1));
        masks = make_rect_masks(w,h);
        edge_mask = masks{1};
        blob_mask = masks{2};
    end

    % Find chamber candidates
    % convolve images with optimal chamber dimension mask
    edge_response = conv2fft(edges,edge_mask,'same');
    blob_response = conv2fft(blobs,blob_mask,'same');
    response = edge_response + blob_response;
    % consider only top 3% responses as candidate chamber centers
    thresh = prctile(response(:),97);
    resp_th = response>thresh;
    % compute the max response for each connected component
    cc = bwconncomp(resp_th);
    max_responses = zeros(1,cc.NumObjects);  
    for i=1:cc.NumObjects
        max_responses(i) = max(response(cc.PixelIdxList{i})); 
    end
    [~,sort_ids] = sort(max_responses,'descend');

    % Set max distance between two chambers
    min_dist = fif(is_arena_circular, 2*r, min(w,h)) ;

    % Add chambers, one by one, starting with the most confident one
    centers = zeros(n_chambers,2);
    count = 0;
    chamber_im = zeros(size(response));
    for s=1:cc.NumObjects
        % set pixel with maximum response as center
        pixels = cc.PixelIdxList{sort_ids(s)};
        [~,idx] = max(response(pixels)); idx = idx(1);
        [y,x] = ind2sub(size(response),pixels(idx)); center = [y x];    
        % ignore responses that overlap with existing chambers
        dist = bwdist(chamber_im);
        if dist(center(1),center(2)) < min_dist
            continue
        end
        % snap chambers to be on a grid
        min_dist_x = inf; idx_x = -1;
        min_dist_y = inf; idx_y = -1;
        for c=1:count
            dist_x = abs(centers(c,2)-center(2));
            if dist_x < min_dist_x
                min_dist_x = dist_x; idx_x = c;
            end
            dist_y = abs(centers(c,1)-center(1));
            if dist_y < min_dist_y
                min_dist_y = dist_y; idx_y = c;
            end
        end
        buff_x = 0;
        buff_y = 0;
        if idx_x > -1 && min_dist_x < min_dist/2
            buff_x = center(2)-centers(idx_x,2);
        end
        if idx_y > -1 && min_dist_y < min_dist/2
            buff_y = center(1)-centers(idx_y,1);
        end
        if response(center(1)-buff_y,center(2)-buff_x)/response(center(1),center(2)) > .7
            center = center - [buff_y buff_x];
        end      
        % add this chamber to the list of chambers
        count = count+1;
        centers(count,:) = center;
        chamber_im(center(1),center(2)) = 1;
        % accept at most n_chambers responses
        if count==n_chambers
            break
        end
    end

    % If not all chambers were found, see if there is free space amongst
    % detected chambers that can facilitate the missing chambers
    while count < n_chambers
        % find point maximally far from all chambers (and border)
        chamber_im(1,:) = 1; chamber_im(end,:) = 1;
        chamber_im(:,1) = 1; chamber_im(:,end) = 1;
        dist = bwdist(chamber_im);
        [y,x] = find(dist == max(dist(:)));
        center = [y(1) x(1)];        
        % snap chambers to be on a grid
        min_dist_x = inf; idx_x = -1;
        min_dist_y = inf; idx_y = -1;
        for c=1:count
            dist_x = abs(centers(c,2)-center(2));
            if dist_x < min_dist_x
                min_dist_x = dist_x; idx_x = c;
            end
            dist_y = abs(centers(c,1)-center(1));
            if dist_y < min_dist_y
                min_dist_y = dist_y; idx_y = c;
            end
        end
        buff_x = 0;
        buff_y = 0;
        if idx_x > -1 
            buff_x = center(2)-centers(idx_x,2);
        end
        if idx_y > -1 
            buff_y = center(1)-centers(idx_y,1);
        end
        center = center - [buff_y buff_x];
        % if chamber is too close to other chambers, do not add it
        if dist(center(1),center(2)) < min_dist
            break
        end        
        % add chamber to the list of chambers
        count = count+1;
        centers(count,:) = center;
        chamber_im(center(1),center(2)) = 1;    
    end
    
    % Finish
    % if bg was downscaled, upscale all outputs accordingly
    if img_sz(1) > size(blobs,1)
        centers = centers*scale;
        r = r*scale;
        w = w*scale;
        h = h*scale;
    end
    % return at most n_chambers
    if count < n_chambers
        centers = centers(1:count,:);
    end
    % close waitbar
    if do_use_display
        multiWaitbar(waitstr,'Close');
        drawnow
    else
        fprintf(1,'\n');
    end        
end

function masks = make_circle_masks(r)
    masks = cell(1,2);
    buffer = max(1,round(r*.1));    
    sz = r*2+2*buffer+1;
    
    % EDGE MASK
    mask = zeros(sz);
    [x,y] = ind2sub(size(mask),1:numel(mask));
    x = x - r -buffer -1;
    y = y - r -buffer -1;
    % edge itself
    valid = abs(x.^2 + y.^2 - r^2) < 2*r;    
    mask(valid) = 1;
    % inner edge penalty
    valid = abs(x.^2 + y.^2 - (r-buffer)^2) < 2*(r-buffer);    
    mask(valid) = -1;
    % normalize so that different bigger masks do not provide higher response
    mask(mask==1) = 1/sum(mask(:)==1);
    mask(mask==-1) = -1/sum(mask(:)==-1);    
    masks{1} = mask;     
        
    % BLOB MASK    
    mask = zeros(sz);
    % interior pixels    
    valid = x.^2 + y.^2 - r^2 < r;
    mask(valid) = 1;
    % exterior pixels
    buff75 = buffer*.75;
    buff25 = buffer*.25;
    valid = abs(x.^2 + y.^2 - (r+buff75)^2) < 2*(r+buff75)*buff25+buff25^2;           
    mask(valid) = -1;
    % normalize so that different bigger masks do not provide higher response
    mask(mask==1) = 1/sum(mask(:)==1);
    mask(mask==-1) = -2/sum(mask(:)==-1);        
    masks{2} = mask;   
end

function masks = make_rect_masks(w, h)
    masks = cell(1,2);
    buffer = max(1,round(min(w,h)*.05));
    sz = [h+2*buffer w+2*buffer];

    % EDGE MASK
    mask = zeros(sz);
    % edge itself    
    mask(buffer+(1:h),buffer+(1:2)) = 1;
    mask(buffer+(1:h),buffer+(w-1:w)) = 1;
    mask(buffer+(1:2),buffer+(1:w)) = 1;
    mask(buffer+(h-1:h),buffer+(1:w)) = 1;
    % inner edge penalty
    mask(2*buffer+1:h,2*buffer+(1:2)) = -1;
    mask(2*buffer+1:h,w-1:w) = -1;
    mask(2*buffer+(1:2),2*buffer+1:w) = -1;
    mask(h-1:h,2*buffer+1:w) = -1;
    % normalize so that different bigger masks do not provide higher response
    mask(mask==1) = 1/sum(mask(:)==1);
    mask(mask==-1) = -1/sum(mask(:)==-1);        
    masks{1} = mask;
    
    % BLOB MASK
    mask = zeros(sz);
    % interior pixels
    mask(buffer+3:h+buffer-2,buffer+3:w+buffer-2) = 1;
    % exterior pixels
    m = max(1,round(buffer/2));
    mask(1:m,:) = -1;
    mask(2*buffer+(h-m+1:h),:) = -1;
    mask(:,1:m) = -1;
    mask(:,2*buffer+(w-m+1:w)) = -1;    
    % normalize so that different bigger masks do not provide higher response
    mask(mask==1) = 1/sum(mask(:)==1);
    mask(mask==-1) = -2/sum(mask(:)==-1);    
    masks{2} = mask;    
end

function [width_range, height_range] = consolid_range(edges, width_range, height_range)        
    step = round(min(size(edges))/100);
    % find width range
    thresh = height_range(1)/4;
    points = find(sum(edges,1)>thresh); points = points(:);
    points = [1; points; size(edges,2)];    
    dists = zeros(size(points));
    for i=1:numel(points)
        for j=1:numel(points)
            dists(i,j) = abs(points(i)-points(j));
        end
    end
    dists = dists(:);
    dists(end+1) = width_range(end);
    dists = unique(dists);    
    indic = zeros(1,width_range(end));
    indic(dists(2:end)) = 1;
    cc = bwconncomp(indic);
    dists = zeros(cc.NumObjects*3,1);
    count = 0;
    for i=1:cc.NumObjects
        values = cc.PixelIdxList{i}(1:step:end);
        dists(count+(1:numel(values))) = values;
        count = count+numel(values);
    end    
    dists = unique(dists);
    valid = dists >= width_range(1) & dists <= width_range(end);
    width_range = dists(valid);    
    % find height range
    thresh = width_range(1)/4;
    points = find(sum(edges,2)>thresh); points = points(:);
    points = [1; points; size(edges,1)];    
    dists = zeros(size(points));
    for i=1:numel(points)
        for j=1:numel(points)
            dists(i,j) = abs(points(i)-points(j));
        end
    end
    dists = dists(:);
    dists(end+1) = height_range(end);
    dists = unique(dists);
    indic = zeros(1,height_range(end));
    indic(dists(2:end)) = 1;
    cc = bwconncomp(indic);
    dists = zeros(cc.NumObjects*3,1);
    count = 0;
    for i=1:cc.NumObjects
        values = cc.PixelIdxList{i}(1:step:end);
        dists(count+(1:numel(values))) = values;
        count = count+numel(values);
    end       
    dists = unique(dists);
    valid = dists >= height_range(1) & dists <= height_range(end);
    height_range = dists(valid);    
end
