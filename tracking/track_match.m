
% Match detections between consecutive frames.
%
% To match detections, use:
%
%    trks = track_match(detections, calib, [chamber_str])
%
% where:
%
%    detections        - detections obtained from track_detect
%    calib             - calibration obtained from calibrator or tracker_job_calibrate
%    chamber_str       - indicates which chamber is being processed (default '')
%
% returns:
%
%    trks.             - tracklets (sequences of confidently matched detections)        
%       frame_ids, frame_data, roi - same fields as in detections
%                                    (see track_detect for description)
%       frame_seq_list - list of sequences (objects) in each frame
%       sequences      - cell array containing extracted match sequences:
%          cardinality - cardinality (instantiated fertility) of object
%          time_start  - start time (index into frame_ids)
%          time_end    - end time (index into frame_ids)
%          obj_list    - id of detected object body in each frame between 
%                        time_start and time_end, inclusive
%       flags          - flags detections where a body component was
%                        segmented into more body components (as this may
%                        result in a potential identity swap)
%
function trks = track_match(detections, calib, chamber_str)
   if nargin < 3
       chamber_str = ''; % used to report progress
   end

   % initialize tracks
   trks.frame_ids  = {};
   trks.frame_data = {};
   trks.sequences  = {};
   trks.seq_graph  = [];      

   % get number of frames to process
   n_frames = numel(detections.frame_ids);   
   % check for nonempty input
   if (n_frames == 0), return; end     
   
   % set parameters
   params = calib.params;   
   % store meta data in parameters for convenience
   params.PPM     = calib.PPM;    
   params.FPS     = calib.FPS;
   params.n_flies = calib.n_flies;   
   params.use_default_fert = 0;
   
   % match atomic components
   atomic_matches = compute_atomic_matches(detections, params, 1, chamber_str);      
   if isnumeric(atomic_matches) && ~atomic_matches
       trks = 0; return;
   end

   % extract track sequences
   trks = extract_track_sequences(detections, atomic_matches);

   % update cardinalities to match num_flies
   trks = adjust_cardinalities(trks, atomic_matches, params);

   % revise detections and matches according to tracks cardinality   
   params.use_default_fert = 0;   % max fertility = 1 for all flies   
   detections = revise_detections(trks, atomic_matches, params, chamber_str);         
   if isnumeric(detections) && detections==0
       % user hit cancel during processing
       trks = 0; return;
   end
   
   % re-extract track sequences   
   if ~isnumeric(detections)
       % only if detections were updated
       atomic_matches = compute_atomic_matches(detections, params, 2, chamber_str);               
       if isnumeric(atomic_matches) && ~atomic_matches
           trks = 0; return;
       end
       trks = extract_track_sequences(detections, atomic_matches);
   end

   % split tracks where too many confident tracks coexist
   trks = split_confident_tracks(trks, params);

   % extract flags
   trks.flags = extract_flags(trks);         
end

function flags = extract_flags(tracks)
    flags = zeros(0,4); % sequence1 sequence2 frame ambiguity
    % loop through all frames to see if their detections have flagged bodies
    for i=1:numel(tracks.frame_ids)
        detect = tracks.frame_data{i};
        if ~isfield(detect,'flag_bods'), continue; end
        % find  body to sequence mapping
        seqs = tracks.frame_seq_list{i};            
        bod2seq = zeros(numel(seqs),1);
        for s=1:numel(seqs)            
            t_s = tracks.sequences{seqs(s)}.time_start;
            bod = tracks.sequences{seqs(s)}.obj_list(i-t_s+1);
            bod2seq(bod) = seqs(s);
        end
        % loop through all flagged body pairs
        for f=1:numel(detect.flag_bods)
            bods = detect.flag_bods{f};
            if numel(bods)<2, continue; end
            % set the cost to equal half the distance between their bodies
            pos1 = detect.body_props(bods(1)).Centroid;
            pos2 = detect.body_props(bods(2)).Centroid;
            dist = norm(pos1-pos2);
            % add this pair to the flags
            seq1 = bod2seq(bods(1));
            seq2 = bod2seq(bods(2));
            flags = [flags; seq1 seq2 i dist/2];
        end
    end
end

