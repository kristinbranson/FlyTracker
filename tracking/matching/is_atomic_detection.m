
% Determine whether detections are atomic based on
% a) body is large enough to belong to a single fly, or
% b) body is the only (or largest) component within foreground.
%
function is_atomic = is_atomic_detection(det,params)
   n_obj = det.body_cc.NumObjects;
   is_atomic = zeros([n_obj 1]);
   mean_body_area = params.mean_area;
   for i=1:n_obj
       % check whether body passes size constraint
       n_pix = det.body_props(i).Area;       
       area_pass = n_pix>mean_body_area/3;
       % check whether body passes foreground constraint 
       %   (largest body in a foreground is atomic)
       fg_id = det.body_fg(i);
       fg_bods = det.fg_body{fg_id};
       areas = zeros(1,numel(fg_bods));
       for b=1:numel(fg_bods)
           areas(b) = det.body_props(fg_bods(b)).Area;
       end
       [~,max_idx] = max(areas);
       fg_pass = i == fg_bods(max_idx);
       % if yes to either, body is atomic
       is_atomic(i) = area_pass || fg_pass;
   end
end
