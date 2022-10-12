function core_core_tracker(output_track_file_path, ...
                           working_background_file_name, ...
                           output_segmentation_file_path, ...
                           input_video_file_path, ...
                           options, ...
                           calibration)

    % The function that does the tracking proper, writing
    % output to output_track_file_path
       
    % Do nothing if the output file already exists, unless forced
    if ~options.do_recompute_tracking && logical(exist(output_track_file_path, 'file')) ,
        return
    end
    
    % Delete any old output file, if it exists
    ensure_file_does_not_exist(output_track_file_path) ;
    
    % break down the track file name
    [~, track_file_base_name, ~] = fileparts(output_track_file_path) ;        

    % Synthesize the temporary track file folder name
    if options.do_use_scratch_folder_for_intermediates ,
        scratch_folder_path = get_scratch_folder_path() ;
        temp_track_folder_path = tempname(scratch_folder_path) ;
    else
        temp_track_folder_path = strcat(output_track_file_path, '.intermediates') ;
    end
    
    % If forced, delete any old temporary folder, if it exists
    if options.do_recompute_tracking ,
        ensure_folder_does_not_exist(temp_track_folder_path) ;
    end
    
    % Mkae sure the intermediates folder exists
    ensure_folder_exists(temp_track_folder_path) ;
    
    % If we're going to delete intermediate results, make sure that happens
    if options.do_delete_intermediate_results ,
        cleaner = onCleanup(@()(ensure_folder_does_not_exist(temp_track_folder_path))) ;
    end
    
    % compute maximum number of frames to process
    max_frames = round(options.max_minutes*calibration.FPS*60) ;
    endframe = options.startframe + max_frames - 1;
    min_chunksize = 100;
        
    % load video to get frame count
    vinfo = video_open(input_video_file_path) ;
    frame_count = vinfo.n_frames ;
    video_close(vinfo) ;
    
    % get length of video
    endframe = min(frame_count, endframe) ;
    n_frames = endframe - options.startframe + 1;
    
    % compute number of chunks to process
    if ~isempty(options.num_chunks)
        chunk_count = options.num_chunks;
        chunk_size = ceil(n_frames/chunk_count);
        options.granularity = max(chunk_size,min_chunksize) ;
    end
    chunk_count = ceil(n_frames./options.granularity) ;
    
    % loop through all chambers
    valid = find(calibration.valid_chambers);
    chamber_count = numel(valid);
    % process tracks for all chambers

    % Set the frame range for each chunk
    start_step_limit_from_chunk_index = struct_with_shape_and_fields([1 chunk_count], {'start', 'step', 'limit'}) ;
    for chunk_index = 1:chunk_count ,
        start_step_limit = struct() ;
        start_step_limit.start = options.startframe - 1 + (chunk_index-1) .* options.granularity ;
        start_step_limit.step  = 1 ;
        start_step_limit.limit = min(start_step_limit.start + options.granularity, endframe) ;
        start_step_limit_from_chunk_index(chunk_index) = start_step_limit ;
    end    
    
    % Determine the temp file name for each (chamber, chunk) pair
    atomic_track_file_name_from_chamber_index_from_chunk_index = cell(chamber_count, chunk_count) ;
    for chunk_index = 1:chunk_count ,
        atomic_track_file_name_from_chamber_index = cell(1, chamber_count) ;
        for chamber_index = 1:chamber_count ,
            chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
            % determine output filename
            atomic_track_file_leaf_name = ...
                [track_file_base_name chamber_affix '-trk' '-' num2str(start_step_limit_from_chunk_index(chunk_index).start,'%010d') '.mat'] ;
            atomic_track_file_name = ...
                fullfile(temp_track_folder_path, atomic_track_file_leaf_name) ;
            atomic_track_file_name_from_chamber_index{chamber_index} = atomic_track_file_name ;
            atomic_track_file_name_from_chamber_index_from_chunk_index{chamber_index, chunk_index} = atomic_track_file_name ;
        end
    end
    
    % For each chunk, run the tracker
    if options.num_cores > 1 ,
        did_succeed_from_chunk_index = zeros(1,chunk_count) ;
        parfor chunk_index = 1:chunk_count ,
            % store job parameters
            did_succeed = ...
                tracker_job_process(input_video_file_path, working_background_file_name, calibration, ...
                                    atomic_track_file_name_from_chamber_index_from_chunk_index(:,chunk_index)', ...
                                    start_step_limit_from_chunk_index(chunk_index), ...
                                    options) ;
            did_succeed_from_chunk_index(chunk_index) = did_succeed;
        end
        if ~all(did_succeed_from_chunk_index)
            error('Some chunks failed') ;
        end
    else
        for chunk_index = 1:chunk_count ,
            % store job parameters
            did_succeed = ...
                tracker_job_process(input_video_file_path, working_background_file_name, calibration, ...
                                    atomic_track_file_name_from_chamber_index_from_chunk_index(:,chunk_index)', ...
                                    start_step_limit_from_chunk_index(chunk_index), ...
                                    options) ;
            if ~did_succeed , 
                error('Error while tracking chunk %d', chunk_index) ;
            end
        end
    end

    %
    % For each chamber, combine results for all chunks
    %
    
    % Synthesize file name for each per-chamber track file
    per_chamber_track_file_name_from_chamber_index = cell(1,chamber_count) ;
    for chamber_index=1:chamber_count
        chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
        per_chamber_track_file_name = fullfile(temp_track_folder_path, [track_file_base_name chamber_affix '-track.mat']);        
        per_chamber_track_file_name_from_chamber_index{chamber_index} = per_chamber_track_file_name;
    end    
    
    % Synthesize file name for each per-chamber seg file
    per_chamber_segmentation_file_name_from_chamber_index = cell(1,chamber_count) ;
    for chamber_index=1:chamber_count
        chamber_affix = fif(chamber_count == 1, '', sprintf('-c%d', chamber_index)) ;
        per_chamber_segmentation_file_name = fullfile(temp_track_folder_path, [track_file_base_name chamber_affix '-seg.mat']);        
        per_chamber_segmentation_file_name_from_chamber_index{chamber_index} = per_chamber_segmentation_file_name;
    end    
    
    % For each chamber, do the heavy lifting of combining results for all chunks
    for chamber_index=1:chamber_count
        atomic_track_file_name_from_chunk_index = atomic_track_file_name_from_chamber_index_from_chunk_index(chamber_index,:) ;
        per_chamber_track_file_name = per_chamber_track_file_name_from_chamber_index{chamber_index} ;   
        per_chamber_segmentation_file_name = per_chamber_segmentation_file_name_from_chamber_index{chamber_index} ;
        core_tracker_job_combine(per_chamber_track_file_name, per_chamber_segmentation_file_name, ...
                                 atomic_track_file_name_from_chunk_index, calibration, options) ;
    end
    
    %
    % Finally, combine tracks from chambers
    %
    core_tracker_job_consolidate(output_track_file_path, ...
                                 output_segmentation_file_path, ...
                                 per_chamber_track_file_name_from_chamber_index, ...
                                 per_chamber_segmentation_file_name_from_chamber_index, ...
                                 options) ;    
end