function tracks = adjust_cardinalities(tracks, atomic_matches, params)
   num_flies = params.n_flies;
   n_seq = numel(tracks.sequences);

   t_ends = zeros(1,n_seq);
   t_starts = zeros(1,n_seq);
   for i=1:n_seq
       t_starts(i) = tracks.sequences{i}.time_start;
       t_ends(i) = tracks.sequences{i}.time_end;
   end
   
   % ensure cardinality consistency between linked sequences   
   dist = zeros(1,n_seq);
   count = zeros(1,n_seq);
   cardis = zeros(1,n_seq);
   cardi_prev = nan(1,n_seq);
   cardi_next = nan(1,n_seq);
   seqs_next = cell(1,n_seq);
   seqs_prev = cell(1,n_seq);
   mean_maxs = zeros(1,n_seq);
   for i=1:n_seq
       seq = tracks.sequences{i};
       cardi = seq.cardinality;       
       t_start = seq.time_start;
       t_end = seq.time_end;      
       frames = t_start:t_end;

       xs = zeros(1,numel(frames));
       ys = zeros(1,numel(frames));
       for f=1:numel(frames)
           o = tracks.sequences{i}.obj_list(f);
           mean_maxs(i) = mean_maxs(i) + atomic_matches{frames(f)}.fert_max(o);           
           pos = tracks.frame_data{frames(f)}.body_props(o).Centroid;
           xs(f) = pos(1);
           ys(f) = pos(2);
       end
       dist(i) = sum((diff(xs).^2 + diff(ys).^2).^2);
       mean_maxs(i) = mean_maxs(i)/f;
       cardis(i) = cardi;          
       count(i) = t_end-t_start+1;           
       % check whether matched bodies in previous frame have higher cardinality
       objs = seq.obj_list;    
       if t_start > 1
           obj_start = objs(1);                       
           % generate cost matrix using look ahead
           % - find all sequences that end right before current seq           
           from_seqs = find(t_ends==t_start-1);
           from_cardis = zeros(size(from_seqs));
           seq_to_obj = zeros(size(from_seqs));
           det_curr = tracks.frame_data{t_start-1};
           for j=1:numel(from_seqs)
               seq_from = tracks.sequences{from_seqs(j)};
               obj = seq_from.obj_list(end);
               % shift detection according to motion
               if numel(seq_from.obj_list) > 1
                   obj_prev = seq_from.obj_list(end-1);
                   dPos = det_curr.body_props(obj).Centroid - ...
                      tracks.frame_data{t_start-2}.body_props(obj_prev).Centroid;
                   det_curr.body_props(obj).Centroid = ...
                       det_curr.body_props(obj).Centroid + dPos/2;
                   [I,J] = ind2sub(det_curr.body_cc.ImageSize,...
                       det_curr.body_cc.PixelIdxList{obj});
                   I = I + round(dPos(2)/2); J = J + round(dPos(1)/2);
                   I = max(1,min(det_curr.body_cc.ImageSize(1),I));
                   J = max(1,min(det_curr.body_cc.ImageSize(2),J));
                   det_curr.body_cc.PixelIdxList{obj} = ...
                       sub2ind_faster(det_curr.body_cc.ImageSize,I,J);                   
               end
               seq_to_obj(j) = obj;
               from_cardis(j) = seq_from.cardinality;
           end           
           det_curr.body_cc.NumObjects = numel(from_seqs);
           det_curr.body_cc.PixelIdxList = det_curr.body_cc.PixelIdxList(seq_to_obj);
           det_curr.body_props = det_curr.body_props(seq_to_obj);
           % - find all sequences that start the same time as current seq
           to_seqs = find(t_starts==t_start);
           to_cardis = zeros(size(to_seqs));
           seq_to_obj = zeros(size(to_seqs));
           det_next = tracks.frame_data{t_start};
           for j=1:numel(to_seqs)
               seq_to = tracks.sequences{to_seqs(j)};
               obj = seq_to.obj_list(1);
               % shift detection according to motion
               if numel(seq_to.obj_list) > 1
                   obj_next = seq_to.obj_list(2);
                   dPos = det_next.body_props(obj).Centroid - ...
                      tracks.frame_data{t_start+1}.body_props(obj_next).Centroid;
                   det_next.body_props(obj).Centroid = ...
                       det_next.body_props(obj).Centroid + dPos/2;
                   [I,J] = ind2sub(det_next.body_cc.ImageSize,...
                       det_next.body_cc.PixelIdxList{obj});
                   I = I + round(dPos(2)/2); J = J + round(dPos(1)/2);
                   I = max(1,min(det_next.body_cc.ImageSize(1),I));
                   J = max(1,min(det_next.body_cc.ImageSize(2),J));
                   det_next.body_cc.PixelIdxList{obj} = ...
                       sub2ind_faster(det_next.body_cc.ImageSize,I,J);                   
               end               
               seq_to_obj(j) = obj;
               to_cardis(j) = seq_to.cardinality;
           end           
           det_next.body_cc.NumObjects = numel(to_seqs);
           det_next.body_cc.PixelIdxList = det_next.body_cc.PixelIdxList(seq_to_obj);
           det_next.body_props = det_next.body_props(seq_to_obj);
           obj_idx = find(seq_to_obj == obj_start);
           % - build cost matrix           
           costmx = detection_match_costs(det_curr,det_next,params.PPM);
           if numel(costmx) > 0
               % greedy matching, every blob gets to match to what it wants
               [~,m_fwd] = min(costmx,[],2);
               [~,m_bwd] = min(costmx,[],1);                              
               prev_match = m_bwd(obj_idx);
               if prev_match==0, prev_match = []; end;
               prev_matches = union(find(m_fwd == obj_idx),prev_match);
               matched_too = find(ismember(m_bwd,prev_matches));
               matched_too = setdiff(matched_too,obj_idx);
               prev_cardi = sum(from_cardis(prev_matches)) - ...
                        sum(to_cardis(matched_too));
               prev_cardi = max(0,prev_cardi);
               cardi_prev(i) = prev_cardi;  
               seqs_prev{i} = from_seqs(prev_matches);
           end
       end
       % check whether matched bodies in next frame have higher cardinality
       if t_end < numel(atomic_matches)
           obj_end = objs(end);          
           % generate cost matrix using look ahead
           % - find all sequences that end the same time as current seq           
           from_seqs = find(t_ends==t_end);
           from_cardis = zeros(size(from_seqs));
           seq_to_obj = zeros(size(from_seqs));
           det_curr = tracks.frame_data{t_end};
           for j=1:numel(from_seqs)
               seq_from = tracks.sequences{from_seqs(j)};
               obj = seq_from.obj_list(end);
               % shift detection according to motion
               if numel(seq_from.obj_list) > 1
                   obj_prev = seq_from.obj_list(end-1);
                   dPos = det_curr.body_props(obj).Centroid - ...
                      tracks.frame_data{t_end-1}.body_props(obj_prev).Centroid;
                   det_curr.body_props(obj).Centroid = ...
                       det_curr.body_props(obj).Centroid + dPos/2;
                   [I,J] = ind2sub(det_curr.body_cc.ImageSize,...
                       det_curr.body_cc.PixelIdxList{obj});
                   I = I + round(dPos(2)/2); J = J + round(dPos(1)/2);
                   I = max(1,min(det_curr.body_cc.ImageSize(1),I));
                   J = max(1,min(det_curr.body_cc.ImageSize(2),J));
                   det_curr.body_cc.PixelIdxList{obj} = ...
                       sub2ind_faster(det_curr.body_cc.ImageSize,I,J);                   
               end
               seq_to_obj(j) = obj;
               from_cardis(j) = seq_from.cardinality;
           end           
           det_curr.body_cc.NumObjects = numel(from_seqs);
           det_curr.body_cc.PixelIdxList = det_curr.body_cc.PixelIdxList(seq_to_obj);
           det_curr.body_props = det_curr.body_props(seq_to_obj);
           obj_idx = find(seq_to_obj == obj_end);
           % - find all sequences that start right after current seq
           to_seqs = find(t_starts==t_end+1);
           to_cardis = zeros(size(to_seqs));
           seq_to_obj = zeros(size(to_seqs));
           det_next = tracks.frame_data{t_end+1};
           for j=1:numel(to_seqs)
               seq_to = tracks.sequences{to_seqs(j)};
               obj = seq_to.obj_list(1);
               % shift detection according to motion
               if numel(seq_to.obj_list) > 1
                   obj_next = seq_to.obj_list(2);
                   dPos = det_next.body_props(obj).Centroid - ...
                      tracks.frame_data{t_end+2}.body_props(obj_next).Centroid;
                   det_next.body_props(obj).Centroid = ...
                       det_next.body_props(obj).Centroid + dPos/2;
                   [I,J] = ind2sub(det_next.body_cc.ImageSize,...
                       det_next.body_cc.PixelIdxList{obj});
                   I = I + round(dPos(2)/2); J = J + round(dPos(1)/2);
                   I = max(1,min(det_next.body_cc.ImageSize(1),I));
                   J = max(1,min(det_next.body_cc.ImageSize(2),J));
                   det_next.body_cc.PixelIdxList{obj} = ...
                       sub2ind_faster(det_next.body_cc.ImageSize,I,J);                   
               end               
               seq_to_obj(j) = obj;
               to_cardis(j) = seq_to.cardinality;
           end           
           det_next.body_cc.NumObjects = numel(to_seqs);
           det_next.body_cc.PixelIdxList = det_next.body_cc.PixelIdxList(seq_to_obj);
           det_next.body_props = det_next.body_props(seq_to_obj);
           % - build cost matrix           
           costmx = detection_match_costs(det_curr,det_next,params.PPM);           
           if numel(costmx) > 0
               % greedy matching, every blob gets to match to what it wants
               [~,m_fwd] = min(costmx,[],2);
               [~,m_bwd] = min(costmx,[],1);               
               next_match = m_fwd(obj_idx);
               if next_match==0, next_match = []; end;
               next_matches = union(find(m_bwd == obj_idx),next_match);
               matched_too = find(ismember(m_fwd,next_matches));
               matched_too = setdiff(matched_too,obj_idx);
               next_cardi = sum(to_cardis(next_matches)) - ...
                        sum(from_cardis(matched_too));
               next_cardi = max(0,next_cardi);
               cardi_next(i) = next_cardi;  
               seqs_next{i} = to_seqs(next_matches);
           end
       end
    end
   
    cardi_mismatch = find(abs(mean_maxs-cardis) > .1);
    resolved = zeros(1,n_seq);
    for i=1:numel(cardi_mismatch)
        seq_id = cardi_mismatch(i);
        % adjust 0 cardinalities that have sufficient atomic support
        if cardis(seq_id) == 0
            seq = tracks.sequences{seq_id};
            frames = seq.time_start:seq.time_end;
            atomic = 0;
            for f=frames
                obj = seq.obj_list(f-seq.time_start+1);
                is_atomic = is_atomic_detection(tracks.frame_data{f},params);
                atomic = atomic+is_atomic(obj);
            end
            if atomic/numel(frames) > .5
                tracks.sequences{seq_id}.cardinality = 1;
                resolved(seq_id) = 1;
                cardis(seq_id) = 1;
            end
        end
    end    
    % set cardinality of blurry sequences to be 1 (flying or on ceiling)
    for seq_id=1:numel(cardis)
        seq = tracks.sequences{seq_id};
        frames = seq.time_start:seq.time_end;
        contrast = 0;
        for f=1:numel(frames)
            obj = seq.obj_list(f);
            det = tracks.frame_data{frames(f)};
            contrast = contrast + det.body_contrast(obj);
        end
        contrast = contrast/numel(frames);
        if contrast < params.contrast_th
            tracks.sequences{seq_id}.cardinality = 1;
            resolved(seq_id) = 1;
            cardis(seq_id) = 1;            
        end
    end    
    cardi_mismatch = setdiff(cardi_mismatch,find(resolved));

    % find confident sequences
    [votes_for,count_valid_flies] = compute_track_votes(tracks,cardis,num_flies);  
    
    do_fix = find((cardis ~= cardi_prev & ~isnan(cardi_prev) & cardi_prev>0) | ...
                  (cardis ~= cardi_next & ~isnan(cardi_next) & cardi_next>0));
    do_fix = union(do_fix,cardi_mismatch);   
    new_cardis = cardis;
    old_cardis = cardis;
    while true
        resolved = false(size(do_fix));
        for s=1:numel(do_fix)
            seq_id = do_fix(s);
            prev = seqs_prev{seq_id};
            next = seqs_next{seq_id};
            prev_cardi = cardi_prev(seq_id);
            next_cardi = cardi_next(seq_id);

            % if sequence connects to nothing, make cardinality correspond 
            %  to capacity, as long as
            % - we're not overestimating the total number of flies
            % - contrast is not too low (flying or walking on ceiling)  
            if isnan(prev_cardi) && isnan(next_cardi) && ...
                  mean_maxs(seq_id)-cardis(seq_id) > .5 && count(seq_id) > 10
                t_start = tracks.sequences{seq_id}.time_start;
                t_end = tracks.sequences{seq_id}.time_end; 
                new_cardi = round(mean_maxs(seq_id));
                new_valid = count_valid_flies(t_start:t_end)+new_cardi-cardis(seq_id);
                too_many = new_valid > num_flies;   
                contrast = 0;
                frames = t_start:t_end;
                for f=1:numel(frames)
                    obj_id = tracks.sequences{seq_id}.obj_list(f);
                    det = tracks.frame_data{frames(f)};
                    contrast = contrast + det.body_contrast(obj_id);
                end
                contrast = contrast/numel(frames);
                if sum(too_many)/numel(too_many) < .1 && ...
                      contrast > params.contrast_th;
                    new_cardis(seq_id) = new_cardi;
                    count_valid_flies(t_start:t_end) = new_valid;
                end
                resolved(s) = 1;

            % if neither disagrees, keep cardinality as is
            elseif (isnan(prev_cardi) || prev_cardi == cardis(seq_id)) && ...
               (isnan(next_cardi) || next_cardi == cardis(seq_id))            
                % do nothing
                resolved(s) = 1;

            % if either disagrees, check which one is most reliable
            else
                if sum(ismember(prev,do_fix))>0
                    prev_cardi = nan;
                    prev = [];               
                end
                if sum(ismember(next,do_fix))>0
                    next_cardi = nan;
                    next = [];
                end                
                if ~isnan(prev_cardi) || ~isnan(next_cardi)                
                    votes = [min(votes_for(prev)) min(votes_for(next)) votes_for(seq_id)];
                    counts = [min(count(prev)) min(count(next)) count(seq_id)];
                    ferts = [prev_cardi next_cardi cardis(seq_id)]; ferts = ferts(~isnan(ferts));
                    [max_vote,max_idx] = max(votes);
                    if (isnan(prev_cardi) || prev_cardi == round(mean_maxs(seq_id))) && ...
                       (isnan(next_cardi) || next_cardi == round(mean_maxs(seq_id)))
                        % use agreement of both surrounding sequences and max fertility                        
                        new_cardis(seq_id) = round(mean_maxs(seq_id));
                    elseif max_vote > 0 
                        % use most reliable sequence
                        new_cardis(seq_id) = ferts(max_idx);
                    elseif any(counts-nanmean(counts) > 0) 
                        % use longest sequence
                        [~,max_idx] = max(counts);
                        new_cardis(seq_id) = ferts(max_idx);
                    end  
                    resolved(s) = 1;
                end
            end
            % make sure we do not delete anything
            if new_cardis(seq_id) < cardis(seq_id)
                new_cardis(seq_id) = min(max(1,new_cardis(seq_id)),num_flies);                                
            end
            % make sure we do not double up cardis where the fly moves
            % around a lot
            if new_cardis(seq_id) > cardis(seq_id)
                if dist(seq_id) > params.PPM*10 && ...      % 5 fly body lengths
                        round(mean_maxs(seq_id)) == 1       % mean body size small
                    new_cardis(seq_id) = cardis(seq_id);
                end
            end
        end
        do_fix_old = do_fix;
        do_fix = do_fix(~resolved);        
        if numel(do_fix)==numel(do_fix_old) || numel(do_fix)==0
            break;
        end
        % update prev_cardi and next_cardi 
        for s=1:numel(cardis)            
            seq_id = s;
            prev_cardi = cardi_prev(seq_id);            
            prev = seqs_prev{seq_id};
            for p=1:numel(prev)
                prev_cardi = prev_cardi - cardis(prev(p)) + new_cardis(prev(p));
            end
            cardi_prev(seq_id) = prev_cardi;
            next_cardi = cardi_next(seq_id);            
            next = seqs_next{seq_id};
            for n=1:numel(next)
                next_cardi = next_cardi - cardis(next(n)) + new_cardis(next(n));
            end
            cardi_next(seq_id) = next_cardi;
        end
        cardis = new_cardis;
        
        % find confident sequences
        [votes_for,count_valid_flies] = compute_track_votes(tracks,cardis,num_flies);  
    end
    updates = find(old_cardis~=new_cardis);
    for i=1:numel(updates)
        seq_id = updates(i);
        tracks.sequences{seq_id}.cardinality = new_cardis(seq_id);
    end   
