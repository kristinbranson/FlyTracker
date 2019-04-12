
% Auto-correct potential identity swaps of tracked flies.
%
% To auto-correct identities, use:
%
%   trk = track_auto_id(trk)
%
% where:
%
%    trk.        - tracking structure obtained from tracker_jobs
%         names  - names of fields in .data
%         data   - n_flies x n_frames x n_fields containing raw tracking data
%         flags  - n_swaps x 6 matrix containing potential identity swaps
%                  (fly1, fly2, frame_start, frame_end, ambiguity, swap_frame)
%
% returns:
%
%    trk         - same as input but fields in data has been moved around
%                  where flies were swapped
%    swaps       - n_actual_swaps x 3 matrix listing swaps that were made
%                  (fly1, fly2, swap_frame)
%
function [trk,swaps] = track_auto_id(trk)
    % Compute features for all flies
    n_flies = size(trk.data,1);
    n_frames = size(trk.data,2);
    X = zeros(n_flies*n_frames,5);
    Y = zeros(n_flies*n_frames,1);
    for i=1:n_flies    
        major_ax = trk.data(i,:,strcmp('major axis len',trk.names));
        minor_ax = trk.data(i,:,strcmp('minor axis len',trk.names));
        axis_ratio = major_ax./minor_ax;
        body_area = trk.data(i,:,strcmp('body area',trk.names));
        wing_l_len = trk.data(i,:,strcmp('wing l len',trk.names));
        wing_r_len = trk.data(i,:,strcmp('wing r len',trk.names));
        mean_wing_len = nanmean([wing_l_len; wing_r_len]);
        % features
        inds = (i-1)*n_frames+(1:n_frames);        
        X(inds,1) = major_ax;
        X(inds,2) = minor_ax;
        X(inds,3) = axis_ratio;
        X(inds,4) = body_area;
        X(inds,5) = mean_wing_len;
        % labels
        Y(inds) = i;
    end

    % Compute bin features for all flies
    binX = bin_features(X,50);
    binFeat = zeros(n_frames,size(binX,2),n_flies);
    for i=1:n_flies
        binFeat(:,:,i) = binX(Y==i,:);
    end

    % Find breakpoints
    flags = trk.flags;
    involved = cell(1,size(flags,1));
    for i=1:size(flags,1)
        involved{i} = flags(i,1:2);
    end
    breaks = zeros(n_flies,n_frames);
    for f=1:size(flags,1)
        breakpoint = flags(f,3);
        breaks(involved{f},breakpoint) = 1;
    end

    % Loop through flags
    swaps = []; % fly 1, fly 2, frame, dur, motion_cost_diff, appear_cost_diff
    for f=1:size(flags,1)
        flies = involved{f};
        % train classifiers on all trajectories before flag    
        Xtr = []; Ytr = [];
        Xte = []; Yte = [];
        fr_end = flags(f,3);
        inds = 1:fr_end;
        framecounts = zeros(size(flies));
        for i=1:numel(flies)
            Xtr = [Xtr; binFeat(inds,:,flies(i))];
            Ytr = [Ytr; flies(i)*ones(numel(inds),1)];        
            brks = find(breaks(flies(i),:));
            next_brk = min(brks(brks>flags(f,4)));
            if numel(next_brk)==0
                next_brk = n_frames;
            end
            nextinds = flags(f,4):next_brk;
            Xte = [Xte; binFeat(nextinds,:,flies(i))];
            Yte = [Yte; flies(i)*ones(numel(nextinds),1)];        
            framecounts(i) = numel(nextinds);
        end
        count_tr = hist(Ytr,unique(Ytr));
        count_te = hist(Yte,unique(Ytr));
        if all(count_te > count_tr)
            % this only happens early in the video, if ever   
            tmpX = Xtr;  tmpY = Ytr;
            Xtr = Xte;   Ytr = Yte;
            Xte = tmpX;  Yte = tmpY;
            % make sure classes are balanced in training
            inds1 = find(Ytr==flies(1));
            inds2 = find(Ytr==flies(2));
            if count_te(1) > count_te(2)                
                inds1 = inds1(1:count_te(2));                
            elseif count_te(2) > count_te(1)
                inds2 = inds2(1:count_te(1));
            end            
            Xtr = Xtr([inds1; inds2],:);
            Ytr = Ytr([inds1; inds2],:);
        end
        if numel(Ytr) > 10000
            dt = max(1,floor(numel(Ytr)/10000));
            Xtr = Xtr(1:dt:end,:);
            Ytr = Ytr(1:dt:end);
        end

        % train a liblinear model
        model = train(Ytr,double(sparse(Xtr)),'-s 0 -c 1 -B 1 -e 0.01 -q');   
        model.w = [model.w; -model.w];
        % make sure model corresponds to the correct flies
        if model.Label(1) ~= flies(1)
            disp('switched')
            model.w = -model.w;
        end
        
        % apply classifiers to tracklets following flag
        scores = [Xte ones(size(Xte,1),1)*model.bias] * model.w';           
        
        % compute probabilities
        probs = exp(scores) ./ repmat(sum(exp(scores),2),1,size(scores,2));
        probs = probs + .001;
        probs = probs ./ repmat(sum(probs,2),1,size(probs,2));
        assign_prob = zeros(numel(flies));
        for i=1:numel(flies)
            inds = find(Yte==flies(i));
            for j=1:numel(flies)
                prob = sum(probs(inds,j));
                assign_prob(i,j) = prob;
            end
            assign_prob(i,:) = assign_prob(i,:)/sum(assign_prob(i,:));
            % add ambiguity to very short tracklets
            assign_prob(i,:) = assign_prob(i,:) + exp(-numel(inds)/100);
            assign_prob(i,:) = assign_prob(i,:)/sum(assign_prob(i,:));
        end
        costmx = -log(assign_prob);
        assignment = match(costmx);
        tmp = find(abs(assignment' - (1:numel(flies))));        
        if numel(tmp) > 0
            t=1;
            fly1 = flies(tmp(t));
            fly2 = flies(assignment(tmp(t)));        
            if size(flags,2) >= 6
            frame = flags(f,6);
            else
                frame = round((flags(f,3)+flags(f,4))/2);
            end
            count = sum(Yte==flies(tmp(t)));
            appear_cost_diff = (costmx(1,1)+costmx(2,2)) - ...
                                   (costmx(1,2)+costmx(2,1));
            motion_cost_diff = flags(f,5);
            if appear_cost_diff > motion_cost_diff        
                % add swap
                swap = [fly1 fly2 frame count motion_cost_diff appear_cost_diff];
                swaps = [swaps; swap]; 
                % update bin feat
                tmp_bin = binFeat(frame:end,:,fly1);
                binFeat(frame:end,:,fly1) = binFeat(frame:end,:,fly2);
                binFeat(frame:end,:,fly2) = tmp_bin;
                % update breaks
                tmp_breaks = breaks(fly1,frame:end);
                breaks(fly1,frame:end) = breaks(fly2,frame:end);
                breaks(fly2,frame:end) = tmp_breaks;
                % update flags and involved
                valid_flags = find(flags(:,4) > frame);
                for i=1:numel(valid_flags)
                    flag = valid_flags(i);
                    idx1 = (involved{flag}==fly1);
                    idx2 = (involved{flag}==fly2);
                    involved{flag}(idx1) = fly2;
                    involved{flag}(idx2) = fly1;
                end  

            end
        end
    end

    % update trk and feat according to swaps
    flags = trk.flags;
    for i=1:size(swaps,1)
        fly1 = swaps(i,1);
        fly2 = swaps(i,2);
        frame = swaps(i,3);
        % update trk
        tmp_trk = trk.data(fly1,frame:end,:);
        trk.data(fly1,frame:end,:) = trk.data(fly2,frame:end,:);
        trk.data(fly2,frame:end,:) = tmp_trk;
        % update flags
        inds11 = (flags(:,1)==fly1 & flags(:,4)>=frame);
        inds12 = (flags(:,2)==fly1 & flags(:,4)>=frame);
        inds21 = (flags(:,1)==fly2 & flags(:,4)>=frame);
        inds22 = (flags(:,2)==fly2 & flags(:,4)>=frame);
        flags(inds11,1) = fly2;
        flags(inds12,2) = fly2;
        flags(inds21,1) = fly1;
        flags(inds22,2) = fly1;
    end
    trk.flags = flags;
end

function [binX,bins] = bin_features(X,bins)
    n_points = size(X,1);
    n_feat = size(X,2);
    % if bins are not provided, create them here
    if isscalar(bins)
        n_bins = bins;
        bins = cell(1,n_feat);
        for i=1:n_feat
            % discrete features get their own discrete bins
            uniq = unique(X(:,i));
            if numel(uniq) <= n_bins
                uniq = sort(uniq);
                if numel(uniq)<2
                    delta = eps;
                else
                    delta = min(diff(uniq))*.5;
                end
                bins{i} = uniq(1:end-1)+delta;
                continue
            end
            % use 5th and 95th percentiles as boundaries
            perc05 = prctile(X(:,i),5);
            perc95 = prctile(X(:,i),95);
            % split the interval between there into equally sized bins
            bins{i} = perc05:(perc95-perc05)/(n_bins-1):perc95;
        end
    end
    n_feats = zeros(1,numel(bins));
    for i=1:numel(bins)
        n_feats(i) = numel(bins{i})+1;
    end
    n_bin_feat = sum(n_feats);
    % move all features to bins
    binX = false(n_points,n_bin_feat);
    t = (1:n_points)';
    for i=1:n_feat
        if numel(bins{i})==0, continue; end
        if numel(bins{i})<2
            binsz = 1;
        else
            binsz = diff(bins{i}(1:2));
        end
        feat = X(:,i);
        valid = ~isnan(feat);
        mapping = ceil((feat(valid)-bins{i}(1))/binsz)+1;
        mapping = max(1,min(n_feats(i),mapping));
        inds = sub2ind(size(binX),t(valid),mapping+sum(n_feats(1:i-1)));
        binX(inds) = true;
    end
end
