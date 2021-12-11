function handles = SetSeq(handles,seqi,isfirstframe)
% set the GUI state for displaying a particular sequence index
% splintered from fixerrorsgui 6/23/12 JAB

handles.seqi = seqi;
handles.seq = handles.seqs(seqi);
handles.f = handles.seq.frames(1);
handles.nselect = 0;
handles.selected = [];
set(handles.errnumbertext,'string',sprintf('Error: %d/%d',seqi,length(handles.seqs)));
set(handles.seqframestext,'string',sprintf('Frames: %d:%d',handles.seq.frames(1),handles.seq.frames(end)));
set(handles.seqfliestext,'string',['Flies: [',num2str(handles.seq.flies),']']);
set(handles.seqtypetext,'string',sprintf('Type: %s',handles.seq.type));
set(handles.seqsusptext,'string',sprintf('Susp: %f',max(handles.seq.suspiciousness)));

% set fly colors so that flies that are close have different colors
x = nan(1,handles.nflies);
y = nan(1,handles.nflies);
f = round(mean([handles.seq.frames(1),handles.seq.frames(end)]));
for fly = 1:handles.nflies,
  if ~isalive(handles.trx(fly),f),
    continue;
  end
  i = handles.trx(fly).off+(f);
  x(fly) = handles.trx(fly).x(i);
  y(fly) = handles.trx(fly).y(i);
end

D = squareform(pdist([x;y]'));
handles.colors(handles.seq.flies,:) = handles.colors0(handles.colororder(1:length(handles.seq.flies)),:);
isassigned = false(1,handles.nflies);
isassigned(handles.seq.flies) = true;
D(:,handles.seq.flies) = nan;
for i = length(handles.seq.flies)+1:handles.nflies,
  [mind,fly] = min(min(D(isassigned,:),[],1));
  if isnan(mind),
    handles.colors(~isassigned,:) = handles.colors0(handles.colororder(i:end),:);
    break;
  end
  handles.colors(fly,:) = handles.colors0(handles.colororder(i),:);
  isassigned(fly) = true;
  D(:,fly) = nan;
end

if isfield(handles,'hpath'),
  for fly = 1:handles.nflies,
     if length( handles.hpath ) < fly
        fprintf( 1, 'error at fly %d: nflies %d; len hpath %d, len hcenter %d\n', fly, handles.nflies, length( handles.hpath ), length( handles.hcenter ) );
        break
     end
    safeset(handles.hpath(fly),'color',handles.colors(fly,:));
    safeset(handles.hpath(fly),'color',handles.colors(fly,:));
    safeset(handles.htailmarker(fly),'color',handles.colors(fly,:));
    safeset(handles.hellipse(fly),'color',handles.colors(fly,:));
    safeset(handles.hleft(fly),'color',handles.colors(fly,:));
    safeset(handles.hright(fly),'color',handles.colors(fly,:));
    safeset(handles.hhead(fly),'color',handles.colors(fly,:));
    safeset(handles.htail(fly),'color',handles.colors(fly,:));
    safeset(handles.hcenter(fly),'color',handles.colors(fly,:));
  end
end

if nargin < 3 || ~isfirstframe,
  fix_SetFrameNumber(handles);
  fix_PlotFrame(handles);
  fix_ZoomInOnSeq(handles);
end


function safeset(h,varargin)

if ishandle(h),
  set(h,varargin{:});
end