end

function tracks = split_confident_tracks(tracks, params)
    num_flies = params.n_flies;
    n_frames = numel(tracks.frame_ids);         
    n_seq = numel(tracks.sequences);
    cardis = ones(1,n_seq);  
    % find confident sequences
    votes_for = compute_track_votes(tracks,cardis,num_flies);
    % split trajectories where too many confident tracks exist
    count_conf = zeros(1,n_frames);
    conf_seq = find(votes_for>0);
    starts = zeros(1,numel(conf_seq));
    ends = zeros(1,numel(conf_seq));
    for i=1:numel(conf_seq)
        seq_id = conf_seq(i);
        seq = tracks.sequences{seq_id};
        starts(i) = seq.time_start;
        ends(i) = seq.time_end;
        count_conf(starts(i):ends(i)) = count_conf(starts(i):ends(i)) + 1;
    end
    too_many = count_conf > num_flies;
    cc = bwconncomp(too_many);
    for c=1:cc.NumObjects
        frames = cc.PixelIdxList{c};
        % split sequences that start on interval
        update_starts = find(starts==frames(1));                
        for u=1:numel(update_starts)
            seq_id = conf_seq(update_starts(u));
            seq = tracks.sequences{seq_id};
            % make a new sequence that spans this gap
            new_seq = seq;
            new_seq.time_end = frames(end);
            new_seq.obj_list = seq.obj_list(1:numel(frames));
            % change current sequence to start later
            seq.time_start = frames(end)+1;
            seq.obj_list = seq.obj_list(numel(frames)+1:end);
            % update sequences
            tracks.sequences{seq_id} = seq;
            tracks.sequences{end+1} = new_seq;
            % update frame sequence list
            for i=1:numel(frames)
                f = frames(i);
                tracks.frame_seq_list{f} = setdiff(tracks.frame_seq_list{f},seq_id);
                tracks.frame_seq_list{f} = union(tracks.frame_seq_list{f},numel(tracks.sequences));
            end
        end
        % split sequences that end on interval
        update_ends = find(ends==frames(end));
        for u=1:numel(update_ends)
            seq_id = conf_seq(update_ends(u));
            seq = tracks.sequences{seq_id};
            % make a new sequence that spans this gap
            new_seq = seq;
            new_seq.time_start = frames(1);
            new_seq.obj_list = seq.obj_list(end-numel(frames)+1:end);
            % change current sequence to start later
            seq.time_end = seq.time_end-numel(frames);
            seq.obj_list = seq.obj_list(1:end-numel(frames));
            % update sequences
            tracks.sequences{seq_id} = seq;
            tracks.sequences{end+1} = new_seq;
            % update frame sequence list
            for i=1:numel(frames)
                f = frames(i);
                tracks.frame_seq_list{f} = setdiff(tracks.frame_seq_list{f},seq_id);
                tracks.frame_seq_list{f} = union(tracks.frame_seq_list{f},numel(tracks.sequences));
            end
        end
    end
