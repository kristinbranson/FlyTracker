
% Link tracklets (sequences) to form continuous trajectories (no more than 
% the expected number of flies indicated in calib)
%
% To link tracklets, use:
%
%   trks = track_segment(trks, calib)
%
% where:
%
%    trks              - tracklets obtained from track_segment
%    calib             - calibration obtained from calibrator or tracker_job_calibrate
%
% returns:
%
%    trks.               - same as the input but with the following changes:
%         sequences      - stitched sequences into full trajectories
%         frame_seq_list - updated to reflect sequences
%         flags          - contains all potential identity swaps that may
%                          have resulted in stitching together tracklets
%         stitch_gaps       - frame ranges where stitching was needed
%         stitch_costmx     - costmatrix used to stitch gaps
%         stitch_seqs       - sequences involved in each stitch process
%         stitch_seq_map    - maps original sequences to stitched sequences 
%         stitch_seq_frames - start and end frame of sequences involved
%
function trks = track_link(trks,calib)
    params = calib.params;
    params.PPM = calib.PPM;
    n_seq = numel(trks.sequences);
    n_frames = numel(trks.frame_ids);
    num_flies = calib.n_flies;   
    
    % compute time cost    
    time_cost = zeros(n_seq);
    for i=1:n_seq
        t_end = trks.sequences{i}.time_end;
        for j=1:n_seq
            t_start = trks.sequences{j}.time_start;
            time_cost(i,j) = t_start-t_end;
        end
    end
    time_cost(time_cost<=0) = inf;
    time_cost = time_cost./calib.FPS; % map cost to seconds
    
    % compute space-time cost tradeoff based on time
    slope = 1; 
    shift = 1; % 1 second
    tradeoff = 10; 
    elim_cost = 10; % 5mm (2.5 fly lengths) or .25 seconds
    weight = 1./(1+exp(-slope*(time_cost-shift)));
    
    % compute votes based on number of sequence present
    % - vote for sequences where at most num flies present (so that hopefully 
    %   trajectories due to noise do not get voted for)
    votes_for = zeros(n_seq,1);
    total_seqs = zeros(n_frames,1);
    for i=1:n_frames
       seqs = trks.frame_seq_list{i};
       total_seqs(i) = numel(seqs);
       if numel(seqs) <= num_flies 
           votes_for(seqs) = votes_for(seqs)+1;
       end
    end
    % - vote against other sequences that coexist with those sequences
    votes_against = zeros(n_seq,1);
    for i=1:n_frames
       seqs = trks.frame_seq_list{i};
       if numel(seqs) > num_flies
           votes = votes_for(seqs);
           if any(votes)
               [~,sort_ids] = sort(votes,'descend');               
               min_votes = votes(sort_ids(num_flies+1));
               votes_against(seqs(votes<=min_votes)) = votes_against(seqs(votes<=min_votes))+1;
           end
       end
    end 

    % store start and end times and compute duration of sequences
    start_times = zeros(1,n_seq);
    end_times = start_times;
    dists = zeros(1,n_seq);
    for i=1:numel(start_times)
        start_times(i) = trks.sequences{i}.time_start;
        end_times(i) = trks.sequences{i}.time_end;
        x = trks.sequences{i}.track(:,1);
        y = trks.sequences{i}.track(:,2);
        dists(i) = nansum((diff(x).^2 + diff(y).^2).^.5);
    end
    dists = dists./calib.PPM;
    durations = end_times-start_times+1;
    vote_certain = votes_against == 0 & votes_for > 0;  
    length_certain = durations' > 100 & dists' > 2.5;    
    certain = vote_certain & length_certain;            
    seq_mapping = 1:n_seq;
    
    % rearrange sequences, sort by start time, then end time, then certainty
    [~,inds] = sort(certain,'descend');
    start_times = start_times(inds);
    end_times = end_times(inds);
    certain = certain(inds);
    votes_for = votes_for(inds);
    dists = dists(inds);
    seq_mapping = seq_mapping(inds);
    [~,inds] = sort(end_times,'ascend');
    start_times = start_times(inds);
    end_times = end_times(inds);
    certain = certain(inds);
    votes_for = votes_for(inds);
    dists = dists(inds);
    seq_mapping = seq_mapping(inds);
    [~,inds] = sort(start_times,'ascend');
    start_times = start_times(inds);
    end_times = end_times(inds);
    certain = certain(inds);
    votes_for = votes_for(inds);
    dists = dists(inds);
    seq_mapping = seq_mapping(inds);
    
    % arrange certain sequences greedily   
    curr_ends = zeros(1,num_flies);
    trajs = zeros(num_flies,n_frames);
    junctions = zeros(0,2);
    for i=1:n_seq
        if certain(i) == 0, continue; end
        t1 = start_times(i);
        t2 = end_times(i);
        spot = find(curr_ends < t1); 
        if numel(spot) == 0
            spot = numel(curr_ends) + 1;
        else
            spot_pref = setdiff(spot,num_flies+1:numel(curr_ends));
            if numel(spot_pref) > 1
                spot = spot_pref;
            end
            [~,min_idx] = min(curr_ends(spot));
            spot = spot(min_idx(1));                
        end     
        if spot <= num_flies
            trajs(spot,t1:t2) = 1;
            if ~(curr_ends(spot)==0 && t1 == 1)
                junctions = [junctions; curr_ends(spot)+1 t1-1];
            end
        end
        curr_ends(spot) = t2;
    end
    if numel(junctions) > 0
        [~,inds] = sort(junctions(:,2),'ascend');
        junctions = junctions(inds,:);
        [~,inds] = sort(junctions(:,1),'ascend');
        junctions = junctions(inds,:);
    end
    
    % arrange uncertain sequences greedily
    uncertain = find(~certain);
    curr_ends_u = zeros(1,1);
    rejected = ones(1,numel(uncertain));
    vacancy = min(trajs,[],1)==0;
    uncertain_cardi = zeros(1,n_frames);
    for ind=1:numel(uncertain);
        i = uncertain(ind);
        t1 = start_times(i);
        t2 = end_times(i);
        % check whether sequence fits inside some junction
        if all(vacancy(t1:t2))
            rejected(ind) = 0;
            uncertain_cardi(t1:t2) = uncertain_cardi(t1:t2) + 1;
        else
            continue
        end
        spot = find(curr_ends_u < t1); 
        if numel(spot) == 0
            spot = numel(curr_ends_u) + 1;
        else
            spot = min(spot);
        end    
        curr_ends_u(spot) = t2;
    end

    % Find sub-sequence matching problems
    % - look at all junctions and see if an uncertain trajectory may belong there
    gaps = zeros(0,2);
    vac_cc = bwconncomp(vacancy);
    for c=1:vac_cc.NumObjects
        t_start = vac_cc.PixelIdxList{c}(1);
        t_end = vac_cc.PixelIdxList{c}(end);
        gaps = [gaps; t_start t_end];
    end
    % - add junctions that consist of a single frame
    size_junct = junctions(:,2)-junctions(:,1)+1;
    for i=1:size(junctions,1)
        if size_junct(i) == 0
            valid = junctions(i,2) <= gaps(:,2);
            valid = junctions(i,1) >= gaps(valid,1);
            if ~any(valid)
                gaps = [gaps; junctions(i,:)];
            end
        end
    end
    [~,inds] = sort(gaps(:,1));
    gaps = gaps(inds,:);
    
    % allow uncertain trajectories to connect to themselves;
    self_cost = inf(n_seq,n_seq);    
    n_uncertain = numel(uncertain);
    for i=1:n_uncertain        
        seq_id = seq_mapping(uncertain(i));
        seq = trks.sequences{seq_id};
        dur = seq.time_end-seq.time_start+1;
        self_cost(seq_id,seq_id) = elim_cost*(1 + ...
            2*votes_for(uncertain(i))/(votes_for(uncertain(i))+2) + ...
            2*dur/(dur+10) + ...
            2*dists(uncertain(i))/(dists(uncertain(i))+1));    
    end

    % find which sequences are involved in each of the subproblems and
    % construct a cost matrix specifically for them    
    n_problems = size(gaps,1);
    seqs = cell(n_problems,1);
    seq_frames = cell(n_problems,1);
    costmats = cell(n_problems,1);
    m_fwd = zeros(1,n_seq);
    for i=1:n_problems        
        seqs_end = find(end_times >= gaps(i,1)-1 & end_times <= gaps(i,2)+1);
        seqs_start = find(start_times >= gaps(i,1)-1 & start_times <= gaps(i,2)+1);    
        valid_seqs = setdiff(union(seqs_start,seqs_end),uncertain(rejected==1));    
        seqs{i} = seq_mapping(valid_seqs);
        seq_frames{i} = [start_times(valid_seqs)' end_times(valid_seqs)'];
        
        % compute cost based on spatial gap
        space_cost_i = get_cost(trks,seqs{i},seqs{i},params)./calib.PPM; %map cost to mm
        % extract time and selfdestruction cost for subproblem
        time_cost_i = time_cost(seqs{i},seqs{i});
        weight_i = weight(seqs{i},seqs{i});
        self_cost_i = self_cost(seqs{i},seqs{i});        
        % combine costs into one costmatrix
        costmat_i = weight_i.*sqrt(time_cost_i)*tradeoff+ (1-weight_i).*space_cost_i; 
        costmat_i(self_cost_i < inf) = self_cost_i(self_cost_i < inf);
        costmats{i} = costmat_i;
        
        if gaps(i,end) == n_frames
            % if there are certain trajectories at the end, they will be
            % paired with one of the dummy nodes, then the uncertain
            % trajectories can fight over the remaining dummy nodes
            n_extra = num_flies;
            tmp_costmat = inf(numel(seqs{i}),numel(seqs{i})+n_extra);
            tmp_costmat(1:numel(seqs{i}),1:numel(seqs{i})) = costmats{i};
            tmp_costmat(:,numel(seqs{i})+1:end) = elim_cost; 
            tmp_fwd = match(tmp_costmat);
            tmp_fwd(tmp_fwd>numel(seqs{i})) = 0;
            tmp_fwd = tmp_fwd(1:numel(seqs{i}));
        else
            tmp_fwd = match(costmats{i});
        end    
        m_fwd(seqs{i}(tmp_fwd>0)) = seqs{i}(tmp_fwd(tmp_fwd>0));
    end

    % consolidate trajectories 
    trajectories = cell(1,n_seq);
    traj_frames = zeros(1,n_seq);    
    rem_seqs = 1:n_seq;
    count = 0;
    while ~isempty(rem_seqs)
        count = count + 1;
        next = rem_seqs(1);
        while next ~=0 && ~isnan(next) && ~ismember(next,trajectories{count})
            trajectories{count} = [trajectories{count} next];
            start_fr = trks.sequences{next}.time_start;
            end_fr = trks.sequences{next}.time_end;            
            traj_frames(count) = traj_frames(count) + end_fr-start_fr+1;
            next = m_fwd(next);
        end
        rem_seqs = setdiff(rem_seqs,trajectories{count});
    end
    trajectories = trajectories(1:count);    
    traj_frames = traj_frames(1:count);
    if numel(trajectories) > num_flies
        [~,inds] = sort(traj_frames,'descend');
        trajectories = trajectories(inds(1:num_flies));        
    end    
    
    % map sequences to trajectories (so that they can be used when
    %  determining flag frames)
    seq_to_traj = zeros(n_seq,1);    
    for i=1:numel(trajectories)
        seq_to_traj(trajectories{i}) = i;
    end
    stitch_seqs = seqs;
    for i=1:numel(seqs)
        stitch_seqs{i} = seq_to_traj(seqs{i});
    end
    
    % update flags from matching to reflect the current sequences    
    if isfield(trks,'flags')
        flags = zeros(0,6); % keep track of which frame had highest ambiguity
        for f=1:size(trks.flags,1)
            s1 = trks.flags(f,1); seqA = seq_to_traj(s1);
            s2 = trks.flags(f,2); seqB = seq_to_traj(s2);
            seq1 = min(seqA,seqB);
            seq2 = max(seqA,seqB);
            if seq1 == 0 || seq2 == 0, continue; end
            fr1 = trks.flags(f,3); fr2 = fr1;
            cut_fr = fr1;
            ambig = trks.flags(f,4);
            idx = find(flags(:,1)==seq1 & flags(:,2)==seq2 & ...
                     fr1 <= flags(:,4)+5 & fr2 >= flags(:,3)-5);
            if numel(idx) > 0
                fr1 = min([flags(idx,3); fr1]);
                fr2 = max([flags(idx,4); fr2]);  
                [ambig,ind] = min([flags(idx,5); ambig]); 
                if ind <= numel(idx)
                    cut_fr = flags(idx(ind),6);
                end
                % delete current inds;
                flags(idx,:) = [];                              
            end
            flags(end+1,:) = [seq1 seq2 fr1 fr2 ambig cut_fr];
        end
        % map ambiguities from pixels to mm
        flags(:,5) = flags(:,5)/calib.PPM;
        trks.flags = flags;
    end

    % update sequences
    sequences = cell(numel(trajectories),1);
    frame_seq_list = cell(numel(trks.frame_ids),1);
    for t=1:numel(trajectories)
        sequence.cardinality = 1;
        first_seq = trajectories{t}(1);
        last_seq = trajectories{t}(end);
        sequence.time_start = trks.sequences{first_seq}.time_start;
        sequence.time_end = trks.sequences{last_seq}.time_end;
        duration = sequence.time_end-sequence.time_start+1;

        % update frame_seq_list
        % - find frames where this fly is present
        temp = zeros(numel(frame_seq_list),1);
        for s=1:numel(trajectories{t})
            s_id = trajectories{t}(s);
            temp(trks.sequences{s_id}.time_start:trks.sequences{s_id}.time_end) = 1;
        end
        % - only register it in frames where it is visible
        valid_frames = find(temp);
        for f=1:numel(valid_frames)
            fr = valid_frames(f);
            frame_seq_list{fr} = [frame_seq_list{fr} t];
        end

        obj_list = zeros(duration,1);
        appearancecost = nan(2,duration);
        track    = nan(duration,size(trks.sequences{1}.track,2));
        for i=1:numel(trajectories{t})
            seq_id = trajectories{t}(i);
            time_start = trks.sequences{seq_id}.time_start - sequence.time_start + 1;
            time_end = time_start+numel(trks.sequences{seq_id}.obj_list)-1;
            obj_list(time_start:time_end) = trks.sequences{seq_id}.obj_list;
            appearancecost(:,time_start:time_end) = trks.sequences{seq_id}.appearancecost;
            track(time_start:time_end,:) = trks.sequences{seq_id}.track;
        end
        sequence.obj_list = obj_list;
        sequence.track = track;   
        sequence.appearancecost = appearancecost;
        sequences{t,1} = sequence;
    end
    trks.sequences = sequences;
    trks.frame_seq_list = frame_seq_list;
    
    % store stitch information
    trks.stitch_costmx = costmats;
    trks.stitch_gaps = gaps;
    trks.stitch_seqs = stitch_seqs;
    trks.stitch_seq_map = seqs;
    trks.stitch_seq_frames = seq_frames;
    
    % flag potential swaps based on stitch information
    trks.flags = flag_swaps(trks);

    % update orientations again after linking
    trks = track_choose_orientations(trks,calib);

