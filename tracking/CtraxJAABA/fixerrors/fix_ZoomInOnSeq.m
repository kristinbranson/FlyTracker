function fix_ZoomInOnSeq(handles,seq)
% set plot axes to show a particular sequence number
% splintered from fixerrorsgui 6/21/12 JAB

if strcmpi(handles.zoommode,'whole arena'),
  return;
end

if exist('seq','var'),
  handles.seq = seq;
end

BORDER = round(min(handles.nr,handles.nc)/30);

frames = max(min(handles.seq.frames)-10,1):max(handles.seq.frames)+10;
nfliesseq = length(handles.seq.flies);
nframesseq = length(frames);
x0 = nan(nfliesseq,nframesseq);
x1 = x0; y0 = x0; y1 = x0; 
for flyi = 1:nfliesseq,
  fly = handles.seq.flies(flyi);
  for fi = 1:nframesseq,
    f = frames(fi);
    i = handles.trx(fly).off+(f);
    if isalive(handles.trx(fly),f)
      [x0(flyi,fi),x1(flyi,fi),y0(flyi,fi),y1(flyi,fi)] = ...
        ellipse_to_bounding_box(handles.trx(fly).x(i),handles.trx(fly).y(i),...
        handles.trx(fly).a(i)*2,handles.trx(fly).b(i)*2,handles.trx(fly).theta(i));
    end
  end
end
badidx = isnan(x0);
if length( find( badidx ) ) == length( x0(:) )
   return % no live tracks left in sequence
end
x0(badidx) = []; y0(badidx) = []; x1(badidx) = []; y1(badidx) = [];

xlim = [min(x0(:))-BORDER,max(x1(:))+BORDER];
xlim = max(min(xlim,handles.nc),1);
ylim = [min(y0(:))-BORDER,max(y1(:))+BORDER];
ylim = max(min(ylim,handles.nr),1);

% match aspect ratio
[xlim,ylim] = match_aspect_ratio(xlim,ylim,handles);

set(handles.mainaxes,'xlim',xlim,'ylim',ylim);
