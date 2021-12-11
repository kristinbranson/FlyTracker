function handles = fix_FixTrackFly(fly,f0,f1,handles)
% do tracking (or fix tracking) of one fly
% splintered from fixerrorsgui 6/21/12 JAB

trk = handles.trx(fly);
se = strel('disk',2);
for f = f0+1:f1

  drawnow;
  handles = guidata(handles.figure1);
  if isfield(handles,'stoptracking') && handles.stoptracking
    break;
  end
  
  i = trk.off+(f);
  [isfore,dfore,xpred,ypred,thetapred,r0,r1,c0,c1,im] = fix_FixBgSub(fly,f,handles);

  [cc,ncc] = bwlabel(isfore);
  isdeleted = [];
  for fly2 = 1:handles.nflies,
    if fly2 == fly, continue; end
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
      if fracoverlap > .75
        isfore(cc==j) = false;
        isdeleted(end+1) = j;
        cc(cc==j) = 0;
      elseif fracoverlap > 0
        bw = imdilate(bw,se);
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
    msgbox(sprintf('Frame %d: Could not find the selected fly. Quitting',f));
    return;
  end
  [tmp1,tmp2,cc] = unique(cc);
  cc = reshape(cc,size(isfore))-1;
  if tmp1(1) == 0
    ncc = length(tmp1)-1;
  end
  xfit = zeros(1,ncc);
  yfit = zeros(1,ncc);
  thetafit = zeros(1,ncc);
  afit = zeros(1,ncc);
  bfit = zeros(1,ncc);
  for j = 1:ncc,
    [y,x] = find(cc==j);
    w = dfore(cc==j);
    [mu,S] = weighted_mean_cov([x,y],w(:));
    xfit(j) = mu(1);
    yfit(j) = mu(2);
    [afit(j),bfit(j),thetafit(j)] = cov2ell(S);
  end
  afit = afit / 2;
  bfit = bfit / 2;
  xfit = xfit + c0 - 1;
  yfit = yfit + r0 - 1;
  if ncc == 1,
    j = 1;
  else
    err = (xpred - xfit).^2 + (ypred - yfit).^2 + handles.ang_dist_wt*(modrange(thetapred - thetafit,-pi/2,pi/2)).^2;
    j = argmin(err);
  end
  trk.x(i) = xfit(j);
  trk.y(i) = yfit(j);
  trk.theta(i) = thetafit(j);
  trk.a(i) = afit(j);
  trk.b(i) = bfit(j);
  

  dtheta = modrange(trk.theta(i)-trk.theta(i-1),-pi/2,pi/2);
  trk.theta(i) = trk.theta(i-1)+dtheta;
  
  handles.trx(fly).x(i) = trk.x(i);
  handles.trx(fly).y(i) = trk.y(i);
  handles.trx(fly).a(i) = trk.a(i);
  handles.trx(fly).b(i) = trk.b(i);
  handles.trx(fly).theta(i) = trk.theta(i);
  handles.f = f;
  if handles.trx(fly).endframe < handles.f
    handles.trx(fly).endframe = f;
  end
  handles.trx(fly).nframes = length(handles.trx(fly).x);
  guidata(handles.figure1,handles);

  if get(handles.showtrackingbutton,'value')
    fix_PlotFrame(handles);
    xlim = get(handles.mainaxes,'xlim');
    ylim = get(handles.mainaxes,'ylim');
    if trk.x(i) < xlim(1) || trk.x(i) > xlim(2) || trk.y(i) < ylim(1) || trk.y(i) > ylim(2)
      seq.frames = [max(f0,f-50),min(f1,f+50)];
      seq.flies = fly;
      fix_ZoomInOnSeq(handles,seq);
    end
  else
    set(handles.frameedit,'string',sprintf('%05d',f));
  end

end