end

function cost_mx = get_cost(trks,froms,tos,params)
    det_prev.body_cc.NumObjects = numel(froms);
    det_curr.body_cc.NumObjects = numel(tos);
    if isfield(trks,'frame_data')
        % detect prev
        det_prev.body_cc.PixelIdxList = cell(1,numel(froms));
        det_prev.body_cc.ImageSize = trks.frame_data{1}.body_cc.ImageSize;
        for i=1:numel(froms)            
            seq_id = froms(i);
            seq = trks.sequences{seq_id};
            frame = seq.time_end;
            obj_id = seq.obj_list(end);
            det_prev.body_props(i) = trks.frame_data{frame}.body_props(obj_id);
            det_prev.body_cc.PixelIdxList{i} = trks.frame_data{frame}.body_cc.PixelIdxList{obj_id};
            % shift according to motion
            if numel(seq.obj_list) > 1 && ~isnan(seq.track(end-1,1))
                dPos = seq.track(end,1:2)-seq.track(end-1,1:2);
                det_prev.body_props(i).Centroid = ...
                    det_prev.body_props(i).Centroid + dPos/2;
                inds = det_prev.body_cc.PixelIdxList{i};
                [I,J] = ind2sub(det_prev.body_cc.ImageSize,inds);
                I = I+round(dPos(2)/2); J = J+round(dPos(1)/2);
                I = max(1,min(det_prev.body_cc.ImageSize(1),I));
                J = max(1,min(det_prev.body_cc.ImageSize(2),J));
                det_prev.body_cc.PixelIdxList{i} = ...
                    sub2ind_faster(det_prev.body_cc.ImageSize,I,J);                    
            end
        end
        % detect curr
        det_curr.body_cc.PixelIdxList = cell(1,numel(tos));
        det_curr.body_cc.ImageSize = trks.frame_data{1}.body_cc.ImageSize;
        for i=1:numel(tos)
            seq_id = tos(i);
            seq = trks.sequences{seq_id};
            frame = seq.time_start;
            obj_id = seq.obj_list(1);
            det_curr.body_props(i) = trks.frame_data{frame}.body_props(obj_id);
            det_curr.body_cc.PixelIdxList{i} = trks.frame_data{frame}.body_cc.PixelIdxList{obj_id};
            % shift according to motion
            if numel(seq.obj_list) > 1 && ~isnan(seq.track(2,1))
                dPos = seq.track(1,1:2)-seq.track(2,1:2);
                det_curr.body_props(i).Centroid = ...
                    det_curr.body_props(i).Centroid + dPos/2;
                inds = det_curr.body_cc.PixelIdxList{i};
                [I,J] = ind2sub(det_curr.body_cc.ImageSize,inds);
                I = I+round(dPos(2)/2); J = J+round(dPos(1)/2);
                I = max(1,min(det_curr.body_cc.ImageSize(1),I));
                J = max(1,min(det_curr.body_cc.ImageSize(2),J));
                det_curr.body_cc.PixelIdxList{i} = ...
                    sub2ind_faster(det_curr.body_cc.ImageSize,I,J);                    
            end            
        end        
    else
        %create det_prev (with only information about position)
        for i=1:numel(froms)
            seq_id = froms(i);
            seq = trks.sequences{seq_id};
            posx = seq.track(end,1);
            posy = seq.track(end,2);            
            det_prev.body_props(i).Centroid = [posx posy];            
            % shift according to motion
            if size(seq.track,1) > 1 && ~isnan(seq.track(end-1,1))
                dPos = seq.track(end,1:2)-seq.track(end-1,1:2);
                det_prev.body_props(i).Centroid = ...
                    det_prev.body_props(i).Centroid + dPos/2;
            end
        end
        %create det_curr (with only information about position)
        for i=1:numel(tos)
            seq_id = tos(i);
            seq = trks.sequences{seq_id};
            posx = seq.track(1,1);
            posy = seq.track(1,2);
            det_curr.body_props(i).Centroid = [posx posy];    
            % shift according to motion
            if size(seq.track,1) > 1 && ~isnan(seq.track(2,1))
                dPos = seq.track(1,1:2)-seq.track(2,1:2);
                det_prev.body_props(i).Centroid = ...
                    det_prev.body_props(i).Centroid + dPos/2;
            end
        end
    end
    % cost matrix
    cost_mx = detection_match_costs(det_prev, det_curr, params.PPM);                                                   
