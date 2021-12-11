function [isfore,dfore,xpred,ypred,thetapred,r0,r1,c0,c1,im] = fix_FixBgSub(flies,f,handles)

trx = handles.trx(flies);
nflies = length(flies);
boxrad = handles.maxjump;

% get predicted locations for all flies, to select tracking ROI
xpred = zeros(1,nflies);
ypred = zeros(1,nflies);
thetapred = zeros(1,nflies);
for j = 1:nflies,
  i = max( trx(j).off+(f), 2 ); % first frame
  x1 = trx(j).x(i-1);
  y1 = trx(j).y(i-1);
  theta1 = trx(j).theta(i-1);
  if i == 2,
    xpred(j) = x1;
    ypred(j) = y1;
    thetapred(j) = theta1;
  else
    x2 = trx(j).x(i-2);
    y2 = trx(j).y(i-2);
    theta2 = trx(j).theta(i-2);
    [xpred(j),ypred(j),thetapred(j)] = cvpred(x2,y2,theta2,x1,y1,theta1);
  end
end

% choose image and ROI
r0 = max(floor(min(ypred)-boxrad),1); r1 = min(ceil(max(ypred)+boxrad),handles.nr);
c0 = max(floor(min(xpred)-boxrad),1); c1 = min(ceil(max(xpred)+boxrad),handles.nc);
im = handles.readframe(f);
if( handles.flipud )
   for channel = 1:size( im, 3 )
      im(:,:,channel) = flipud( im(:,:,channel) );
   end
end
im = double(im(r0:r1,c0:c1));

% subtract bg
bg = handles.bgcurr(r0:r1,c0:c1);
dfore = im - bg;
if handles.lighterthanbg == 1
  dfore = max(dfore,0);
elseif handles.lighterthanbg == -1
  dfore = max(-dfore,0);
else
  dfore = abs(dfore);
end

% check circular arena
if isfield( handles, 'circular_arena' ) && ...
      isfield( handles.circular_arena, 'do_set_circular_arena' ) && ...
      handles.circular_arena.do_set_circular_arena
   [cc, rr] = meshgrid( c0:c1, r0:r1 );
   non_arena_mask = sqrt( ...
      (cc - handles.circular_arena.arena_center_x).^2 + ...
      (rr - handles.circular_arena.arena_center_y).^2 ) ...
      > handles.circular_arena.arena_radius;
   dfore(non_arena_mask) = 0;
end

% check locally defined circular arena
if isfield( handles, 'temp_arena' )
   [cc, rr] = meshgrid( c0:c1, r0:r1 );
   non_arena_mask = sqrt( ...
      (cc - handles.temp_arena.center_x).^2 + ...
      (rr - handles.temp_arena.center_y).^2 ) ...
      > handles.temp_arena.radius;
   dfore(non_arena_mask) = 0;
end

% threshold and smooth
isfore = dfore >= handles.bgthresh;
se = strel('disk',1);
isfore = imclose(isfore,se);
isfore = imopen(isfore,se);
