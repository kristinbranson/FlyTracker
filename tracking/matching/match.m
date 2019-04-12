
% Matching with both cost and fertility (size) constraints.
%
%    [m_forward m_backward] = match(cost_mx, cost_th, fa, fb, df_th)
%
% where:
%
%    cost_mx    - pairwise matching costs bewteen sets A and B
%                 (m x n matrix where m = |A| and n = |B|)
%    cost_th    - maximum cost match allowed (default = 0)
%    cost_diff_th - minimum cost ambiguity allowed (default = inf)
%    fa         - length m vector of fertilities for set A (default = all ones)
%    fb         - length n vector of fertilities for set B (default = all ones)
%
% returns:
%
%    m_foward   - length m vector mapping items in set A to set B
%    m_backward - length n vector mapping items in set B to set A
%                 (in each case, a zero indicates an item is not matched)
%
% 1) Match detections using hungarian algorithm with greedy assignment of outliers
% 2) Eliminate assignments that exceed maximum fertility
% 3) Allow matches to switch to high fertility detection if cheaper
% 4) Eliminate ambiguous matches (according to cost_diff_th)
%
function [m_forward, m_backward] = match(cost_mx, cost_th, cost_diff_th, fa, fb)
   % get number of items in each set
   [m, n] = size(cost_mx);
   % return if problem is trivial
   if (n==0 || m==0)
      m_forward = [];
      m_backward = [];
      return
   end
   % set default cost threshold if not specified
   if (nargin < 2 || isempty(cost_th)), cost_th = inf; end
   % set default ambiguity threshold if not specified
   if (nargin < 3 || isempty(cost_diff_th)), cost_diff_th = -inf; end
   % set default fertilities 
   if (nargin < 4 || isempty(fa)), fa = ones([m 1]); end
   if (nargin < 5 || isempty(fb)), fb = ones([n 1]); end

   % 1) Match detections using hungarian algorithm
   [m_forward,m_backward] = match_hungarian(cost_mx, cost_th);   
  
   % 2) Eliminate matches that exceed maximum fertility
   counts_b = histc(m_forward,1:numel(fb)); counts_b = counts_b(:);
   invalid = find(counts_b > fb);
   for i=1:numel(invalid)
       idx = invalid(i);
       m_forward(m_forward==idx) = 0;
       if fb(idx) > 0 %|| card_b(idx) == 0
           % allow the best match to stay matched
           m_forward(m_backward(idx)) = idx;
       else
           % fully delete the matching both ways           
           from_idx = m_backward(idx);
           m_backward(idx) = 0;           
           % reset m_forward in case other blobs were matched to it
           to_inds = find(m_backward==from_idx);
           if numel(to_inds)>0
               [~,new_to] = min(cost_mx(from_idx,to_inds));
               m_forward(from_idx) = to_inds(new_to);
           end
       end
   end
   counts_a = histc(m_backward,1:numel(fa)); counts_a = counts_a(:);
   invalid = find(counts_a > fa);
   for i=1:numel(invalid)
       idx = invalid(i);
       m_backward(m_backward==idx) = 0;
       if fa(idx) > 0 %|| card_a(idx) == 0
           % allow the best match to stay matched
           m_backward(m_forward(idx)) = idx;
       else
           % fully delete the matching both ways
           to_idx = m_forward(idx);
           m_forward(idx) = 0;
           % reset m_backward in case other blobs were matched to it
           from_inds = find(m_forward==to_idx);
           if numel(from_inds)>0
               [~,new_from] = min(cost_mx(from_inds,to_idx));
               m_backward(to_idx) = from_inds(new_from);
           end
       end
   end      
   
   % 3) Allow matches to switch to high fertility detection if cheaper
   higher = find(fa>1);
   for i=1:numel(higher)
       idx = higher(i);
       fert = sum(fb(m_backward==idx));
       d_fert = fa(idx)-fert;
       if d_fert > 0
           other_inds = find(m_backward~=idx);
           for j=1:numel(other_inds)
               other = other_inds(j);
               from = m_backward(other);
               if (from == 0 || cost_mx(idx,other) < cost_mx(from,other)) ...
                       && cost_mx(idx,other) < cost_th && fb(other) <= d_fert
                   m_backward(other) = idx;
                   if from > 0, m_forward(from) = 0; end
                   if m_forward(idx) == 0, m_forward(idx) = other; end
                   d_fert = d_fert - fb(other);
                   if d_fert <= 0, break; end
               end
           end
       end
   end   
   higher = find(fb>1);
   for i=1:numel(higher)
       idx = higher(i);
       fert = sum(fa(m_forward==idx));
       d_fert = fb(idx)-fert;
       if d_fert > 0
           other_inds = find(m_forward~=idx);
           for j=1:numel(other_inds)
               other = other_inds(j);
               to = m_forward(other);
               if (to == 0 || cost_mx(other,idx) < cost_mx(other,to)) ...
                       && cost_mx(other,idx) < cost_th && fa(other) <= d_fert
                   m_forward(other) = idx;
                   if to > 0, m_backward(to) = 0; end
                   if m_backward(idx) == 0, m_backward(idx) = other; end
                   d_fert = d_fert - fa(other);
                   if d_fert <= 0, break; end
               end
           end
       end
   end   
   
   % 4) Eliminate ambiguous matches (according to cost_diff_th)
   if cost_diff_th > -inf
       % check whether forward matches are valid
       for i=1:numel(m_forward)
           from = i;
           to = m_forward(i);
           if to==0, continue; end
           inds = find(m_backward==i);
           if numel(inds) == 0, continue; end
           cost = max(cost_mx(i,inds));
           other_inds = find(m_backward~=i);
           if numel(other_inds) == 0, continue; end
           ambig_inds = other_inds(cost_mx(i,other_inds)-cost < cost_diff_th);
           for a=1:numel(ambig_inds)
               ambi_to = ambig_inds(a);
               ambi_from = m_backward(ambi_to);
               if ambi_from == i
                   continue
               elseif ambi_from == 0
                   m_forward(i) = 0;
                   m_backward(inds) = 0;
               else
                   curr_cost = cost_mx(from,to)+cost_mx(ambi_from,ambi_to);
                   alt_cost = cost_mx(from,ambi_to)+cost_mx(ambi_from,to);
                   if alt_cost-curr_cost < cost_diff_th*2
                       m_backward([to ambi_to]) = 0;
                       m_forward([from ambi_from]) = 0; 
                       m_backward(inds) = 0;
                   end
               end
           end
       end
       % check whether backward matches are valid   
       for i=1:numel(m_backward)
           to = i;
           from = m_backward(i);
           if from==0, continue; end
           inds = find(m_forward==i);
           if numel(inds) == 0, continue; end
           cost = max(cost_mx(inds,i));
           other_inds = find(m_forward~=i);
           if numel(other_inds) == 0, continue; end
           ambig_inds = other_inds(cost_mx(other_inds,i)-cost < cost_diff_th);
           for a=1:numel(ambig_inds)
               ambi_from = ambig_inds(a);
               ambi_to = m_forward(ambi_from);
               if ambi_to == i
                   continue
               elseif ambi_to == 0
                   m_backward(i) = 0;
                   m_forward(inds) = 0;
               else  
                   curr_cost = cost_mx(from,to)+cost_mx(ambi_from,ambi_to);
                   alt_cost = cost_mx(from,ambi_to)+cost_mx(ambi_from,to);
                   if alt_cost-curr_cost < cost_diff_th*2
                       m_forward([from ambi_from]) = 0;
                       m_backward([to ambi_to]) = 0;
                       m_forward(inds) = 0;
                   end
               end
           end       
       end
   end   
   
   % ensure consistency between m_forward and m_backward   
   old_forward = zeros(size(m_forward));
   old_backward = zeros(size(m_backward));
   while any(old_forward~=m_forward) || any(old_backward~= m_backward)
       old_forward = m_forward;
       old_backward = m_backward;
       inds = find(m_forward == 0);
       m_backward(ismember(m_backward,inds)) = 0;
       inds = find(m_backward == 0);
       m_forward(ismember(m_forward,inds)) = 0;
   end
