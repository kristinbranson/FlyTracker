
% Track (and calibrate) videos.
%
% To run tracker with interface, use:
%
%   tracker
%
% To run tracker without interface, use:
%
%   tracker(videos, [options], [f_calib], [vinfo])
%
%  where [] denotes an optional parameter (default values used if set to []) and:
%
%    videos.            - videos to process through tracking pipeline
%       dir_in          - directory containing input videos
%       dir_out         - directory in which to save results
%       filter          - file filter (eg '*.avi') (default: '*')
%       
%    options.           - cluster processing and output options
%       max_minutes     - maximum number of minutes to process (default: inf)
%       num_cores       - number of workers to process jobs in parallel? (default: 1)
%       granularity     - number of video frames per job (default: 10,000)
%       num_chunks      - number of chunks to process (default: num_frames/granularity)
%       save_JAABA      - write JAABA folders from features? (default: false)
%       save_xls        - save tracks and feats to xls? (default: false)
%       save_seg        - save segmentation from tracking process? (default: false)
%       f_parent_calib  - path to parent calibration file -- defines
%                         parameters that are usually preserved within
%                         videos of the same rig based on a calibration
%                         file from a different video. If not
%                         defined/empty, all parameters are estimated from
%                         this video.                          
%       fr_samp         - Number of frames to sample when computing
%                         background model. (default: 100)
%       isdisplay       - Whether display is available for waitbars etc.
%       startframe      - Frame to start tracking on. Default = 1
%       force_all       - Whether to force all computations, regardless of
%                         whether the files these computations would
%                         compute already exist. (default: false)
%       force_calib     - Whether to run calibration even if calibration
%                         mat file already exists. (default: false)
%       force_tracking  - Whether to run tracking, even if track files
%                         already exist. (default: false)
%       force_features  - Whether to run feature computation even if
%                         feature mat file alreay exists. (default: false)
%       expdir_naming   - Whether to use JAABA-style experiment directory
%                         naming scheme for files. (default: false)
%       arena_r_mm      - Radius of the arena in mm. This will be used to
%                         set the resolution (PPM, pixels per millimeter)
%                         if a circular arena is automatically detected.
%       n_flies         - Number of flies. Only used when run in
%                         non-interactive mode to override parent
%                         calibration. (default: not defined)
%       n_flies_is_max  - Whether n_flies is an upper limit on the number
%                         of flies or an actual count. (default: false)
%      
%    f_calib            - file containing calibration data (default: [videos.dir_in]/calibration.mat)
%    vinfo              - if specified, ignore videos and use loaded video
%
function tracker(videos, options, calibration_file_name)

   % add tracker to path if its not there already
   check = which('is_atomic_detection');
   if isempty(check)
       parentdir = fileparts(mfilename('fullpath'));
       addpath(genpath(parentdir));
   end   

   if nargin == 0
       % If tracker is started with no arguments, load interface
       display_available = feature('ShowFigureWindows');
       if display_available
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

