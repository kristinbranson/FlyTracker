function core_tracker(videos_dir_out, videos_dir_in, videos_filter, options, f_calib)
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
    %    f_calib            - file containing calibration data (default: [videos_dir_in]/calibration.mat)
    %    vinfo              - if specified, ignore videos and use loaded video
    %
    
    % default options
    options_def = DefaultOptions();
    
    % set display variables
    display_available = feature('ShowFigureWindows');
    fs = 72/get(0,'ScreenPixelsPerInch'); % scale fonts to resemble OSX
    dh = [];  % dialog handle
    
    % fill in specified options
    if ((nargin < 2) || (isempty(options))), options = options_def; end
    options = set_defaults(options, options_def);
    if options.force_all,
        options.force_calib = true;
        options.force_tracking = true;
        options.force_features = true;
    end
    
    display_available = display_available && options.isdisplay;
    
    % make sure we don't try to use more workers than available
    n_cores = feature('numCores');
    options.num_cores = min(n_cores,options.num_cores);
    % open parallel pool if not already open
    if options.num_cores > 1
        try
            open_pool = 1;
            if ~isempty(gcp('nocreate'))
                par = gcp;
                n_workers = par.NumWorkers;
                if n_workers == options.num_cores
                    open_pool = 0;
                else
                    delete(gcp);
                end
            end
            if open_pool
                parpool(options.num_cores);
            end
        catch
            options.num_cores = 1;
            str = 'Could not open parallel pool. Using single thread.';
            disp(str);
        end
    end
    
    % collect video information
    vinfo = [] ;
    % convert input/output directories to absolute path form
    videos_dir_in  = absolute_path(videos_dir_in);
    videos_dir_out = absolute_path(videos_dir_out);
    % check video list
    if ((~isfield(videos,'filter')) || (isempty(videos_filter)))
        videos_filter = '*';
    end
    % scan input directory for video files
    vid_files = dir(fullfile(videos_dir_in, videos_filter));
    vid_files([vid_files.isdir]) = [];
    vid_files = { vid_files.name };
    
    % make sure there are videos to process
    n_vids = numel(vid_files);
    if options.expdir_naming,
        assert(n_vids == 1,'expdir_naming = true only allowed when tracking a single video');
    end
    if n_vids < 1
        str = ['No videos to process for: ' fullfile(videos_dir_in, videos_filter)];
        if display_available
            customDialog('warn',str,12*fs);
        else
            disp(str);
        end
        return
    end
    
    % create output directories
    if (~exist(videos_dir_out,'dir')), mkdir(videos_dir_out); end
    for n = 1:n_vids
        dir_vid = get_dir_vid(vid_files{n}, options, videos_dir_out);
        %       [~, name] = fileparts(vid_files{n});
        %       dir_vid = fullfile(videos_dir_out, name);
        if (~exist(dir_vid,'dir')), mkdir(dir_vid); end
    end
    
    % load calibration file
    if nargin < 3 || isempty(f_calib)
        f_calib = fullfile(videos_dir_in, 'calibration.mat');
    end
    if exist(f_calib,'file') && ~(options.force_calib && exist(options.f_parent_calib,'file')),
        D = load(f_calib); parent_calib = D.calib;
    elseif exist(options.f_parent_calib,'file'),
        D = load(options.f_parent_calib); parent_calib = D.calib;
    else
        str = [f_calib ' not found: run calibrator first or input a valid calibration file.'];
        if display_available
            customDialog('warn',str,12*fs);
        else
            disp(str);
        end
        return
    end
    
    % If certain things are defined in options, want those to override values in
    % parent calibration
    if isfield(options, 'n_flies') ,
        parent_calib.n_flies = options.n_flies ;
    end
    if isfield(options, 'arena_r_mm') ,
        parent_calib.arena_r_mm = options.arena_r_mm ;
    end
    if isfield(options,'n_flies_is_max'),
        parent_calib.n_flies_is_max = options.n_flies_is_max;
    end
    
    % compute maximum number of frames to process
    max_frames = round(options.max_minutes*parent_calib.FPS*60);
    endframe = options.startframe + max_frames - 1;
    min_chunksize = 100;
    
    runinfo = struct;
    runinfo.vid_files = vid_files;
    runinfo.frs_per_chunk = cell(1,n_vids);
    
    % package jobs to be run in sequence
    for n = 1:n_vids
        % get input video file
        [path1,name,ext] = fileparts(vid_files{n});
        if options.expdir_naming,
            [~,parent_name] = fileparts(path1);
            display_name = [parent_name,filesep,name];
        else
            display_name = name;
        end
        f_vid = fullfile(videos_dir_in, vid_files{n});
        assert(exist(f_vid,'file')>0);
        dir_vid = get_dir_vid(vid_files{n});
        
        f_params = fullfile(dir_vid,[name,'-params.mat']);
        save(f_params,'options');
        
        % display progress
        waitstr = ['Processing ' display_name ext ...
            '   (movie ' num2str(n) '/' num2str(n_vids) ')'];
        if display_available
            if isempty(dh) || ~ishandle(dh)
                dh = customDialog('wait',waitstr,12*fs);
            else
                child = get(dh,'Children');
                set(child(1),'string',waitstr);
            end
        else
            disp(['*** ' waitstr])
        end
        % check whether video has already been tracked
        f_res_final = fullfile(dir_vid, [name '-track.mat']);
        if options.force_tracking && exist(f_res_final,'file'),
            delete(f_res_final) ;
        end
        if exist(f_res_final,'file')
            disp('Movie already tracked')
            % compute features and learning files if specified
            tracker_job('track_features',f_vid,f_res_final,f_calib,options,options.force_features);
            continue;
        end
        % load video
        if isempty(vinfo)
            vinfo = video_open(f_vid);
            do_close = 1;
        else
            do_close = 0;
        end
        % get length of video
        endframe = min(vinfo.n_frames,endframe);
        n_frames = endframe - options.startframe + 1;
        %n_frames = min(vinfo.n_frames,max_frames);
        % output filenames
        f_bg  = fullfile(dir_vid, [name '-bg.mat']);
        if n_vids > 1 && parent_calib.auto_detect
            % generate new calibration files if multiple videos
            f_calib = fullfile(dir_vid, [name '-calibration.mat']);
        end
        % compute background and calibration if needed
        flag = tracker_job('track_calibrate', f_vid, f_bg, f_calib, options, parent_calib, vinfo, options.force_calib) ;
        if check_abort_bang(dh, flag), return; end
        % load calibration
        D = load(f_calib); calib = D.calib;
        % compute number of chunks to process
        if ~isempty(options.num_chunks)
            n_chunks = options.num_chunks;
            chunksize = ceil(n_frames/n_chunks);
            options.granularity = max(chunksize,min_chunksize);
        end
        n_chunks = ceil(n_frames./options.granularity);
        % loop through all chambers
        valid = find(calib.valid_chambers);
        n_chambers = numel(valid);
        % process tracks for all chambers
        % set frame range
        frs = cell(1,n_chunks);
        f_trks = cell(1,n_chunks);
        for c=1:n_chunks
            fr.start = options.startframe-1+(c-1).*options.granularity;
            fr.step  = 1;
            fr.limit = min(fr.start + options.granularity, endframe);
            frs{c} = fr;
            f_trks{c} = cell(1,n_chambers);
            for i=1:n_chambers
                if n_chambers == 1
                    chamber_str = '';
                else
                    chamber_str = ['-c' num2str(i)];
                end
                % determine output filename
                f_trk = fullfile(dir_vid, ...
                    [name chamber_str '-trk' '-' num2str(frs{c}.start,'%010d') '.mat'] ...
                    );
                f_trks{c}{i} = f_trk;
            end
        end
        runinfo.frs_per_chunk{n} = frs;
        % check whether chamber files already exist
        f_res = fullfile(dir_vid, [name chamber_str '-track.mat']);
        if ~exist(f_res,'file')
            if options.num_cores > 1
                success = zeros(1,n_chunks);
                parfor c = 1:n_chunks
                    % store job parameters
                    if strcmp(ext,'.ufmf')
                        % ufmf cannot be processed in parallel with single fid, must create a new one for each chunk
                        flag = tracker_job('track_process', f_vid, f_bg, f_calib, f_trks{c}, frs{c});
                    else
                        flag = tracker_job('track_process', f_vid, f_bg, f_calib, f_trks{c}, frs{c}, vinfo);
                    end
                    success(c) = flag;
                end
                if check_abort_bang(dh, min(success)), return; end
            else
                for c = 1:n_chunks
                    % store job parameters
                    flag = tracker_job('track_process', f_vid, f_bg, f_calib, f_trks{c}, frs{c}, vinfo);
                    if check_abort_bang(dh, flag), return; end
                end
            end
        end
        % combine results for all chunks (per chamber)
        f_res_list = cell(1,n_chambers);
        for i=1:n_chambers
            if n_chambers == 1
                chamber_str = '';
            else
                chamber_str = ['-c' num2str(i)];
            end
            f_trk_list = cell(1,n_chunks);
            for c=1:n_chunks
                f_trk_list{c} = f_trks{c}{i};
            end
            f_res = fullfile(dir_vid, [name chamber_str '-track.mat']);
            f_res_list{i} = f_res;
            if n_chambers > 1
                chamber_str = ['c' num2str(i) ' - '];
            end
            tracker_job('track_combine', f_res, f_trk_list, f_calib, options, chamber_str);
        end
        % combine results from chambers
        if n_chambers > 1
            tracker_job('track_consolidate', f_res_final, f_res_list, options);
        end
        % compute features and learning files if specified
        tracker_job('track_features', f_vid, f_res_final, f_calib, options, 1);
        
        % close video
        if do_close
            video_close(vinfo);
            vinfo = [];
        end
    end
    
    save(f_params,'runinfo','-append');
    
    if ~isempty(dh) && ishandle(dh)
        child = get(dh,'Children');
        set(child(1),'string','Finished!');
        pause(2)
        delete(dh);
    end
    
end



function do_abort = check_abort_bang(dh, flag)
    do_abort = 0;
    if ~flag
        if ~isempty(dh) && ishandle(dh),
            child = get(dh,'Children');
            set(child(1),'string','** canceled by user **');
            pause(2)
            delete(dh);
        end
        do_abort = 1;
    end
end

    
    
function dir_vid = get_dir_vid(vid_file, options, videos_dir_out)
    if options.expdir_naming,
        dir_vid = videos_dir_out;
    else
        [~, name1] = fileparts(vid_file);
        dir_vid = fullfile(videos_dir_out, name1);
    end
end
    