end

% Perform an initial matching using the Hungarian algorithm with outlier cost
% specified by threshold th.  Modify these initial matches by allowing any 
% unpaired items (initially assigned as outliers) to also match to a currently
% paired item (so matching is no longer one-to-one) if the cost of the 
% additional match is less than th.
function [m_forward, m_backward] = match_hungarian(cost_mx, th)
   % get number of items in each set
   [m, n] = size(cost_mx);
   % set default cost threshold if not specified
   if (nargin < 2), th = inf; end
   % treat infinite threshold as twice highest cost in matrix
   if (isinf(th))
      th = 2.*max(cost_mx(:));
   end
   % introduce nodes for outliers, create new cost matrix
   s = m+n;
   c_mx = th.*ones([s s]);
   c_mx(1:m,1:n) = cost_mx;
   % solve assignment problem using hungarian algorithm
   assign = munkres(c_mx);
   % create match vectors
   m_forward  = zeros([m 1]);
   m_backward = zeros([n 1]);
   for i = 1:m
      % get match
      j = assign(i);
      % record if match is valid
      if ((j > 0) && (j <= n))
         m_forward(i)  = j;
         m_backward(j) = i;
      end
   end
   % perform additional greedy matching
   [m_forward, m_backward] = match_greedy(cost_mx, th, m_forward, m_backward);
end

% Set correspondences between items by greedily picking the lowest cost match
% from the cost matrix.  Only matches costing less than the given threshold are
% permitted.  If given, preserve initial matches specified by m_forward and
% m_backward while matching currently unassigned items in a greedy fashion.
function [m_forward, m_backward] = match_greedy(cost_mx, th, m_forward, m_backward)
   % get number of items in each set
   [m, n] = size(cost_mx);
   % set default cost threshold if not specified
   if (nargin < 2), th = inf; end
   % initialize match vectors if not specified
   if (nargin < 3), m_forward  = zeros([m 1]); end
   if (nargin < 4), m_backward = zeros([n 1]); end
   % sort matches by cost
   [costs, inds] = sort(cost_mx(:));
   [is, js] = ind2sub([m n],inds);
   % perform greedy matching
   for k = 1:(m*n)
      % get indices to match and cost
      i = is(k);
      j = js(k);
      c = costs(k);
      % check if match allowed
      m_ok = (c < th);
      % update matches
      m_forward(i)  = m_forward(i)  + m_ok.*(m_forward(i)==0).*j;
      m_backward(j) = m_backward(j) + m_ok.*(m_backward(j)==0).*i;
   end
end
