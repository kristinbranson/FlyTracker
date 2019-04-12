
% Estimate background model.
%
% To compute a background model, use:
%
%    bg = calib_bg_estimate(vinfo, [PPM], [frame_range])
%
% where [] denotes an optional parameter and:
%
%    vinfo         - handle to input video (see video_open)
%
%    PPM           - pixels per millimeter (default 20)
%
%    frame_range.  - range of frames to process (optional)
%       start      - first frame (default 0)
%       limit      - limit frame (default total # frames)
%       step       - step between frames (default limit/100)
%
% returns:
%
%    bg.                 - background model
%       bg_mean          - mean background estimate
%       bg_var           - per pixel variance estimate
%       {all,soft,hard}. - components of background model
%          bg_mask       - mask indicating which pixel estimates are valid
%          bg_mean       - mean background estimate
%          bg_var        - per pixel variance estimate 
%       blob_sum         - sum of blobs detected at each pixel
%
function bg = calib_bg_estimate(vinfo, PPM, frame_range)
   % set default pixels per millimeters if not provided
   if nargin < 2 || isempty(PPM)
       PPM = 20; % if this value is too small then blobs might not cover
                 % entire body of flies which can result in poor bg image
   end
   % set default frame range if not provided
   if nargin < 3 || isempty(frame_range)
      n_imgs = min(100,vinfo.n_frames);
      frame_range.start = 0;
      frame_range.limit = vinfo.n_frames-1;
      frame_range.step  = floor((vinfo.n_frames-1)/(n_imgs-1));
   end   
   frames = (frame_range.start):(frame_range.step):(frame_range.limit-1);
   % initialize waitbar
   display_available = feature('ShowFigureWindows');
   waitstr = 'Computing background image';
   if display_available
        multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
        waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
   else
        percent = 0;
        fprintf(1,[waitstr ': %d%%'], percent);
   end    
   % compute parameters   
   im = video_read_frame(vinfo,2);
   if (vinfo.sz == 3), im = rgb2gray(im); end
   params.fg_radius = PPM*0.5;
   params.fg_falloff = max(1,round(params.fg_radius*.1));
   % initialize background models
   bg_all  = bg_init(vinfo.sx, vinfo.sy, vinfo.sz);
   bg_soft = bg_init(vinfo.sx, vinfo.sy, vinfo.sz);
   bg_hard = bg_init(vinfo.sx, vinfo.sy, vinfo.sz);      
   % compile a list of comparison frames for finding blobs
   n_sample = 5;
   chunk = round((vinfo.n_frames-10)/(n_sample-1));
   tmpframes = 2:chunk:vinfo.n_frames;
   imgs = zeros(size(im,1),size(im,2),numel(tmpframes));
   for f=1:numel(tmpframes)
       im = video_read_frame(vinfo,tmpframes(f)-1);       
       if (vinfo.sz == 3), im = rgb2gray(im); end
       imgs(:,:,f) = im;
       % update waitbar
       if display_available 
         abort = multiWaitbar(waitstr,f/(numel(frames)+n_sample));
         if abort, bg = 0; return; end
       else
         for d=1:numel(num2str(percent))+1
            fprintf(1,'\b');
         end
         percent = round(f/(numel(frames)+n_sample)*100);
         fprintf(1,'%d%%',percent);
       end       
   end
   diffs = zeros(numel(tmpframes));
   for i=1:numel(tmpframes)
       for j=i+1:numel(tmpframes)
           d = imgs(:,:,i)-imgs(:,:,j);           
           diffs(i,j) = sum(abs(d(:)));
           diffs(j,i) = diffs(i,j);
       end
   end
   total_diffs = sum(diffs);
   valid = total_diffs < median(total_diffs) + std(total_diffs);
   if sum(valid) < 2, valid(:) = 1; end
   rough_mean = mean(imgs(:,:,valid),3);   
   tmp = im-rough_mean;
   dmin = prctile(tmp(:),.1);
   dmax = prctile(tmp(:),99.9);
   params.invert = abs(dmax) > abs(dmin);   
   if params.invert, rough_mean = 1-rough_mean; im = 1-im; end
   curr_bg = rough_mean;
   % compute difference threshold
   im_diff = im-rough_mean;
   [~,b] = hist(im_diff(:),10);
   diff_th = b(4);
   prct_fg = sum(im_diff(:) < diff_th)/numel(im_diff(:));
   prct_th = max(0.1,prct_fg*2);
   converged = zeros(size(im));
   % keep track of where blob has been
   blob_sum = zeros(size(im));
   % randomize order of frames
   frames = frames(randperm(numel(frames)));
   % estimate models    
   for f=1:numel(frames)
      id = frames(f);
      % load frame
      im = video_read_frame(vinfo, id);
      % convert to grayscale and invert for detections (if specified)
      if (vinfo.sz == 3), im_gray = rgb2gray(im); else im_gray = im; end
      if (params.invert), im_gray = 1-im_gray; im = 1-im; end
      % reject image if it's too different from current background image 
      %  (for instance frames in shadow experiment)
      diffr = im_gray-curr_bg;      
      if sum(abs(diffr(:))>.1)/numel(im) > prct_th
          continue
      end
      % threshold      
      im_th = diffr < diff_th;
      % estimate foreground probabilty and mask
      fg_dist = double(bwdist(im_th));
      fg_prob = ...
         1./(1+exp((fg_dist-params.fg_radius)/params.fg_falloff));
      fg_mask = (fg_prob >= 0.5);
      blob_sum = blob_sum + im_th;
      % replicate fg estimates to full image size
      bg_prob_z = repmat(1-fg_prob,[1 1 vinfo.sz]);
      bg_mask_z = repmat(1-fg_mask,[1 1 vinfo.sz]);
      % update background models
      bg_all  = bg_update(bg_all, im, ones([vinfo.sx vinfo.sy vinfo.sz]));
      bg_soft = bg_update(bg_soft, im, bg_prob_z);
      bg_hard = bg_update(bg_hard, im, bg_mask_z);
      % merge background models
      bg = bg_merge(bg_all, bg_soft, bg_hard);
      % check whether bg has converged
      prev_bg = curr_bg;
      unseen = bg_hard.bg_weight==0;
      curr_bg = bg.bg_mean .* (1-unseen) + curr_bg .* unseen;      
      if f>=20 % more than 20 images have been processed
          diffr = abs(prev_bg-curr_bg);
          ok = diffr./median(curr_bg(:)) < .001 & ...
               bg_hard.bg_weight >= 10;
          converged(~fg_mask) = ok(~fg_mask);
          if sum(converged(:))/numel(converged) > .995
              break
          end
      end
      % update waitbar
      if display_available 
         abort = multiWaitbar(waitstr,(f+n_sample)/(numel(frames)+n_sample));
         if abort, bg = 0; return; end
      else
         for d=1:numel(num2str(percent))+1
            fprintf(1,'\b');
         end
         percent = round((f+n_sample)/(numel(frames)+n_sample)*100);
         fprintf(1,'%d%%',percent);
      end
   end     
   if ~exist('bg','var')
       bg.bg_mean = rough_mean;
       disp('Warning: only used 5 images for background computation.')
   end
   % store blob sum
   bg.blob_sum = blob_sum;     
   bg.invert = params.invert;
   % close waitbar
   if display_available
       multiWaitbar(waitstr,1); pause(.5);
       multiWaitbar(waitstr,'Close');
       drawnow
   else
       for d=1:numel(num2str(percent))+1
          fprintf(1,'\b');
       end
       percent = round((f+5)/(numel(frames)+n_sample)*100);
       fprintf(1,'%d%%',percent); 
       fprintf(1,'\n');
   end    
end

% initialize background model
function bg = bg_init(sx, sy, sz)
   bg.bg_sum    = zeros([sx sy sz]);
   bg.bg_sum2   = zeros([sx sy sz]);
   bg.bg_weight = zeros([sx sy sz]);
end

% update background model
function bg = bg_update(bg, im, w)
   bg.bg_sum    = bg.bg_sum + w.*im;
   bg.bg_sum2   = bg.bg_sum2 + w.*im.*im;
   bg.bg_weight = bg.bg_weight + w;
end

% finalize background model
function bg_final = bg_finalize(bg)
   bg_final.bg_mask = (bg.bg_weight > 0);
   bg_final.bg_mean = bg.bg_sum ./ (bg.bg_weight + (1-bg_final.bg_mask));
   bg_final.bg_var  = ...
      ((bg.bg_sum2) ...
       - 2.*(bg.bg_sum).*(bg_final.bg_mean) ...
       + (bg.bg_weight.*bg_final.bg_mean.*bg_final.bg_mean)) ./ ...
      (bg.bg_weight + (1-bg_final.bg_mask));
end

% merge background models
function bg = bg_merge(bg_all, bg_soft, bg_hard)
   % finalize models
   bg_a = bg_finalize(bg_all);
   bg_s = bg_finalize(bg_soft);
   bg_h = bg_finalize(bg_hard);
   % combine models using pixel masks
   bg.bg_mean = ...
      (bg_h.bg_mean).*(bg_h.bg_mask) + ...
      (bg_s.bg_mean).*(1-bg_h.bg_mask).*(bg_s.bg_mask) + ...
      (bg_a.bg_mean).*(1-bg_h.bg_mask).*(1-bg_s.bg_mask).*(bg_a.bg_mask);
   bg.bg_var = ...
      (bg_h.bg_var).*(bg_h.bg_mask) + ...
      (bg_s.bg_var).*(1-bg_h.bg_mask).*(bg_s.bg_mask) + ...
      (bg_a.bg_var).*(1-bg_h.bg_mask).*(1-bg_s.bg_mask).*(bg_a.bg_mask);
   % store submodels
   bg.all  = bg_a;
   bg.soft = bg_s;
   bg.hard = bg_h;
end
