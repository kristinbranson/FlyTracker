
% Determine fertility of detections based on size and atomicity.
%
function fertility = detection_fertility(det,params)
   n_obj = det.body_cc.NumObjects;
   % initialize fertilities to default of 1
   fertility = ones([n_obj 1]);   
   % collect body size constraints
   mean_body_area = params.mean_area;
   max_body_area  = params.max_area;
   max_major_axis = params.max_major_axis;
   max_minor_axis = params.max_minor_axis;
   % loop through all bodies
   for i=1:n_obj
       % compute fertility based on mean body area
       n_pix = det.body_props(i).Area;
       fert = round(n_pix/mean_body_area);  
       % lower limit fertility based on max body area
       major_ax = det.body_props(i).MajorAxisLength;
       minor_ax = det.body_props(i).MinorAxisLength;
       if n_pix > max_body_area || ...
          major_ax > max_major_axis || ...
          minor_ax > max_minor_axis
           fert = max(fert,2);
       end
       fertility(i) = fert;
   end
   % give atomic detections fertility of at least 1
   is_atomic = is_atomic_detection(det,params);
   fertility = max(fertility,is_atomic);
end