end

function [votes_for, count_valid_flies, votes_against] = compute_track_votes(tracks, cardis, num_flies)
    n_frames = numel(tracks.frame_ids);    
    % - vote for sequences that exist as equal number of flies
    votes_for = zeros(size(tracks.sequences));
    count_valid_flies = zeros(1,n_frames);
    for i=1:n_frames
       seqs = tracks.frame_seq_list{i};
       if numel(seqs) == num_flies && sum(cardis(seqs)) == num_flies
           votes_for(seqs) = votes_for(seqs)+1;           
           count_valid_flies(i) = numel(seqs);
       end       
    end
    % - vote against additional sequences that coexist with those sequences
    votes_against = zeros(size(tracks.sequences));
    for i=1:n_frames
       seqs = tracks.frame_seq_list{i};
       count_valid = 0;
       for s=1:numel(seqs)
           if tracks.sequences{seqs(s)}.cardinality > 0
              count_valid = count_valid + 1;
           end
       end
       if count_valid > num_flies
           votes = votes_for(seqs);
           if any(votes)
               [~,sort_ids] = sort(votes,'descend');
               votes_against(seqs(sort_ids(num_flies+1:end))) = votes_against(sort_ids(num_flies+1:end)) + 1;
           end
       end
    end         
end

function [dets, matches] = revise_detections(tracks, matches, params, chamber_str)
    if nargin < 4
        chamber_str = '';
    end
    n_seq = numel(tracks.sequences);
    n_frames = numel(tracks.frame_ids);
    % find frames that are invalid (due to shadow)
    total_area = zeros(1,n_frames);
    for i=1:n_frames
        total_area(i) = sum([tracks.frame_data{i}.body_props.Area]);
    end
    invalid = total_area > prctile(total_area,90)*2;
    % collect the cardinality of all sequences
    cardinalities = zeros(1,n_seq);
    n_mod_frames = 0;
    for i = 1:n_seq
        cardinalities(i) = tracks.sequences{i}.cardinality;
        if cardinalities(i) > 1
            n_mod_frames = n_mod_frames + numel(tracks.sequences{i}.obj_list);
        end
    end 
    assert(sum(cardinalities==0)==0) % by now all sequences should have >= 1 cardi
    % find trajectories with >1 cardinality
    inds = find(cardinalities > 1);     
    if numel(inds) == 0
        % no fixes to be made
        dets = 1; return; 
    end
    show_progress = n_mod_frames > 100;
    if show_progress
        % set waitbar
        display_available = feature('ShowFigureWindows');
        waitstr = 'Revising detections';
        waitstr = [chamber_str waitstr ': frames ' num2str(tracks.frame_ids(1)) ...
                               '-' num2str(tracks.frame_ids(end)+1)];    
        waitstep = max(1,floor(n_mod_frames/100));                   
        if display_available        
            multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
            waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));   
        else
            percent = 0;
            fprintf(1,[waitstr ': %d%%'], percent); 
        end              
        count = 0;
    end    
    for i = inds              
        n_bods = cardinalities(i);
        n_bods = min(n_bods,params.n_flies);
        t_start = tracks.sequences{i}.time_start;
        t_end = tracks.sequences{i}.time_end;
        for t = t_start:t_end            
            obj_id = tracks.sequences{i}.obj_list(t-t_start+1);
            detect = tracks.frame_data{t};            
            if invalid(t)
                detect_new = detect;
                detect_new.fg_cc.NumObjects = 0;
                detect_new.fg_cc.PixelIdxList = {};
                detect_new.fg_props = regionprops(detect_new.fg_cc);
                detect_new.body_cc.NumObjects = 0;
                detect_new.body_cc.PixelIdxList = {};
                detect_new.body_props = regionprops(detect_new.body_cc);
                detect_new.body_fg = [];
                detect_new.fg_body = {};
                detect_new.body_contrast = [];
                bod_ids = [];
                continue
            end                        
            % split detection into multiple bodies
            if t>1
                %detect_prev = dets.frame_data{t-1};
                detect_prev = tracks.frame_data{t-1};
                if t == t_start
                    prev_ids = find(matches{t-1}.m_next==obj_id);
                else
                    prev_ids = bod_ids;
                end
                [detect_new,bod_ids] = split_bodies(detect,params,n_bods,obj_id,detect_prev,prev_ids);
            else
                [detect_new,bod_ids] = split_bodies(detect,params,n_bods,obj_id);
            end
            tracks.frame_data{t} = detect_new;    
            if show_progress
                % update waitbar
                count = count+1;            
                if display_available && mod(count,waitstep) == 0
                   abort = multiWaitbar(waitstr,count/n_mod_frames);
                   if abort, dets = 0; return; end
                elseif mod(count,waitstep) == 0
                   for d=1:numel(num2str(percent))+1
                      fprintf(1,'\b');
                   end
                   percent = round(count/n_mod_frames*100);
                   fprintf(1,'%d%%',percent);                    
                end    
            end
        end
        % update matches
        t_s = max(1,t_start-1);
        t_e = min(n_frames,t_end+1);
        buff_s = t_s > 1;
        buff_e = t_e < n_frames;
        tmp_dets.frame_data = tracks.frame_data(t_s-buff_s:t_e+buff_e);
        tmp_dets.frame_ids = t_s-buff_s:t_e+buff_e;
        matches_new =  compute_atomic_matches(tmp_dets,params,0);
        matches(t_s:t_e) = matches_new(1+buff_s:end-buff_e);        
    end
    if show_progress
        % close waitbar
        if display_available
           multiWaitbar(waitstr,'Close');
           drawnow
        else
           for d=1:numel(num2str(percent))+1
              fprintf(1,'\b');
           end
           percent = 100;
           fprintf(1,'%d%% \n',percent);               
        end      
    end
    dets.frame_ids = tracks.frame_ids;
    dets.frame_data = tracks.frame_data;
    dets.roi = tracks.roi;  
