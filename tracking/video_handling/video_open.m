
% Open a video and return a handle to it.
%
%    vinfo = video_open(filename)
%
% where filename is a video file that supports random access to frames.
% Returns a vinfo structure which serves as a handle for accessing  
% individual video frames.
%
%    vinfo = video_open(filename, cache_size)
%
% where filename is a video file that does not support random access to
% frames. Video will be read in batch of cache_size (default 100) frames. 
%
function vinfo = video_open(filename, cache_size)
   % check arguments
   if (nargin < 1), error('missing filename argument'); end
   % default cache size (# frames) for files not supporting random access
   if (nargin < 2), cache_size = 100; end
   % 
   if exist(filename,'file')
       % extend filename to use absolute path
       filename = absolute_path(filename);
   else       
       error([filename ' does not exist']);
   end
   % determine type of video
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% .seq format (requires Piotr's toolbox to be installed)
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   if numel(filename) > 4 && strcmp(filename((end-3):end),'.seq')
      % store name and type
      vinfo.filename = filename;
      vinfo.type = 'seq';
      % get file info
      vinfo.seq.info = seqIo(filename, 'getInfo');
      % create seq reader
      vinfo.seq.sr = seqIo(filename, 'reader');
      % store frame count and size
      vinfo.n_frames = vinfo.seq.info.numFrames;
      % store frame rate
      vinfo.fps = vinfo.seq.info.fps;
      % store frame size
      vinfo.sx = vinfo.seq.info.height;
      vinfo.sy = vinfo.seq.info.width;
      vinfo.sz = vinfo.seq.info.imageBitDepth./8;
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% .ufmf format (requires JAABA or Ctrax to be installed)
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   elseif numel(filename) > 5 && strcmp(filename((end-4):end),'.ufmf')
      % store name and type
      vinfo.filename = filename;
      vinfo.type = 'ufmf';
      % read file
      vinfo.ufmf = ufmf_read_header(filename);
      % store number of frames
      vinfo.n_frames = vinfo.ufmf.nframes;
      % store frame rate
      vinfo.fps = 1/mean(diff(vinfo.ufmf.timestamps));
      % store frame size
      vinfo.sx = vinfo.ufmf.nc;
      vinfo.sy = vinfo.ufmf.nr;
      vinfo.sz = 1;
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
   %%% standard video format
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   else
      try %% Use mmread (usually faster than VideoReader)
          % store name and type
          vinfo.filename = filename;
          vinfo.type = 'mmread';
          % check that file can be opened
          fid = fopen(filename, 'r');
          if (fid == -1)
             error(['unable to open file ' filename ', using VideoReader']);
          else
             header = fgetl(fid);
             if ~isempty(strfind(header,'CNCVCanonAVC0005'))
                 % files from this camera cause Matlab to crash, 
                 % so switching to VideoReader upon error fails 
                 %    --> throw error manually
                 error('mmreader fails for CNCVCanonAVC0005 files, using VideoReader');
             end
             fclose(fid);
          end
          % use mmread to obtain file information
          loaded_all = 0;      
          if isinf(cache_size)
            v = mmread(vinfo.filename);   
            loaded_all = 1;
          else
            v = mmread(vinfo.filename, [], [0 1]); % read first 1 second
          end      
          vinfo.mmread.width         = v.width;
          vinfo.mmread.height        = v.height;
          vinfo.mmread.rate          = v.rate;
          vinfo.mmread.nrFramesTotal = v.nrFramesTotal;
          vinfo.mmread.totalDuration = v.totalDuration;
          % determine frame rate based on distance between timestamps
          dt = diff(v.times);
          valid = abs(dt - median(dt)) < median(dt)*.1;
          vinfo.fps = 1/mean(dt(valid));
          % determine number of frames based on duration and framerate
          vinfo.n_frames = round(v.totalDuration*vinfo.fps);      
          % store frame size
          vinfo.sx = vinfo.mmread.height;
          vinfo.sy = vinfo.mmread.width;
          vinfo.sz = 1;
          % check whether cache_size is too large
          if ~isinf(cache_size)
            maxRAM = 200000000; %200 megabytes
            max_cache_size = floor(maxRAM/vinfo.sx/vinfo.sy);
            cache_size = min(cache_size,max_cache_size);
          end      
          % reduce cache size if longer than video
          cache_size = min(cache_size, vinfo.n_frames);
          % initialize frame cache
          vinfo.mmread.cache.cache_size = cache_size;
          if loaded_all
            num_valid = numel(v.times);
            vinfo.mmread.cache.data = ...
                   zeros([vinfo.sx vinfo.sy vinfo.sz num_valid],'uint8');
            vinfo.mmread.cache.frame_id = 0:num_valid-1;   
            for n = 1:num_valid
                im = double(v.frames(n).cdata);
                if size(im,3) > 1
                    im = (im(:,:,1)+im(:,:,2)+im(:,:,3))./3;
                end
                vinfo.mmread.cache.data(:,:,:,n) = im;
            end
            clear v
            vinfo.mmread.cache.is_valid = true;
            vinfo.mmread.cache.f_start = 0;  
            vinfo.mmread.cache.f_end   = num_valid-1;
          else
            vinfo.mmread.cache.data  = [];
            vinfo.mmread.cache.frame_id = [];
            vinfo.mmread.cache.is_valid = false; % is cache valid?
            vinfo.mmread.cache.f_start = 0;      % first frame in cache
            vinfo.mmread.cache.f_end   = 0;      % last frame (may be < cache size)
          end
      catch %% In case mmread fails, use VideoReader
          filename = absolute_path(filename);
          % store name and type
          vinfo.filename = filename;
          vinfo.type = 'vidobj';
          % read file
          vinfo.vidobj = VideoReader(filename);
          % store number of frames
          vinfo.n_frames = vinfo.vidobj.NumberOfFrames;
          % store frame rate
          vinfo.fps = vinfo.vidobj.FrameRate;
          % store frame size
          vinfo.sx = vinfo.vidobj.Height;
          vinfo.sy = vinfo.vidobj.Width;
          vinfo.sz = 1;              
      end
   end
end
