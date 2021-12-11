function handles = fix_FixTrackFlies(flies,f0,f1,handles)
% track multiple flies
% splintered from fixerrorsgui 6/23/12 JAB

guidata(handles.figure1,handles);

MINPRIOR = .01;
se = strel('disk',1);
nflies = length(flies);
mu0 = zeros(nflies,2);
S0 = zeros([2,2,nflies]);
priors0 = zeros(1,nflies);
for i = 1:nflies,
  fly = flies(i);
  j = handles.trx(fly).off+(f0);
  mu0(i,:) = [handles.trx(fly).x(j),handles.trx(fly).y(j)];
  S0(:,:,i) = axes2cov(handles.trx(fly).a(j)*2,handles.trx(fly).b(j)*2,handles.trx(fly).theta(j));
  priors0(i) = handles.trx(fly).a(j)*handles.trx(fly).b(j);
end
priors0 = priors0 / sum(priors0);

if isfield(handles,'trajfns'),
  extrafns = setdiff(handles.trajfns,{'x','y','a','b','theta'});
else
  extrafns = {};
end

for f = f0+1:f1

  drawnow;
  handles = guidata(handles.figure1);
  if isfield(handles,'stoptracking') && handles.stoptracking
    break;
  end
  
  % get foreground/background classification around flies
  [isfore,dfore,xpred,ypred,thetapred,r0,r1,c0,c1] = fix_FixBgSub(flies,f,handles);

  [cc,ncc] = bwlabel(isfore);
  isdeleted = [];
  for fly2 = 1:handles.nflies,
    if ismember(fly2,flies), continue; end
    if ~isalive(handles.trx(fly2),f), continue; end
    i2 = handles.trx(fly2).off+(f);
    if handles.trx(fly2).x(i2)-(2*handles.trx(fly2).a(i2)+5) > c1 || ...
        handles.trx(fly2).x(i2) + (2*handles.trx(fly2).a(i2)+5)< c0 || ...
        handles.trx(fly2).y(i2) + (2*handles.trx(fly2).a(i2)+5)< r0 || ...
        handles.trx(fly2).y(i2) - (2*handles.trx(fly2).a(i2)+5)> r1,
      continue;
    end
    bw = ellipsepixels([handles.trx(fly2).x(i2),handles.trx(fly2).y(i2),...
      handles.trx(fly2).a(i2)*4,handles.trx(fly2).b(i2)*4,handles.trx(fly2).theta(i2)],...
      [r0,r1,c0,c1]);
    j = 1;
    while true,
      if j > ncc,
        break;
      end

      if ismember(j,isdeleted), 
        j = j + 1;
        continue; 
      end
      fracoverlap = sum(dfore((cc==j) & bw)) / sum(dfore(cc==j));
      if nflies == 1
         testfracoverlap = 0.75;
      else
         testfracoverlap = 0.85;
      end
      if fracoverlap > testfracoverlap
        isfore(cc==j) = false;
        isdeleted(end+1) = j;
        cc(cc==j) = 0;
      elseif fracoverlap > 0
         if nflies == 1
            bw = imdilate(bw,se);
         end
        isfore(bw) = false;
        cc(bw) = 0;
        tmp = cc == j;
        tmp = imopen(tmp,se);
        %[cctmp,ncctmp] = bwlabel(tmp);
        %if ncctmp > 1
        %  areas = regionprops(cctmp,'area');
        %  areas = getstructarrayfield(areas,'Area');
        %  k = argmax(areas);
        %else
        %  k = 1;
        %end
        %tmp = cctmp==k;
        isfore(cc==j) = false;
        cc(cc==j) = 0;
        cc(tmp) = j;
        isfore(tmp) = true;
        [cctmp,ncctmp] = bwlabel(tmp);
        for k = 2:ncctmp,
          ncc = ncc+1;
          cc(cctmp==k) = ncc;
        end
      end
      j = j + 1;
    end
  end
  % choose the closest connected component
  if ~any(isfore(:)),
    msgbox(sprintf('Frame %d: Could not find the selected fly, quitting.',f));
    handles.trackingstoppedframe = f;
    return;
  end
  
  if nflies == 1
     % fit an ellipse
     [tmp1,tmp2,cc] = unique(cc);
     cc = reshape(cc,size(isfore))-1;
     if tmp1(1) == 0
        ncc = length(tmp1)-1;
     end
     xfit = zeros(1,ncc);
     yfit = zeros(1,ncc);
     thetafit = zeros(1,ncc);
     for j = 1:ncc,
        [y,x] = find(cc==j);
        w = dfore(cc==j);
        [nmu,S] = weighted_mean_cov([x,y],w(:));
        xfit(j) = nmu(1);
        yfit(j) = nmu(2);
        [a,b,thetafit(j)] = cov2ell(S);
     end
     xfit = xfit + c0 - 1;
     yfit = yfit + r0 - 1;
     if ncc == 1,
        j = 1;
     else
        err = (xpred - xfit).^2 + (ypred - yfit).^2 + handles.ang_dist_wt*(modrange(thetapred - thetafit,-pi/2,pi/2)).^2;
        j = argmin(err);
     end
     mu(1,1) = xfit(j);
     mu(1,2) = yfit(j);
     priors = 1;
     
  else
     % use GMM to fit multiple ellipses
     w = dfore(isfore);
     w = w / max(w);
     mix = gmm(2, nflies, 'full');
     mix.centres = mu0;
     mix.covars = S0;
     mix.priors = priors0;
     [y,x] = find(isfore);
     x = x + c0 - 1;
     y = y + r0 - 1;
     [mu,S,priors] = mygmm([x(:),y(:)],nflies,'start',mix,'weights',w);
     if any(priors < MINPRIOR),
        msgbox(sprintf('Frame %d: Prior for a fly got too small, aborting.',f));
        handles.trackingstoppedframe = f;
        return;
     end
  end

  % update trx structures
  for i = 1:nflies,
    fly = flies(i);
    j = handles.trx(fly).off+(f);
    handles.trx(fly).x(j) = mu(i,1);
    handles.trx(fly).y(j) = mu(i,2);
    [a,b,theta] = cov2ell(S(:,:,i));
    handles.trx(fly).a(j) = a/2;
    handles.trx(fly).b(j) = b/2;
    dtheta = modrange(theta-handles.trx(fly).theta(j-1),-pi/2,pi/2);
    handles.trx(fly).theta(j) = modrange(handles.trx(fly).theta(j-1)+dtheta,-pi,pi);
    for fni = 1:numel(extrafns),
      handles.trx(fly).(extrafns{fni})(j) = nan;
    end
    handles.trx(fly).nframes = length(handles.trx(fly).x);
    handles.trx(fly).endframe = handles.trx(fly).firstframe + handles.trx(fly).nframes - 1;
    if isfield( handles, 'timestamps' ) && length( handles.timestamps ) >= f && isfield( handles.trx(fly), 'timestamps' )
       handles.trx(fly).timestamps(j) = handles.timestamps(f);
    end
  end
  handles.f = f;
  if handles.trx(fly).endframe < handles.f
    handles.trx(fly).endframe = f;
  end
  guidata(handles.figure1,handles);

  % display progress, if applicable
  if get(handles.manytrackshowtrackingbutton,'value') || get( handles.showtrackingbutton, 'value' )
    fix_PlotFrame(handles);
    xlim = get(handles.mainaxes,'xlim');
    ylim = get(handles.mainaxes,'ylim');
    minx = min(mu(:,1));
    maxx = max(mu(:,1));
    miny = min(mu(:,2));
    maxy = max(mu(:,2));
    if minx < xlim(1) || maxx > xlim(2) || miny < ylim(1) || maxy > ylim(2)
      seq.frames = [max(f0,f-20),min(f1,f+20)];
      seq.flies = flies;
      fix_ZoomInOnSeq(handles,seq);
    end
  else
    set(handles.frameedit,'string',sprintf('%05d',f));
  end

  mu0 = mu;
  S0 = S;
  priors0 = priors;
  
end