end

function [detect_new,bod_ids] = split_bodies(detect,params,n_bods,obj_id,detect_prev,prev_ids)
    % initialize new detection to be the same
    detect_new = detect;
    % find bbox surrounding all body objects that are close to each other
    body_cc = detect.body_cc;
    pixels = body_cc.PixelIdxList{obj_id};
    img = zeros(body_cc.ImageSize);
    img(pixels) = 1; 
    [I,J] = ind2sub(body_cc.ImageSize,pixels);
    X = [J(:) I(:)];
    
    minor_axis = detect.body_props(obj_id).MinorAxisLength;
    try_gmm = minor_axis > params.max_minor_axis*1.2;
    
    cc = bwconncomp(img);
    solved = 0;
    if cc.NumObjects == n_bods
        props = regionprops(cc, params.r_props);
        if max([props.Area]) < params.max_area && ...
           max([props.MajorAxisLength]) < params.max_major_axis && ...
           max([props.MinorAxisLength]) < params.max_minor_axis        
            clusters = cell(1,n_bods);
            for i=1:n_bods
                clusters{i} = cc.PixelIdxList{i};            
            end
            try_gmm = 0;
            solved = 1;
        end
    end
    
    if try_gmm
        success = 0;
        try
        warning off 
        options = statset('Display','off','TolFun',1*10^-8,'MaxIter',1000);
        use_random_start = 1;           
        if nargin > 4 && numel(prev_ids) == n_bods
            % check whether previous detection is close enough to current
            % prediction to initialize the gaussian fitting
            img_prev = zeros(size(img));
            for i=1:numel(prev_ids)
                id = prev_ids(i);
                img_prev(detect_prev.body_cc.PixelIdxList{id}) = 1;
            end
            percent_diff = sum(img(:)~=img_prev(:))/sum(img(:));
            if percent_diff < .3
                use_random_start = 0;
                S.mu = zeros(n_bods,2);
                S.Sigma = zeros(2,2,n_bods);
                for i=1:numel(prev_ids)
                    id = prev_ids(i);
                    S.mu(i,:) = detect_prev.body_props(id).Centroid;
                    ori = detect_prev.body_props(id).Orientation/180*pi;
                    V = [cos(ori) sin(ori); -sin(ori) cos(ori)];
                    major_axis = (detect_prev.body_props(id).MajorAxisLength);
                    minor_axis = (detect_prev.body_props(id).MinorAxisLength);
                    major_axis = major_axis^2/(major_axis+minor_axis);
                    minor_axis = minor_axis^2/(major_axis+minor_axis);
                    D = [major_axis 0; 0 minor_axis];
                    S.Sigma(:,:,i) = V*D/V;
                end
                S.PComponents = ones(n_bods,1)/n_bods;
                gm = gmdistribution.fit(X,n_bods,'Options',options,'Replicates',1,'Start',S);
                success = (gm.Converged && gm.NComponents == n_bods);
            end
        end
        if use_random_start || ~success
            gm = gmdistribution.fit(X,n_bods,'Options',options,'Replicates',10);
            success = (gm.Converged && gm.NComponents == n_bods);
        end
        warning on
        catch
            % do nothing
            warning on
        end
    end
    
    if try_gmm && success  %% split bodies according to gmm        
        P = posterior(gm,X);
        clusters = cell(1,n_bods);
        [~,maxinds] = max(P,[],2);
        for i=1:n_bods
            %clusters{i} = P(:,i)>.3;
            clusters{i} = pixels(maxinds==i);
            % make sure that each cluster has at least one pixel
            if numel(clusters{i}) == 0
                [~,idx] = max(P(:,i));
                clusters{i} = pixels(idx);
            end
        end        
    elseif ~solved %% split bodies evenly along the major axis       
        % rotate X along body orientation
        rho = detect.body_props(obj_id).Orientation / 180*pi;
        rotmat = [cos(rho) sin(rho); -sin(rho) cos(rho)];
        X(:,1) = X(:,1)-detect.body_props(obj_id).Centroid(1);
        X(:,2) = X(:,2)-detect.body_props(obj_id).Centroid(2);
        X = X*rotmat;
        X(:,1) = X(:,1)+detect.body_props(obj_id).Centroid(1);
        X(:,2) = X(:,2)+detect.body_props(obj_id).Centroid(2);
        % split pixels into bodies along the x-axis (which is now the major
        % axis of the blob)
        min_x = min(X(:,1));
        max_x = max(X(:,1));
        chunk = (max_x-min_x+1)/n_bods;
        clusters = cell(1,n_bods);
        for i=1:n_bods
            left_cands = find(X(:,1)-min_x+1 <= i*chunk);
            right_cands = find(X(:,1)-min_x+1 > (i-1)*chunk);
            clusters{i} = pixels(intersect(left_cands,right_cands));
            % make sure that each cluster has at least one pixel
            if numel(clusters{i}) == 0
                idx = abs(X(:,1)-min_x+1 - i*chunk) < 1;
                clusters{i} = pixels(idx);
            end
        end
    end
    % update detect properties according to the split body
    body_cc.PixelIdxList{obj_id} = clusters{1};
    for i=2:n_bods
        body_cc.PixelIdxList{end+1} = clusters{i};
    end     
    body_cc.NumObjects = body_cc.NumObjects+n_bods-1;
    detect_new.body_cc = body_cc;
    detect_new.body_props = regionprops(body_cc, params.r_props);
    fg_id = detect.body_fg(obj_id);
    detect_new.body_fg(end+(1:n_bods-1)) = fg_id;
    detect_new.fg_body{fg_id} = union(detect_new.fg_body{fg_id}, ...
                               detect.body_cc.NumObjects+(1:n_bods-1));
    detect_new.body_contrast(end+(1:n_bods-1)) = ...
                               detect.body_contrast(obj_id);    
    % return ids of newly created bodies
    bod_ids = [obj_id body_cc.NumObjects-n_bods+2:body_cc.NumObjects]; 
    
    % flag bodies that have been split from a single component that fits
    %  single fly constraints
    major_axis = detect.body_props(obj_id).MajorAxisLength;
    if major_axis < params.max_major_axis 
        if ~isfield(detect_new,'flag_bods')
            detect_new.flag_bods{1} = bod_ids;
        else
            detect_new.flag_bods{end+1} = bod_ids;
        end
    end
