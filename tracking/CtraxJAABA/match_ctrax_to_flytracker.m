function [f2c,c2f,cost] = match_ctrax_to_flytracker(ctrx,ftrx,varargin)

[dummycost,DEBUG,readframe,nfill] = myparse(varargin,'dummycost',100,'debug',0,'readframe',[],'nfill',5);

cnflies = numel(ctrx);
fnflies = numel(ftrx);
nframes = max(max([ctrx.endframe]),max([ftrx.endframe]));
firstframe = min(min([ctrx.firstframe]),min([ftrx.firstframe]));

% [xhead, xtail, yhead, ytail] x nflies x nframes
cX = nan(4,cnflies,nframes);
fX = nan(4,fnflies,nframes);
for fly = 1:cnflies,
  cX(1,fly,ctrx(fly).firstframe:ctrx(fly).endframe) = ctrx(fly).x + 2*ctrx(fly).a.*cos(ctrx(fly).theta);
  cX(2,fly,ctrx(fly).firstframe:ctrx(fly).endframe) = ctrx(fly).x - 2*ctrx(fly).a.*cos(ctrx(fly).theta);
  cX(3,fly,ctrx(fly).firstframe:ctrx(fly).endframe) = ctrx(fly).y + 2*ctrx(fly).a.*sin(ctrx(fly).theta);
  cX(4,fly,ctrx(fly).firstframe:ctrx(fly).endframe) = ctrx(fly).y - 2*ctrx(fly).a.*sin(ctrx(fly).theta);
end

for fly = 1:fnflies,
  fX(1,fly,ftrx(fly).firstframe:ftrx(fly).endframe) = ftrx(fly).x + 2*ftrx(fly).a.*cos(ftrx(fly).theta);
  fX(2,fly,ftrx(fly).firstframe:ftrx(fly).endframe) = ftrx(fly).x - 2*ftrx(fly).a.*cos(ftrx(fly).theta);
  fX(3,fly,ftrx(fly).firstframe:ftrx(fly).endframe) = ftrx(fly).y + 2*ftrx(fly).a.*sin(ftrx(fly).theta);
  fX(4,fly,ftrx(fly).firstframe:ftrx(fly).endframe) = ftrx(fly).y - 2*ftrx(fly).a.*sin(ftrx(fly).theta);
end

cost = nan(1,nframes);
f2c = zeros(fnflies,nframes);
for t = firstframe:nframes,

  cidx = find(all(~isnan(cX(:,:,t)),1));
  fidx = find(all(~isnan(fX(:,:,t)),1));
%   if isempty(cidx) || isempty(fidx),
%     continue;
%   end
  cn = numel(cidx);
  fn = numel(fidx);
  dreal = permute(sum((cX(:,cidx,t)-permute(fX(:,fidx,t),[1,3,2])).^2,1),[2,3,1]);
  
  d = zeros(cn+fn);
  d(1:cn,1:fn) = dreal;
  d(1:cn,fn+1:end) = dummycost;
  d(cn+1:end,1:fn) = dummycost;
  
  % d(f2c(i),i) selected
  [f2ccurr,cost(t)] = hungarian(d);
  f2ccurr = f2ccurr(1:fn);
  fflies = fidx(f2ccurr<=cn);
  cflies = cidx(f2ccurr(f2ccurr<=cn));
  f2c(fflies,t) = cflies;
  
  if DEBUG > 1 && ~isempty(readframe),

    figure;
    clf;
    im = readframe(t);
    hax(1) = subplot(1,3,1);
    imagesc(im); axis image; colormap gray;
    hold on;
    plot(cX(1,:,t),cX(3,:,t),'go');
    plot(cX(1:2,:,t),cX(3:4,:,t),'g-');
    plot(fX(1,:,t),fX(3,:,t),'bs');
    plot(fX(1:2,:,t),fX(3:4,:,t),'b-');
    title(num2str(t));
    subplot(1,3,2);
    imagesc(d);
    set(gca,'CLim',[0,dummycost*2]); axis image; set(gca,'YDir','normal'); xlabel('f id'); ylabel('c id');
    hax(2) = subplot(1,3,3);
    imagesc(im); axis image;
    hold on;
    plot(cX(1,:,t),cX(3,:,t),'go');
    plot(cX(1:2,:,t),cX(3:4,:,t),'g-');
    
    for flyi = 1:numel(fidx),
      ffly = fidx(flyi);
      if f2ccurr(flyi) > cn,
        plot(fX(1,ffly,t),fX(3,ffly,t),'mx');
        plot(fX(1:2,ffly,t),fX(3:4,ffly,t),'m-');
      else
        cfly = cidx(f2ccurr(flyi));
        plot(fX(1,ffly,t),fX(3,ffly,t),'bs');
        plot([fX(1,ffly,t);cX(1,cfly,t)],[fX(3,ffly,t);cX(3,cfly,t)],'c-');
        plot([fX(2,ffly,t);cX(2,cfly,t)],[fX(4,ffly,t);cX(4,cfly,t)],'c-');
      end
      text(mean(fX(1:2,ffly,t)),mean(fX(3:4,ffly,t)),num2str(ffly),'Color',[0,1,1],'HorizontalAlignment','center','VerticalAlignment','top');
      text(mean(cX(1:2,ffly,t)),mean(cX(3:4,ffly,t)),num2str(cfly),'Color',[1,1,0],'HorizontalAlignment','center','VerticalAlignment','bottom');
    end
    linkaxes(hax);
    drawnow;
  end
end

% fill holes
f2cfill = f2c;
se = strel(ones(1,nfill+1));
for fly = 1:fnflies,
  counts = hist(f2c(fly,ftrx(fly).firstframe:ftrx(fly).endframe),1:cnflies);
  [~,order] = sort(-counts);
  for cfly = order,
    if counts(cfly) == 0,
      break;
    end
    isalive = ~any(isnan(fX(:,fly,:)),1);
    iscfly = f2cfill(fly,:)==cfly;
    iscfly2 = imclose(iscfly,se) & isalive(:)';
    if any(iscfly2 & ~iscfly),
      fprintf('Filling %d frames of ffly %d with cfly %d\n',nnz(iscfly2&~iscfly),fly,cfly);
      f2cfill(fly,iscfly2) = cfly;
    end
  end
end

% compute reverse lookup
c2f = zeros(cnflies,nframes);
for cfly = 1:cnflies,
  [fflies,ts] = find(f2c==cfly);
  c2f(cfly,ts) = fflies;
end