end

function flags = flag_swaps(trks)
    ambi_thresh = 1; %mm
    if isfield(trks,'flags')
        flags = trks.flags; %flags from matching due to split bodies
    else
        flags = zeros(0,6); %[seq1 seq2 start_frame end_frame ambiguity]
    end

    for i=1:numel(trks.stitch_costmx)
        costmx = trks.stitch_costmx{i};    
        seqs = trks.stitch_seqs{i};
        valid = seqs > 0;
        costmx = costmx(valid,valid);
        seq_frames = trks.stitch_seq_frames{i}(valid,:);
        seqs = seqs(valid);
        m_fwd = match(costmx);
        valid = find(m_fwd>0);
        for m=1:numel(valid)
            from = valid(m);
            to = m_fwd(from);
            if seqs(from) == 0, continue; end % ignore deleted matches
            diffs = costmx(from,:)-costmx(from,to);
            mixinds = find(diffs < ambi_thresh);
            mixinds = setdiff(mixinds,to);
            mixers = mixinds(seqs(from)~=seqs(mixinds) & seqs(mixinds)~=0);
            if numel(mixers) > 0 
                u_ids = unique(seqs(mixers));
                % loop through all sequences that might have been mixed
                for u=1:numel(u_ids)            
                    inds = find(seqs(mixers)==u_ids(u));
                    % pick the sequence most likely to be mixed
                    mixfroms = find(ismember(m_fwd,mixers(inds)));
                    if isempty(mixfroms), continue; end
                    [~,mixidx] = min(costmx(mixfroms,to));                     
                    mixer = mixers(inds(mixidx));
                    mix_from = mixfroms(mixidx);
                    cost_curr = costmx(from,to)    + costmx(mix_from,mixer);
                    cost_alt  = costmx(from,mixer) + costmx(mix_from,to);
                    ambig = cost_alt-cost_curr;
                    if ambig > ambi_thresh*2
                        continue
                    end
                    % add mix candidate to mixup matrix
                    seq_from = seqs(from);
                    seq_to = seqs(mixer);
                    fr1 = seq_frames(from,2);
                    fr2 = min(seq_frames(to,1),seq_frames(mixer,1));
                    cut_fr = round((fr1+fr2)/2);
                    seq1 = min(seq_from,seq_to);
                    seq2 = max(seq_from,seq_to);
                    idx = find(flags(:,1)==seq1 & flags(:,2)==seq2 & ...
                             fr1 <= flags(:,4)+5 & fr2 >= flags(:,3)-5);
                    if numel(idx) > 0
                        fr1 = min([flags(idx,3); fr1]);
                        fr2 = max([flags(idx,4); fr2]);
                        [ambig,ind] = min([flags(idx,5); ambig]); 
                        if ind <= numel(idx)
                            cut_fr = flags(idx(ind),6);
                        end
                        % delete current inds;
                        flags(idx,:) = [];                                      
                    end
                    flags(end+1,:) = [seq1 seq2 fr1 fr2 ambig cut_fr];
                end
            end
        end
    end

    % return the mix candidates sorted by start time
    [~,sortinds] = sort(flags(:,3),'ascend');
    flags = flags(sortinds,:);

    % make sure frames correspond to video
    flags(:,[3:4 6]) = flags(:,[3:4 6]) + trks.frame_ids(1);
end