end

% Compute matches between atomic detections.
%
%    [matches flag] = compute_atomic_matches(detections, params)
%
% where: 
%
%    detections   - detections
%    params       - parameters for matching
%
% returns:
%
%    matches      - cell array of matches between consecutive frames
%       m_prev    - mapping of current to previous frame detections
%       m_next    - mapping of current to next frame detections
%       fert_max  - maximum fertility of detections in current frame
%       fert_used - used fertility of detections in current frame
%
function matches = compute_atomic_matches(detections, params, caller_id, chamber_str)
   % initialize matching data structure
   n_frames = numel(detections.frame_ids);
   matches = cell([n_frames 1]);   
   if nargin < 3
       caller_id = 1;
   end
   show_progress = caller_id > 0;
   if nargin < 4
       chamber_str = '';
   end
   % initialize fertility
   fert_max_curr = [];
   fert_max_next = [];
   if (n_frames > 0)
      det_curr = detections.frame_data{1};
      if ~params.use_default_fert
        fert_max_curr = detection_fertility(det_curr,params);
      end
      matches{1}.fert_max  = fert_max_curr;
      matches{1}.fert_used = zeros(size(fert_max_curr));
   end
   % set waitbar
   if show_progress
       display_available = feature('ShowFigureWindows');
       if caller_id == 1
        waitstr = 'Computing matches';
       else
        waitstr = 'Re-computing matches';   
       end
       waitstr = [chamber_str waitstr ': frames ' num2str(detections.frame_ids(1)) ...
                       '-' num2str(detections.frame_ids(end)+1)];
       waitstep = max(1,floor(n_frames/100));            
       if display_available
           multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
           waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
       else
           percent = 0;
           fprintf(1,[waitstr ': %d%%'], percent); 
       end     
   end
   % compute matches
   for f = 1:(n_frames-1) 
      % update waitbar
      if show_progress
          if display_available && mod(f,waitstep) == 0
              abort = multiWaitbar(waitstr,f/(n_frames-1));
              if abort, matches = 0; return; end
          elseif mod(f,waitstep) == 0
              for d=1:numel(num2str(percent))+1
                  fprintf(1,'\b');
              end
              percent = round(f/(n_frames-1)*100);
              fprintf(1,'%d%%',percent);                  
          end           
      end
      % get next set of detections, compute fertilities
      det_next = detections.frame_data{f+1};
      if ~params.use_default_fert
        fert_max_next = detection_fertility(det_next,params);
      end
      % compute match costs
      cost_mx = detection_match_costs(det_curr, det_next, params.PPM);
      % perform matching
      [m_forward, m_backward] = match( ...
         cost_mx, params.match_cost_th, params.min_cost_mat_diff, ...
         fert_max_curr, fert_max_next);
      % store cost difference (to determine sketchy matches)
      matches{f+1}.costmat = cost_mx;
      % store matches
      matches{f}.m_next   = m_forward;
      matches{f+1}.m_prev = m_backward;
      % store fertility
      matches{f+1}.fert_max  = fert_max_next;
      matches{f+1}.fert_used = zeros(size(fert_max_next));
      % get number of detections
      n_curr = det_curr.body_cc.NumObjects;
      n_next = det_next.body_cc.NumObjects;
      % update used fertility - current frame
      used_curr = zeros([n_curr 1]);
      inds = find(reshape(m_backward,[1 numel(m_backward)]));
      for i = inds
         b = m_backward(i);         
         used_curr(b) = used_curr(b) + 1;
      end
      matches{f}.fert_used = max(matches{f}.fert_used, used_curr);
      % update used fertility - next frame
      used_next = zeros([n_next 1]);
      inds = find(reshape(m_forward,[1 numel(m_forward)]));
      for i = inds
         b = m_forward(i);
         used_next(b) = used_next(b) + 1;
      end
      matches{f+1}.fert_used = max(matches{f+1}.fert_used, used_next);
      % increment timestep
      det_curr = det_next;
      if ~params.use_default_fert
        fert_max_curr = fert_max_next;
      end
   end
   % propagate fertility - forward pass
   for f = 2:(n_frames)
      % get matches
      matches_prev = matches{f-1};
      matches_curr = matches{f};
      % update fertility
      fert = propagate_fertility(matches_prev, matches_curr);
      matches{f}.fert_used = min(matches{f}.fert_max, fert);
   end
   % propagate fertility - backward pass
   for f = (n_frames-1):-1:1
      % get matches
      matches_next = matches{f+1};
      matches_curr = matches{f};
      % switch directions
      matches_next.m_next = matches_next.m_prev;
      matches_curr.m_prev = matches_curr.m_next;
      % update fertility
      fert = propagate_fertility(matches_next, matches_curr);
      matches{f}.fert_used = min(matches{f}.fert_max, fert);
   end
   % make sure that detections that are unmatched have fertility > 0 
   for f=1:n_frames
       matches{f}.fert_used = max(matches{f}.fert_used,1);
   end   
   % close waitbar
   if show_progress
      if display_available
          multiWaitbar(waitstr,'Close');
      else
          for d=1:numel(num2str(percent))+1
             fprintf(1,'\b');
          end
          percent = 100;
          fprintf(1,'%d%% \n',percent);               
      end   
   end     
