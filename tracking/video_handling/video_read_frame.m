
% Read requested frame from the video.
%
%    [im,id] = video_read_frame(vinfo, id)
%
% returns im, the frame of the video specified by id (0-indexed), and the 
% true frame id of the im returned (for videos with missing frames this is  
% the nearest neighbor to the requested id). All returned images are
% converted to grayscale.
%
function [im,id] = video_read_frame(vinfo, id)
   % check that frame is in range
   if ((id < 0) || (id >= vinfo.n_frames))
      error(['cannot read out of range frame ' ...
             num2str(id) ' of ' num2str(vinfo.n_frames)]);
   end
   % check type of video
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% .seq format (requires Piotr's toolbox to be installed)
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   if (strcmp(vinfo.type,'seq'))
      % read frame
      flag = vinfo.seq.sr.seek(id);
      if (~flag)
         error('unable to seek to specified frame in seq file');
      end
      im  = double(vinfo.seq.sr.getframe()) ./ ...
            ((2.^vinfo.seq.info.imageBitDepthReal)-1);
      % convert to grayscale if needed
      if (size(im,3) > vinfo.sz)
         im = rgb2gray(im);
      end   
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% .ufmf format (requires JAABA or Ctrax to be installed)
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
   elseif (strcmp(vinfo.type,'ufmf'))
      im = ufmf_read_frame(vinfo.ufmf, id+1);
      im = double(im)/255;
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
   %%% standard video format, read by VideoReader
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
   elseif (strcmp(vinfo.type,'vidobj'))
      im = read(vinfo.vidobj,id+1);
      im = double(im)/255;
      if size(im,3) > 1
          im = (im(:,:,1)+im(:,:,2)+im(:,:,3))./3;
      end      
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
   %%% standard video format, read by mmread
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
   elseif (strcmp(vinfo.type,'mmread'))
      % check if frame is in cache
      if (~((vinfo.mmread.cache.is_valid) && ...
            (vinfo.mmread.cache.f_start <= id) && ...
              (id <= vinfo.mmread.cache.f_end)))         
         cache_size = vinfo.mmread.cache.cache_size;
         % set cache frame range
         f_start = id;
         f_end   = id + cache_size - 1;
         f_start = max(f_start, 0);
         f_end   = min(f_end, vinfo.n_frames-1);
         % compute time indices
         t_start = (f_start - 0.8)./(vinfo.fps);
         t_end   = (f_end + 0.8)./(vinfo.fps);
         % read video file
         vid = mmread(vinfo.filename, [], [t_start t_end]);
         % handle the case where mmread failed to obtain the id by 
         %    re-reading with larger padding around the frame
         if numel(vid.times)==0 || id/vinfo.fps < vid.times(1) - vinfo.fps/2
             f_start = id-5;
             f_end   = id+5;
             f_start = max(f_start, 0);
             f_end   = min(f_end, vinfo.n_frames-1);
             t_start = (f_start - 0.8)./(vinfo.fps);
             t_end   = (f_end + 0.8)./(vinfo.fps);
             vid_pad = mmread(vinfo.filename, [], [t_start t_end]);
             [alltimes,ind_pad,ind] = union(vid_pad.times,vid.times);
             vid.times = alltimes;
             vid.frames = [vid_pad.frames(ind_pad) vid.frames(ind)];
         end
         % adjust cache_size to number of actual frames read
         cache_size = numel(vid.frames);
         % allocate cache if needed
         vinfo.mmread.cache.data = ...
           zeros([vinfo.sx vinfo.sy vinfo.sz cache_size],'uint8');
         vinfo.mmread.cache.frame_id = zeros(1,cache_size);
         % fill cache
         for n = 1:cache_size
            im = double(vid.frames(n).cdata);
            if size(im,3) > 1
                im = (im(:,:,1)+im(:,:,2)+im(:,:,3))./3;
            end
            vinfo.mmread.cache.data(:,:,:,n) = im;
            vinfo.mmread.cache.frame_id(n) = round(vid.times(n)*vinfo.fps);
         end
         % update cache status
         vinfo.mmread.cache.f_start  = vinfo.mmread.cache.frame_id(1);
         vinfo.mmread.cache.f_end    = vinfo.mmread.cache.frame_id(end);
         vinfo.mmread.cache.is_valid = true;
         % update vinfo object in caller
         vinfo_name = inputname(1);
         if (~isempty(vinfo_name))
            assignin('caller', vinfo_name, vinfo);
         else
            warning( ...
               ['could not update frame cache during video read - ' ...
                'this may negatively impact performance'] ...
            );
         end
      end
      % load from cache
      [~,idx] = min(abs(vinfo.mmread.cache.frame_id - id));
      id = vinfo.mmread.cache.frame_id(idx);
      im = vinfo.mmread.cache.data(:,:,:,idx);
      if isa(im,'uint8')
          im = double(im)/255;
      end
   else
      error('unrecognized video type');
   end
end
