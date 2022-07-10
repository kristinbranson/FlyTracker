function tracker(videos, options, calibration_file_name)
% Track (and calibrate) videos.
%
% To run tracker with interface, use:
%
%   tracker
%
% To run tracker without interface, use:
%
%   tracker(videos, [options], [f_calib])
%
%  where [] denotes an optional parameter (default values used if set to []) and:
%
%    videos.            - videos to process through tracking pipeline
%       dir_in          - directory containing input videos
%       dir_out         - directory in which to save results
%       filter          - file filter (eg '*.ufmf') (default: '*')
%       
%    options.           - cluster processing and output options
%       max_minutes     - maximum number of minutes to process (default: inf)
%       num_cores       - number of workers to process jobs in parallel (default: 1)
%       granularity     - number of video frames per job (default: 10,000)
%       num_chunks      - number of chunks to process (default: num_frames/granularity)
%       save_JAABA      - write JAABA folders from features (default: false)
%       save_xls        - save tracks and features to a folder of .csv files (default: false)
%       save_seg        - save segmentation from tracking process (default: false)
%       fr_samp         - Number of frames to sample when computing
%                         background model. (default: 100)
%       isdisplay       - Whether graphical display should be used for waitbars etc.
%       startframe      - Frame to start tracking on. Default = 1
%       force_calib     - If true, arena calibration is done for each video, 
%                         regardless of setting in calibration file (default: false)
%       expdir_naming   - Whether to use JAABA-style experiment directory
%                         naming scheme for files. (default: false)
%       arena_r_mm      - Radius of the arena in mm. This will be used to
%                         set the resolution (PPM, pixels per millimeter)
%                         if a circular arena is automatically detected.
%       n_flies         - Number of flies. Only used when run in
%                         non-interactive mode to override input
%                         calibration. (default: not defined)
%       n_flies_is_max  - Whether n_flies is an upper limit on the number
%                         of flies or an actual count. (default: false)
%      
%    f_calib            - File containing calibration data.  If missing or empty,
%                         defaults to [videos.dir_in]/calibration.mat.  If
%                         running without an interface, a calibration file must
%                         be present.
%
% Note that for batch use-cases, core_tracker() is now the recommended interface
% to FlyTracker.

   % add tracker to path if its not there already
   check = which('is_atomic_detection');
   if isempty(check)
       parentdir = fileparts(mfilename('fullpath'));
       addpath(genpath(parentdir));
   end   

   if nargin == 0
       % If tracker is started with no arguments, load interface
       is_display_available = feature('ShowFigureWindows');
       if is_display_available
          tracker_interface();          
       else          
          disp('No display available: run tracker with arguments:') 
          help tracker
          return
       end
   else
       % If tracker is run with arguments, make sure all fields are entered
       if nargin < 2, options = []; end
       if nargin < 3, calibration_file_name = []; end
       run_tracker(videos, options, calibration_file_name) ;
   end
end