end

% Propagate fertility along chains of one-to-one matches.
%
%    [fertility] = propagate_fertility( ...
%                     det_prev, det_curr, matches_prev, matches_curr)
% 
% where:
%
%    det_prev     - detections in previous frame
%    det_curr     - detections in current frame
%    matches_prev - match data for previous frame
%    matches_curr - match data for current frame
%
% returns:
%
%    fertility    - updated fertility for current frame
%
function fertility = propagate_fertility(matches_prev, matches_curr)
   % get number of objects 
   n_curr = numel(matches_curr.fert_used);
   % get matches
   m_prev_curr = matches_prev.m_next;
   % compute incoming fertility for one-to-one matches
   fert_prev = matches_prev.fert_used;
   fert_inc = zeros([n_curr 1]);
   for i=1:n_curr
       bs = m_prev_curr==i;
       fert_inc(i) = sum(fert_prev(bs));
   end
   % update fertility
   fertility = max(matches_curr.fert_used, fert_inc);
end

% Determine the number of incoming matches for items in corresponding frames.
%
%    [inc_prev inc_curr] = count_matches(m_forward, m_backward)
%
% where:
%
%    m_forward  - mapping of previous items to current
%    m_backward - mapping of current items to previous
%
% returns:
%
%    inc_prev - count of incoming links to previous items
%    inc_curr - count of incoming links to current items
%
function [inc_prev, inc_curr] = count_matches(m_forward, m_backward)
   % count usage - previous
   n_prev = numel(m_forward);
   inc_prev = zeros([n_prev 1]);
   inds = find(reshape(m_backward,[1 numel(m_backward)]));
   for i = inds
      b = m_backward(i);
      inc_prev(b) = inc_prev(b) + 1;
   end
   % count usage - current
   n_curr = numel(m_backward);
   inc_curr = zeros([n_curr 1]);
   inds = find(reshape(m_forward,[1 numel(m_forward)]));
   for i = inds
      b = m_forward(i);
      inc_curr(b) = inc_curr(b) + 1;
   end
