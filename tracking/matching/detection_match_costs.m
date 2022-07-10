
% Compute match costs between detections in neighboring frames, 
% based on body overlap (if segmentation available) and distance.
%
function cost_mx = detection_match_costs(det_curr, det_next, PPM)
   % get number of body components
   n_body_curr = det_curr.body_cc.NumObjects;
   n_body_next = det_next.body_cc.NumObjects;      
   % If segmentation available, use overlap and distance between centroids
   use_segmentation = isfield(det_curr.body_cc,'PixelIdxList');
   if use_segmentation       
       w_dist = 1;
       % weigh overlap to be one fly body length (2mm)
       w_overlap = 10;
       if nargin > 2 && ~isempty(PPM)
           w_overlap = 2*PPM;
       end
       % initialize match feature matrices
       %    overlap - intersection over union (range [0 1])
       %    dist    - distance from centroid to closest point in other body
       f_overlap = zeros([n_body_curr n_body_next]);
       f_dist    = zeros([n_body_curr n_body_next]); 
       % convert body indices to subscripts for future reference and
       % create index map for next image to compute overlap
       xy_next = cell(n_body_next,2);       
       im_next = zeros(det_next.body_cc.ImageSize);
       for b = 1:n_body_next
           pixels = det_next.body_cc.PixelIdxList{b};
           [x, y] = ind2sub(det_next.body_cc.ImageSize, pixels);
           xy_next{b,1} = x;
           xy_next{b,2} = y;
           im_next(pixels) = b;
       end
       % compute body match features   
       for b1 = 1:n_body_curr
          % get body pixels and properties      
          pixels1 = det_curr.body_cc.PixelIdxList{b1};
          props1  = det_curr.body_props(b1);
          yc1 = props1.Centroid(1); xc1 = props1.Centroid(2);
          [x1, y1] = ind2sub(det_curr.body_cc.ImageSize, pixels1);
          % get overlap variables
          n1 = numel(pixels1);
          next_inds = im_next(pixels1);      
          % loop over possible matches in next frame
          for b2 = 1:n_body_next
             % get body pixels and properties
             pixels2 = det_next.body_cc.PixelIdxList{b2};
             props2  = det_next.body_props(b2);
             % compute overlap
             n2 = numel(pixels2);
             n_itrsct = sum(next_inds==b2);
             f_overlap(b1,b2) = n_itrsct/(n1+n2-n_itrsct);
             % compute centroid to closest point distance         
             yc2 = props2.Centroid(1); xc2 = props2.Centroid(2);         
             x2 = xy_next{b2,1}; y2 = xy_next{b2,2};
             dx1 = x2 - xc1; dy1 = y2 - yc1;
             dx2 = x1 - xc2; dy2 = y1 - yc2;
             dist1 = min(sqrt(dx1.*dx1 + dy1.*dy1));
             dist2 = min(sqrt(dx2.*dx2 + dy2.*dy2));
             f_dist_this_maybe = min(dist1,dist2) ;  % this seems to be empty occasionally --ALT, 2022-07-08
             f_dist(b1,b2) = fif(isempty(f_dist_this_maybe), inf, f_dist_this_maybe) ;  % hopefully this is a reasonable patch
          end
       end
       % compute match cost matrix
       cost_mx = ...
          (w_overlap).*(1-f_overlap) + ...
          (w_dist).*(f_dist);
   % If segmentation not available, use distance between centroids
   else
       % initialize match feature matrices
       %    dist - distance between body centroids 
       f_dist = zeros([n_body_curr n_body_next]); 
       % compute body match features
       for b1 = 1:n_body_curr
          % get body properties
          props1  = det_curr.body_props(b1);
          yc1 = props1.Centroid(1); xc1 = props1.Centroid(2);
          % loop over possible matches in next frame
          for b2 = 1:n_body_next
             % get body properties
             props2  = det_next.body_props(b2);
             yc2 = props2.Centroid(1); xc2 = props2.Centroid(2);
             % compute centroid to centroid distance
             dx = xc1 - xc2;
             dy = yc1 - yc2;
             f_dist(b1,b2) = sqrt(dx.*dx + dy.*dy);
          end
       end
       % compute match cost matrix
       cost_mx = f_dist;       
   end
end
