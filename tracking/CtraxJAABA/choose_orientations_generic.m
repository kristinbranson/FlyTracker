% theta = choose_orientations_generic(theta,wtheta,appearancecost)
%
% we will set the orientation to theta_t = theta_t + s_t * pi
% we want to choose s_t to minimize
% \sum_t cost(s_t|s_{t-1})
% cost(s_t|s_{t-1}) = [wtheta_t*d(\theta_t,\theta_{t-1}) +
%                      appearancecost(s_t,t)]
%
% we will find the most likely states s_t using the recursion
% cost_t(s_t) = min_{s_{t-1}} { cost_{t-1}(s_{t-1}) + cost(s_t|s_{t-1})
%
% Inputs:
% theta: N x 1 vector where theta(t) is the orientation of the fly at time t
% wtheta: N x 1 vector where wtheta(t) is the weight of the change in
% orientation term at time t
% appearancecost: N x 2 vector where appearancecost(t,s) is the
% appearance-based cost for choosing state s at time t
%
% Outputs:
% theta: N x 1 vector of chosen/optimized orientations
% s: N x 1 indicator vector taking values 1 (theta unchanged from orig) or
% 2 (theta flipped)
function [theta,s] = choose_orientations_generic(theta,weight_theta,appearancecost)

inputsz = size(theta);
theta = theta(:);
weight_theta = weight_theta(:);

% number of frames
N = length(theta);

% allocate space for storing the optimal path
stateprev = zeros(N-1,2);

% allocate space for computing costs
tmpcost = zeros(2,1);
costprevnew = zeros(2,1);

% initialize first frame
costprev = zeros(2,1);

% % compute velocity
% vx = [0;diff(x)];
% vy = [0;diff(y)];
% 
% % compute angle of velocity
% velocityangle = atan2(vy,vx);

% compute iteratively
for t = 2:N,
  
  % compute for both possible states
  for scurr = 1:2,
    
    % try both previous states
    thetacurr = theta(t) + (scurr-1)*pi;
    
    for sprev = 1:2,
      
      thetaprev = theta(t-1) + (sprev-1)*pi;
      costcurr = weight_theta(t)*angledist(thetaprev,thetacurr) + ...
        appearancecost(scurr,t);
      tmpcost(sprev) = costprev(sprev) + costcurr;
      
    end
    
    % choose the minimum
    sprev = argmin(tmpcost);
    
    % set pointer for path
    stateprev(t-1,scurr) = sprev;
    
    % set cost
    costprevnew(scurr) = tmpcost(sprev);
    
  end
  
  % copy over
  costprev(:) = costprevnew(:);
  
end

s = nan(1,N);

% choose the best last state
scurr = argmin(costprev);
s(end) = scurr;

if scurr == 2,
  theta(end) = modrange(theta(end)+pi,-pi,pi);
end

% choose the best states
for t = N-1:-1:1,
  scurr = stateprev(t,scurr);
  s(t) = scurr;
  if scurr == 2,
    theta(t) = modrange(theta(t)+pi,-pi,pi);
  end  
end

theta = reshape(theta,inputsz);