end

% Extract track sequences and the graph connecting them.
%
%    [tracks flag] = ...
%       extract_track_sequences(detections, atomic_matches)
%
% where:
%
%    detections - detections
%    matches    - matches between detections
%
% returns:
%
%    tracks     - structure containing input detections along with 
%                 sequences (chains of single detection matches) and a
%                 graph connecting sequences (links are possible matches)
%
function tracks = extract_track_sequences(tracks, matches)
   % initialize number of objects
   n_frames = numel(tracks.frame_ids);
   if (n_frames > 0)
      n_objects = tracks.frame_data{1}.body_cc.NumObjects;
   else
      n_objects = 0;
   end
   % count number of objects
   frames_complete = 0;
   for f = 2:n_frames
      % get matching
      m_forward  = matches{f-1}.m_next;
      m_backward = matches{f}.m_prev;
      [inc_prev, inc_curr] = count_matches(m_forward, m_backward);
      % get fertility
      fert_prev = matches{f-1}.fert_used;
      fert_curr = matches{f}.fert_used;
      % check for new objects (not one-to-one linked to existing track)
      for o = 1:numel(m_backward)
         o_prev = m_backward(o);
         if ((inc_curr(o) ~= 1) || (inc_prev(o_prev) ~= 1) || ...
               (fert_prev(o_prev) ~= fert_curr(o)))
            % record as new object
            n_objects = n_objects + 1;
         end
      end
      frames_complete = frames_complete + 1;
   end
   % initialize list of objects in each frame
   tracks.frame_seq_list = cell([n_frames 1]);
   % allocate sequence array
   tracks.sequences = cell([n_objects 1]);
   for n = 1:n_objects
      tracks.sequences{n}.cardinality = [];
      tracks.sequences{n}.time_start  = [];
      tracks.sequences{n}.time_end    = [];
      tracks.sequences{n}.obj_list    = [];
   end
   % initialize active sequences
   if (n_frames > 0) 
      % get detections in first frame
      n_obj_curr = tracks.frame_data{1}.body_cc.NumObjects;
      tracks.frame_seq_list{1} = 1:n_obj_curr;
      % allocate tracks for these detections
      for o = 1:n_obj_curr
         tracks.sequences{o}.cardinality = matches{1}.fert_used(o);
         tracks.sequences{o}.time_start = 1;
         tracks.sequences{o}.obj_list = zeros([n_frames 1]);
         tracks.sequences{o}.obj_list(1) = o;
      end
   end
   % initialize next sequence id
   seq_id_new = numel(tracks.frame_seq_list{1}) + 1;
   % extract sequences
   frames_complete = 1;
   for f = 2:n_frames 
      % get matching
      m_forward  = matches{f-1}.m_next;
      m_backward = matches{f}.m_prev;
      [inc_prev, inc_curr] = count_matches(m_forward, m_backward);
      % get fertility
      fert_prev = matches{f-1}.fert_used;
      fert_curr = matches{f}.fert_used;
      % get sequeunces corresponding to objects in previous frame
      seq_list = tracks.frame_seq_list{f-1};
      % process current objects
      if numel(fert_prev) == 0 && numel(fert_curr) > 0
         % object is start of new sequence
         for o=1:tracks.frame_data{f}.body_cc.NumObjects
             tracks.sequences{seq_id_new}.cardinality = fert_curr(o);
             tracks.sequences{seq_id_new}.time_start = f;
             tracks.sequences{seq_id_new}.obj_list = zeros([n_frames 1]);
             tracks.sequences{seq_id_new}.obj_list(f) = o;
             tracks.frame_seq_list{f} = [tracks.frame_seq_list{f} seq_id_new];
             seq_id_new = seq_id_new + 1;
         end
      else
         for o = 1:numel(m_backward)
            o_prev = m_backward(o);
            if ((inc_curr(o) ~= 1) || (inc_prev(o_prev) ~= 1) || ...
                      (fert_prev(o_prev) ~= fert_curr(o)))
               % object is start of new sequeunce
               tracks.sequences{seq_id_new}.cardinality = fert_curr(o);
               tracks.sequences{seq_id_new}.time_start = f;
               tracks.sequences{seq_id_new}.obj_list = zeros([n_frames 1]);
               tracks.sequences{seq_id_new}.obj_list(f) = o;
               tracks.frame_seq_list{f} = [tracks.frame_seq_list{f} seq_id_new];
               seq_id_new = seq_id_new + 1;
            else
               % object is continuation of previous sequeunce
               seq_id = seq_list(o_prev);
               tracks.sequences{seq_id}.obj_list(f) = o;
               tracks.frame_seq_list{f} = [tracks.frame_seq_list{f} seq_id];
            end
         end
     end
     % terminate uncontinued sequeuces
     seq_list_curr = tracks.frame_seq_list{f};
     seq_closed = setdiff(seq_list, seq_list_curr);
     for s = 1:numel(seq_closed)
        seq_id = seq_closed(s);
        tracks.sequences{seq_id}.time_end = f-1;
        tracks.sequences{seq_id}.obj_list = ...
           tracks.sequences{seq_id}.obj_list( ...
              (tracks.sequences{seq_id}.time_start):(f-1));
     end
     frames_complete = frames_complete + 1;
   end
   % terminate active sequences
   seq_closed = tracks.frame_seq_list{n_frames};
   for s = 1:numel(seq_closed)
      seq_id = seq_closed(s);
      tracks.sequences{seq_id}.time_end = f;
      tracks.sequences{seq_id}.obj_list = ...
         tracks.sequences{seq_id}.obj_list( ...
            (tracks.sequences{seq_id}.time_start):(f));
   end
end
