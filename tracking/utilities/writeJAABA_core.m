function writeJAABA_core(moviefilename, trk, feat, calib, outdir, ...
                         save_JAABA_trk_mat_file, save_JAABA_perframe_features, save_JAABA_movie_link_or_copy)
    % create the output directory
    if ~exist(outdir,'dir'),
      [success1,msg1] = mkdir(outdir);
      if ~success1,
        disp(msg1);
        return
      end
    end
    [~,~,movie_ext] = fileparts(moviefilename);
    jaabamoviefilename = fullfile(outdir,['movie' movie_ext]);

    % write timestamps
    total_frames = size(trk.data,2);
    n_trkfeat = size(trk.data,3);
    n_flies = size(trk.data,1);
    timestamps = (1:total_frames) / calib.FPS;

    % get wing index
    wingidx = find(strcmp(trk.names,'wing l x'));

    % write trx
    for i=1:n_flies
        data = trk.data(i,:,:);
        data = reshape(data,total_frames,n_trkfeat);
        valid_inds = find(~isnan(data(:,1)));
        % movie in its original folder
        track.moviename     = moviefilename;
        % movie stored in JAABA folder
        track.moviefile     = jaabamoviefilename;
        % video info
        track.firstframe    = valid_inds(1);
        track.off           = 1-track.firstframe;
        track.endframe      = valid_inds(end);
        track.nframes       = track.endframe - track.firstframe + 1;
        track.fps           = calib.FPS;
        track.pxpermm       = calib.PPM;
        %track.arena %?
        % fly info
        track.id            = i;
        track.sex           = 'm';
        % time stamps
        frames = track.firstframe:track.endframe;
        track.timestamps    = frames/track.fps;
        track.dt            = diff(track.timestamps);
        % raw features in pixels
        track.x             = data(frames,1);
        track.y             = data(frames,2);
        track.theta         = -data(frames,3);
        track.a             = data(frames,4)/4;
        track.b             = data(frames,5)/4;
        track.xwingl        = data(frames,wingidx);
        track.ywingl        = data(frames,wingidx+1);
        track.xwingr        = data(frames,wingidx+2);
        track.ywingr        = data(frames,wingidx+3);
        % raw features in mm (necessary?)
        track.x_mm          = track.x/track.pxpermm;
        track.y_mm          = track.y/track.pxpermm;
        track.a_mm          = track.a/track.pxpermm;
        track.b_mm          = track.b/track.pxpermm;
        track.theta_mm      = track.theta; %?
        
        trx(i) = track;  %#ok<AGROW> 
    end

    % save trx.mat
    if save_JAABA_trk_mat_file ,
      save(fullfile(outdir,'trx.mat'),'timestamps','trx','-v7.3')
    end

    % write perframe folder
    if save_JAABA_perframe_features ,
        perframedir = fullfile(outdir,'perframe');        
        if ~exist(perframedir,'dir'),
            [success1,msg1] = mkdir(perframedir);
            if ~success1
                disp(msg1);
                return
            end
        end
        aug_feat = feat_augment(feat);
        n_feat = size(aug_feat.data,3);
        for i=1:n_feat
            data = cell(1,n_flies);
            for s=1:n_flies
                data{s} = aug_feat.data(s,trx(s).firstframe:trx(s).endframe,i);
            end
            units.numerator = cell(1,0);
            units.denominator = cell(1,0);
            save(fullfile(perframedir,[aug_feat.names{i}]),'data','units','-v7.3')
        end
    end

    % copy/soft-link movie
    if save_JAABA_movie_link_or_copy ,
        if exist(jaabamoviefilename,'file'),
            delete(jaabamoviefilename);
        end
        if isunix(),
            % try to figure out a canonical path to the movie file
            % if that goes badly, just use the moviefilename
            [status1,result1] = unix(sprintf('realpath %s',moviefilename));
            if status1 == 0,
                canonicalmoviefilename = strtrim(result1);
            else
                canonicalmoviefilename = '';
            end
            if isempty(canonicalmoviefilename),
                canonicalmoviefilename = moviefilename;
            end
            % make the softlink
            cmd = sprintf('ln -s %s %s',canonicalmoviefilename,jaabamoviefilename);
            unix(cmd);
            % test to make sure it worked
            [status2,result2] = unix(sprintf('realpath %s',jaabamoviefilename));
            result2_trimmed = strtrim(result2);
            did_create_soft_link = ( status2==0 && strcmp(result2_trimmed,canonicalmoviefilename) ) ;
        else
            did_create_soft_link = false;
        end

        % If we failed to create the softlink, delete the intended softlink file name,
        % so we don't leave a mess behind.
        if ~did_create_soft_link,
            if ispc() ,
                if exist([jaabamoviefilename,'.lnk'],'file')
                    delete([jaabamoviefilename,'.lnk']);
                end
            end
            if exist(jaabamoviefilename,'file')
                delete(jaabamoviefilename);
            end
            disp('WARNING: Could not write softlink');
        end
    end
end  % function
