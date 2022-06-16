function flag = tracker_job(type, varargin)
   % Helper function to run individual tracking jobs
   % check job type
   flag = true;
   if (strcmp(type,'track_calibrate'))
      flag = tracker_job_calibrate(varargin{:});
   elseif (strcmp(type,'track_process'))
      flag = tracker_job_process(varargin{:});
   elseif (strcmp(type,'track_combine'))
      flag = tracker_job_combine(varargin{:});
   elseif (strcmp(type,'track_consolidate'))
      tracker_job_consolidate(varargin{:});
   elseif (strcmp(type,'track_features'))
      tracker_job_features(varargin{:});
   else
      % invalid job type
      flag = false;
   end
end
