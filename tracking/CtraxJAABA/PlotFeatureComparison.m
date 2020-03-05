function PlotFeatureComparison(fd,cd,ftrx,ctrx,f2c,fn,varargin)

[haxcurr,plottype,limprctile,nbins,domatch] = myparse(varargin,'hax',nan,'plottype','hist',...
  'limprctile',1,'nbins',100,'domatch',true);
fnflies = numel(ftrx);
cnflies = numel(ctrx);

if ~ishandle(haxcurr),
  hfig = figure;
  haxcurr = gca;
end

hold(haxcurr,'on');
  
[fd2,delta] = reorder_match(f2c,cd.data,ctrx,ftrx);

fdall = [fd.data{:}];
fd2all = [fd2{:}];

switch plottype,
  case 'off',
    off = fdall-fd2all;%./nanmedian(abs([fd2{:}]));
    ctrs = linspace(prctile(off,limprctile),prctile(off,100-limprctile),nbins);
    [counts] = hist(off,ctrs);
    plot(haxcurr,ctrs,counts/sum(counts),'k-');
  case 'hist'
    if domatch,
      ctrs1 = HelpGetCtrs(nbins,limprctile,fdall,fd2all);
      ctrs2 = ctrs1;
    else
      ctrs1 = HelpGetCtrs(nbins,limprctile,fdall);
      ctrs2 = HelpGetCtrs(nbins,limprctile,fd2all);
    end
    alldata = [fdall',fd2all'];
    alldata(isnan(fdall)|isnan(fd2all),:) = [];
    counts = hist3(alldata,{ctrs1,ctrs2});
    counts = counts / sum(counts(:));
    imagesc([ctrs1(1),ctrs1(end)],[ctrs2(1),ctrs2(end)],counts','Parent',haxcurr);
    clim = [0,prctile(counts(:),100-limprctile)];
    if clim(end) == 0,
      clim(end) = max(counts(:));
    end
    set(haxcurr,'CLim',clim);
    xlabel(haxcurr,'FlyTracker');
    ylabel(haxcurr,'Ctrax');
    %plot(haxcurr,[minv,maxv],[minv,maxv],'k-');
  case 'raw',
    colors = hsv(fnflies);
    for ffly = 1:fnflies,
      plot(haxcurr,fd.data{ffly},fd2{ffly},'.','Color',colors(ffly,:));
    end
    xlabel(haxcurr,'FlyTracker');
    ylabel(haxcurr,'Ctrax');
end
title(haxcurr,fn,'Interpreter','none');
switch plottype,
  case 'raw',
    axisalmosttight([],haxcurr);
    axis(haxcurr,'equal');
    xlim = get(haxcurr,'XLim');
    ylim = get(haxcurr,'YLim');
    r = [min(xlim(1),ylim(1)),max(xlim(2),ylim(2))];
    plot(haxcurr,r,r,'k-');
    set(haxcurr,'xlim',r,'ylim',r);
  case 'off'
    axisalmosttight([],haxcurr);
  case 'hist',
    if domatch,
      axis(haxcurr,'image');
    else
      axis(haxcurr,'tight');
    end
    set(haxcurr,'YDir','normal');
    colormap(haxcurr,'jet');
end

function ctrs = HelpGetCtrs(nbins,limprctile,varargin)

ctrs = [];
for i = 1:numel(varargin),
  ctrs = union(ctrs,varargin{i}(~isnan(varargin{i})));
end
if numel(ctrs) > nbins,
  minv = inf;
  maxv = -inf;
  for i = 1:numel(varargin),
    minv = min(minv,prctile(varargin{i},limprctile));
    maxv = max(maxv,prctile(varargin{i},100-limprctile));
  end
  ctrs = linspace(minv,maxv,nbins);
else
  minv = ctrs(1);
  maxv = ctrs(end);
  ctrs = linspace(minv,maxv,numel(ctrs));
end
