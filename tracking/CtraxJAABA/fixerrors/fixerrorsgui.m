function varargout = fixerrorsgui(varargin)
% TRX = FIXERRORSGUI(SEQS,MOVIENAME,TRX,ANNNAME,PARAMS,[LOADNAME])
% SEQS: array of suspicious sequences
% MOVIENAME: name of movie
% TRX: positions of flies over time
% ANNNAME: name of annotation file
% PARAMS: parameters used to determine suspicious sequences
% LOADNAME: previously saved results to restart with

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @fixerrorsgui_OpeningFcn, ...
                   'gui_OutputFcn',  @fixerrorsgui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before fixerrorsgui is made visible.
function fixerrorsgui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to fixerrorsgui (see VARARGIN)

% Choose default command line output for fixerrorsgui
handles.output = hObject;

% read inputs
handles.seqs = varargin{1};
handles.moviename = varargin{2};
handles.trx = varargin{3};
handles.annname = varargin{4};
handles.params = varargin{5};
handles.matname = varargin{6};
if length(varargin) > 6,
  handles.savename = varargin{7};
  didload = false;
else
  didload = false;
end
if length( varargin ) > 7
   readframe_fcn = varargin{8};
   handles.readframe = readframe_fcn.readframe;
   handles.nframes = readframe_fcn.nframes;
   handles.fid = readframe_fcn.fid;
else
   [handles.readframe,handles.nframes,handles.fid] = get_readframe_fcn(handles.moviename);
end
if length( varargin ) > 8
   handles.circular_arena = varargin{9};
else
   handles.circular_arena = struct( 'do_set_circular_arena', 0 );
end

% what fields correspond to trajectories? guess based on sizes
handles.trajfns = fix_GetTrajFields(handles.trx);
assert(all(ismember({'x','y','a','b','theta'},handles.trajfns)));

% get timestamps
if isfield(handles.trx,'timestamps'),
  handles.timestamps = nan(1,handles.nframes);
  for i = 1:numel(handles.trx),
    if isdummytrk( handles.trx(i) ), continue, end
    t0 = handles.trx(i).firstframe;
    t1 = handles.trx(i).endframe;
    if isempty( handles.trx(i).timestamps ) && ~isempty( t0 )
       handles.timestamps(t0:t1) = (t0:t1)/handles.trx(i).fps;
    else       
       if length( handles.timestamps ) >= t1 && ...
             any(~isnan(handles.timestamps(t0:t1)) & ...
             (abs(handles.trx(i).timestamps-handles.timestamps(t0:t1))>1e-5)),
         error('Timestamps don''t match for fly %d',i);
       end
       handles.timestamps(t0:t1) = handles.trx(i).timestamps;
    end
  end
  % interpolate where there are still NaNs
  nan_ind = find( isnan( handles.timestamps ) );
  if ~isempty( nan_ind ) && length( nan_ind ) ~= length( handles.timestamps )
     t0 = nan_ind(1);
     t1 = nan_ind(1);
     for f = 2:length( nan_ind )
        if nan_ind(f) ~= t0 + 1 % not consecutive
           t1 = nan_ind(f - 1);
           v = (1:(t1 - t0 + 1))/handles.trx(1).fps;
           handles.timestamps(t0:t1) = handles.timestamps(t1 + 1) - v(end:-1:1);
           t0 = nan_ind(f);
        end
     end
     if t1 <= t0
        t1 = nan_ind(end);
        v = (1:(t1 - t0 + 1))/handles.trx(1).fps;
        handles.timestamps(t0:t1) = handles.timestamps(t0 - 1) + v;
     end
  end
end

% initialize parameters
handles = InitializeMainAxes(handles);

% initialize state
isseqleft = false;
for i = 1:length(handles.seqs),
  if isempty( strfindi(handles.seqs(i).type,'dummy') ),
    isseqleft = true;
    break;
  end
end
if ~isseqleft,
  if ~didload,
    handles.doneseqs = [];
  end
  guidata(hObject,handles);
  msgbox('No suspicious sequences to be corrected. Exiting. ','All Done');
  uiresume(handles.figure1);
  return
end
handles.flipud = 0;
handles.show_dead = 1;
handles.nflies = length(handles.trx);
handles = fix_SetFlyColors(handles);
handles = fix_SetSeq(handles,i,true);
handles.nselect = 0;
handles.selected = [];
handles.motionobj = [];
handles.plotpath = 'All Flies';
handles.nframesplot = 101;
handles.zoommode = 'sequence';
handles.undolist = {};
handles.needssaving = 0;

handles.bgthresh = 10;
%handles.lighterthanbg = 1;
handles.bgcolor = nan;
[~,~,handles.ang_dist_wt,handles.maxjump,~,~,model_type,~,handles.bgthresh,iscalibfile] = ...
  fix_ReadAnnParams(handles.annname);
if iscalibfile,
  calibd = load(handles.annname);
  handles.bgmed = calibd.bg_mean;
else
  [bgtype,bgmed,bgmean,model_type] = ...
    read_ann(handles.annname,...
    'bg_algorithm','background_median','background_mean','bg_type');
  if strcmpi(bgtype,'median'),
    handles.bgmed = bgmed;
  else
    handles.bgmed = bgmean;
  end
end
if ischar(model_type),
  if strcmp(model_type,'dark_on_light'),
    handles.lighterthanbg = -1;
  elseif strcmp(model_type,'light_on_dark'),
    handles.lighterthanbg = 1;
  else
    handles.ligherthanbg = 0;
  end
else
  if model_type == 0,
    handles.lighterthanbg = 1;
  elseif model_type == 1,
    handles.lighterthanbg = -1;
  else
    handles.lighterthanbg = 0;
  end
end
% initialize data structures

% initialize structure to hold seqs that are done
if ~didload,
  handles.doneseqs = [];
end

% initialize gui

InitializeFrameSlider(handles);
fix_SetFrameNumber(handles);
handles = PlotFirstFrame(handles);
InitializeDisplayPanel(handles);
fix_SetErrorTypes(handles);
handles.bgmed = reshape(handles.bgmed,[handles.nc,handles.nr])';
InitializeKeyPressFcns(handles);

handles = fix_StorePanelPositions(handles);

% Update handles structure
guidata(hObject, handles);

fix_Play(handles,handles.figure1);

% UIWAIT makes fixerrorsgui wait for user response (see UIRESUME)
uiwait(handles.figure1);


function InitializeKeyPressFcns(handles)

h = findobj(handles.figure1,'KeyPressFcn','');
set(h,'KeyPressFcn',get(handles.figure1,'KeyPressFcn'));


function handles = InitializeMainAxes(handles)

handles.mainaxesaspectratio = 1;


function InitializeDisplayPanel(handles)

i = find(strcmpi(get(handles.plotpathmenu,'string'),handles.plotpath),1);
set(handles.plotpathmenu,'value',i);
i = find(strcmpi(get(handles.zoommenu,'string'),handles.zoommode),1);
set(handles.zoommenu,'value',i);
set(handles.nframesplotedit,'string',num2str(handles.nframesplot));

function InitializeFrameSlider(handles)

set(handles.frameslider,'max',handles.nframes,'min',1,'sliderstep',[1,20]/(handles.nframes-1));


% --- Outputs from this function are returned to the command line.
function varargout = fixerrorsgui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
deletetrx = [];
for fly = 1:length(handles.trx),
  if isdummytrk(handles.trx(fly))
    deletetrx(end+1) = fly;
  end
end
handles.trx(deletetrx) = [];
% store correct timestamps
varargout{1} = fix_FixIgnoredFields(handles);
%varargout{1} = handles.trx;
delete(handles.figure1);


function handles = PlotFirstFrame(handles)

axes(handles.mainaxes);
im = handles.readframe(handles.f);
[handles.nr,handles.nc,handles.ncolors] = size(im);
handles.him = imagesc(im);
colormap gray; axis image; hold on;
zoom reset;

switch class(im),
    case 'uint8',
        maxv = 255;
    case 'uint16',
        maxv = 2^16-1;
    otherwise
        maxv = max(im(:));
        if maxv <= 1,
            maxv = 1;
        end
end

set(handles.mainaxes,'Clim',[0,maxv]);
        

handles.hellipse = zeros(1,handles.nflies);
handles.hcenter = zeros(size(handles.hellipse));
handles.hhead = zeros(size(handles.hellipse));
handles.htail = zeros(size(handles.hellipse));
handles.hleft = zeros(size(handles.hellipse));
handles.hright = zeros(size(handles.hellipse));
handles.htailmarker = zeros(size(handles.hellipse));
handles.hpath = zeros(size(handles.hellipse));
for fly = 1:handles.nflies,
  [handles.hellipse(fly),handles.hcenter(fly),handles.hhead(fly),...
    handles.htail(fly),handles.hleft(fly),handles.hright(fly),...
    handles.htailmarker(fly),handles.hpath(fly)] = ...
    InitFly(handles.colors(fly,:));
  handles = fix_UpdateFlyPathVisible(handles);
  handles = fix_FixUpdateFly(handles,fly);
end

fix_ZoomInOnSeq(handles);


function [hellipse,hcenter,hhead,htail,hleft,hright,htailmarker,hpath] = InitFly(color)

hpath = plot(0,0,'.-','color',color,'hittest','off');
htailmarker = plot([0,0],[0,0],'-','color',color,'hittest','off');
hellipse = ellipsedraw(10,10,0,0,0);
set(hellipse,'color',color,'linewidth',2);
set(hellipse,'buttondownfcn','fixerrorsgui(''ellipse_buttondown'',gcbo,[],guidata(gcbo))');
hleft = plot(0,0,'o','markersize',6,'color',color,'markerfacecolor','w');
set(hleft,'buttondownfcn','fixerrorsgui(''left_buttondown'',gcbo,[],guidata(gcbo))');
hright = plot(0,0,'o','markersize',6,'color',color,'markerfacecolor','w');
set(hright,'buttondownfcn','fixerrorsgui(''right_buttondown'',gcbo,[],guidata(gcbo))');
hhead = plot(0,0,'o','markersize',6,'color',color,'markerfacecolor','w');
set(hhead,'buttondownfcn','fixerrorsgui(''head_buttondown'',gcbo,[],guidata(gcbo))');
htail = plot(0,0,'o','markersize',6,'color',color,'markerfacecolor','w');
set(htail,'buttondownfcn','fixerrorsgui(''tail_buttondown'',gcbo,[],guidata(gcbo))');
hcenter = plot(0,0,'o','markersize',6,'color',color,'markerfacecolor','w');
set(hcenter,'buttondownfcn','fixerrorsgui(''center_buttondown'',gcbo,[],guidata(gcbo))');


function tail_buttondown(hObject,eventdata,handles)

fly = find(handles.htail==hObject);
if isempty(fly), return; end
handles.motionobj = {'tail',fly};
guidata(hObject,handles);

function head_buttondown(hObject,eventdata,handles)

fly = find(handles.hhead==hObject);
if isempty(fly), return; end
handles.motionobj = {'head',fly};
guidata(hObject,handles);

function right_buttondown(hObject,eventdata,handles)

fly = find(handles.hright==hObject);
if isempty(fly), return; end
handles.motionobj = {'right',fly};
guidata(hObject,handles);

function left_buttondown(hObject,eventdata,handles)

fly = find(handles.hleft==hObject);
if isempty(fly), return; end
handles.motionobj = {'left',fly};
guidata(hObject,handles);

function ellipse_buttondown(hObject,eventdata,handles)

fly = find(handles.hellipse==hObject,1);
if isempty(fly), return; end

set(handles.selectedflytext,'string',sprintf('Selected Fly %d',fly));

% are we selecting flies?
if handles.nselect == 0, return; end;

handles = fix_SelectFly(handles,fly);
guidata(hObject,handles);

function center_buttondown(hObject,eventdata,handles)

fly = find(handles.hcenter==hObject);
if isempty(fly), return; end
handles.motionobj = {'center',fly};
guidata(hObject,handles);

function handles = move_center(fly,handles)

tmp = get(handles.mainaxes,'CurrentPoint');

% outside of the axis
if tmp(1,3) ~= 1,
  return;
end

i = handles.trx(fly).off+(handles.f);
handles.trx(fly).x(i) = tmp(1,1);
handles.trx(fly).y(i) = tmp(1,2);
fix_FixUpdateFly(handles,fly);

function handles = move_head(fly,handles)

tmp = get(handles.mainaxes,'CurrentPoint');
% outside of the axis
if tmp(1,3) ~= 1,
  return;
end
x1 = tmp(1,1);
y1 = tmp(1,2);
i = handles.trx(fly).off+(handles.f);

x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
theta = handles.trx(fly).theta(i);

x2 = x - a*cos(theta);
y2 = y - a*sin(theta);
x = (x1+x2)/2;
y = (y1+y2)/2;
theta = atan2(y1-y2,x1-x2);
a = sqrt( (x1-x)^2 + (y1-y)^2 )/2;

handles.trx(fly).x(i) = x;
handles.trx(fly).y(i) = y;
handles.trx(fly).a(i) = a;
handles.trx(fly).theta(i) = theta;

fix_FixUpdateFly(handles,fly);

function handles = move_left(fly,handles)

tmp = get(handles.mainaxes,'CurrentPoint');
% outside of the axis
if tmp(1,3) ~= 1,
  return;
end
x3 = tmp(1,1);
y3 = tmp(1,2);
i = handles.trx(fly).off+(handles.f);

x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);

% compute the distance from this point to the major axis
d = -sin(theta)*(x3 - x) + cos(theta)*(y3 - y);
% compute projection onto minor axis
x3 = x - d * sin(theta);
y3 = y + d * cos(theta);

x4 = x + b*cos(theta+pi/2);
y4 = y + b*sin(theta+pi/2);

x = (x3+x4)/2;
y = (y3+y4)/2;
b = sqrt((x3-x)^2 + (y3-y)^2)/2;

handles.trx(fly).x(i) = x;
handles.trx(fly).y(i) = y;
handles.trx(fly).b(i) = b;

fix_FixUpdateFly(handles,fly);

function handles = move_right(fly,handles)

tmp = get(handles.mainaxes,'CurrentPoint');
% outside of the axis
if tmp(1,3) ~= 1,
  return;
end
x4 = tmp(1,1);
y4 = tmp(1,2);
i = handles.trx(fly).off+(handles.f);

x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);

% compute the distance from this point to the major axis
d = -sin(theta)*(x4 - x) + cos(theta)*(y4 - y);
% compute projection onto minor axis
x4 = x - d * sin(theta);
y4 = y + d * cos(theta);

x3 = x - b*cos(theta+pi/2);
y3 = y - b*sin(theta+pi/2);

x = (x3+x4)/2;
y = (y3+y4)/2;
b = sqrt((x3-x)^2 + (y3-y)^2)/2;

handles.trx(fly).x(i) = x;
handles.trx(fly).y(i) = y;
handles.trx(fly).b(i) = b;

fix_FixUpdateFly(handles,fly);

function handles = move_tail(fly,handles)

tmp = get(handles.mainaxes,'CurrentPoint');
% outside of the axis
if tmp(1,3) ~= 1,
  return;
end
x2 = tmp(1,1);
y2 = tmp(1,2);
i = handles.trx(fly).off+(handles.f);

x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
theta = handles.trx(fly).theta(i);

x1 = x + a*cos(theta);
y1 = y + a*sin(theta);
x = (x1+x2)/2;
y = (y1+y2)/2;
theta = atan2(y1-y2,x1-x2);
a = sqrt( (x1-x)^2 + (y1-y)^2 )/2;

handles.trx(fly).x(i) = x;
handles.trx(fly).y(i) = y;
handles.trx(fly).a(i) = a;
handles.trx(fly).theta(i) = theta;

fix_FixUpdateFly(handles,fly);


% --- Executes on slider movement.
function frameslider_Callback(hObject, eventdata, handles)
% hObject    handle to frameslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

handles.f = round(get(hObject,'value'));
fix_SetFrameNumber(handles,hObject);
fix_PlotFrame(handles);
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function frameslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frameslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
fix_SetCreatedObjectBgColor( hObject, [.9 .9 .9] );


function frameedit_Callback(hObject, eventdata, handles)
% hObject    handle to frameedit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frameedit as text
%        str2double(get(hObject,'String')) returns contents of frameedit as a double
f = str2double(get(hObject,'String'));
if isnan(f),
  set(hObject,'string',num2str(handles.f));
  return;
end
handles.f = round(f);
handles.f = max(f,1);
handles.f = min(f,handles.nframes);
if handles.f ~= f,
  set(hObject,'string',num2str(handles.f));
end
fix_SetFrameNumber(handles,handles.f);
fix_PlotFrame(handles);
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function frameedit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frameedit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on selection change in nexterrortypemenu.
function nexterrortypemenu_Callback(hObject, eventdata, handles)
% hObject    handle to nexterrortypemenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns nexterrortypemenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from nexterrortypemenu


% --- Executes during object creation, after setting all properties.
function nexterrortypemenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nexterrortypemenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on selection change in sortbymenu.
function sortbymenu_Callback(hObject, eventdata, handles)
% hObject    handle to sortbymenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns sortbymenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from sortbymenu


% --- Executes during object creation, after setting all properties.
function sortbymenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sortbymenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on button press in correctbutton.
function correctbutton_Callback(hObject, eventdata, handles)
% hObject    handle to correctbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% add to undolist
handles.undolist{end+1} = {'correct',handles.seqi,handles.seq};
handles.needssaving = 1;

% move from seqs to doneseqs
if isempty(handles.doneseqs),
  handles.doneseqs = handles.seq;
else
  handles.doneseqs(end+1) = handles.seq;
end
handles.seqs(handles.seqi).type = ['dummy', handles.seqs(handles.seqi).type];

handles.seqs = check_suspicious_sequences(handles.trx,handles.annname,handles.seqs,handles.params{:});

fix_SetErrorTypes(handles);

% quit if this is the last sequence
if strcmpi(get(handles.correctbutton,'string'),'finish')
  msgbox('All suspicious sequences have been corrected. Quitting.','All Done');
  savebutton_Callback(hObject, [], handles);
  uiresume(handles.figure1);
  return;
end

try
  contents = get(handles.nexterrortypemenu,'string');
  if length(contents) == 1,
    s = contents;
  else
    v = get(handles.nexterrortypemenu,'value');
    if v > length(contents),
      set(handles.nexterrortypemenu,'value',length(contents));
      v = length(contents);
    end
    s = contents{v};
  end
catch
  keyboard;
end

% what is the next type of error
type_list = nexterrortype_type();
nexttype = type_list{strcmpi(type_list(:,1),s),2};
flies = [];
frames = [];
susp = [];
idx = [];

% find an error of type nexttype
for i = 1:length(handles.seqs),
  
  % if this is the right type of error
  if strcmpi(handles.seqs(i).type,nexttype),
    
    % store frames, flies, suspiciousness for this seq
    if strcmpi(nexttype,'swap'),
      flies(end+1) = handles.seqs(i).flies(1)*handles.nflies+handles.seqs(i).flies(2);
    else
      flies(end+1) = handles.seqs(i).flies;
    end
    frames(end+1) = handles.seqs(i).frames(1);
    susp(end+1) = max(handles.seqs(i).suspiciousness);
    idx(end+1) = i;
    
  end
  
end

if isempty(flies), keyboard; end

% choose error of this type if there are more than one
contents = get(handles.sortbymenu,'string');
sortby = contents{get(handles.sortbymenu,'value')};
if strcmpi(sortby,'suspiciousness'),
  j = argmax(susp);
  handles = fix_SetSeq(handles,idx(j));
elseif strcmpi(sortby,'frame number'),
  j = argmin(frames);
  handles = fix_SetSeq(handles,idx(j));
elseif strcmpi(sortby,'fly'),
  if strcmpi(handles.seq.type,'swap'),
    currfly = handles.seq.flies(1)*handles.nflies +handles.seq.flies(2);
  else
    currfly = handles.seq.flies;
  end
  issamefly = flies == currfly;
  if any(issamefly),
    nextfly = currfly;
  else
    nextfly = min(flies);
  end
  nextflies = find(flies == nextfly);
  j = nextflies(argmin(frames(nextflies)));
  handles = fix_SetSeq(handles,idx(j));
end

guidata(hObject,handles);

fix_Play(handles,hObject);


% --- Executes on button press in backbutton.
function backbutton_Callback(hObject, eventdata, handles)
% hObject    handle to backbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% find most recent "correct" action and skip back to previous sequence
for ai = length( handles.undolist ):-1:1
   if strcmp( handles.undolist{ai}{1}, 'correct' )
      % put previously corrected sequence back into sequence list
      handles.seqi = handles.undolist{ai}{2};
      handles.seq = handles.undolist{ai}{3};
      handles.needssaving = 1;
      handles.seqs(handles.seqi) = handles.seq;
      % remove from undo list
      if ai == 1
         if length( handles.undolist ) == 1
            handles.undolist = {};
         else
            handles.undolist = handles.undolist{2:end};
         end
      elseif ai == length( handles.undolist )
         handles.undolist = handles.undolist{1:end-1};
      else
         try % untested
            handles.undolist = handles.undolist{[1:ai-1 ai+1:length( handles.undolist )]};
         catch err
            handles.undolist
            ai
            handles.seq
            rethrow( err )
         end
      end
      % remove from doneseqs list
      if length( handles.doneseqs ) == 1
         handles.doneseqs = {};
      else
         for di = 1:length( doneseqs )
            if all( handles.doneseqs(di).flies == handles.seq.flies ) && ...
                  strcmp( handles.doneseqs(di).type, handles.seq.type ) && ...
                  length( handles.doneseqs(di).frames ) == length( handles.seq.frames ) && ...
                  all( handles.doneseqs(di).frames == handles.seq.frames ) && ...
                  length( handles.doneseqs(di).suspiciousness ) == length( handles.seq.suspiciousness ) && ...
                  all( handles.doneseqs(di).suspiciousness == handles.seq.suspiciousness )
               % if this is the sequence we just undid...
               if di == 1
                  handles.doneseqs = handles.doneseqs(2:end);
               elseif di == length( handles.doneseqs )
                  handles.doneseqs = handles.doneseqs(1:end-1);
               else
                  try % untested
                     handles.doneseqs = handles.doneseqs([1:di-1 di+1:length( handles.doneseqs )]);
                  catch err
                     handles.doneseqs
                     di
                     handles.seq
                     rethrow( err )
                  end
               end
               break
            end
         end
      end

      % update GUI to old sequence
      handles = fix_SetSeq( handles, handles.seqi );
      fix_SetErrorTypes( handles );
      % find type string matching sequence type
      type_list = nexterrortype_type;
      type_ind = nan;
      for ti = 1:size( type_list, 1 )
         if strcmpi( type_list{ti,2}, handles.seq.type )
            type_ind = ti;
         end
      end
      if isnan( type_ind ), keyboard, end
      % find menu item matching type string
      content = get( handles.nexterrortypemenu, 'string' );
      if ~iscell( content )
         content = {content};
      end
      for si = 1:length( content )
         if strcmpi( type_list{type_ind,1}, content{si} )
            set( handles.nexterrortypemenu, 'value', si )
         end
      end
      guidata( hObject, handles );

      fix_Play( handles, hObject );
      break
   end % found a sequence in undo list that was marked 'correct'
end % for each item in undo list


% --- Executes on button press in savebutton.
function savebutton_Callback(hObject, eventdata, handles)
% hObject    handle to savebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global defaultpath;

if ~isfield(handles,'savename') || isempty(handles.savename),
  [path,defaultfilename] = filenamesplit(handles.moviename);
  defaultfilename = splitext(defaultfilename);
  defaultfilename = ['fixed_',defaultfilename,'.mat'];
  if ~isempty(defaultpath),
    defaultfilename = [defaultpath,defaultfilename];
  end
  [filename,defaultpath] = uiputfile('*.mat','Save FixErrors Progress',defaultfilename);
  handles.savename = [defaultpath,filename];
end

%trx = rmfield(handles.trx,'f2i');
%trx = handles.trx;
trx = fix_FixIgnoredFields(handles);

seqs = handles.seqs;
doneseqs = handles.doneseqs;
moviename = handles.moviename;
seqi = handles.seqi;
params = handles.params;
matname = handles.matname;
save(handles.savename,'trx','seqs','doneseqs','moviename','seqi','params','matname');

handles.needssaving = 0;
guidata(hObject,handles);


% --- Executes on button press in quitbutton.
function quitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to quitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.needssaving
   v = questdlg('Save progress before quitting?','Save?','Yes','No','Yes');
   if strcmpi(v,'yes'),
      savebutton_Callback(handles.savebutton, eventdata, handles);
   end
end
uiresume(handles.figure1);


% --- Executes on button press in undobutton.
function undobutton_Callback(hObject, eventdata, handles)
% hObject    handle to undobutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

top = length( handles.undolist );
if ~isempty( handles.undolist ) && ~iscell( handles.undolist{1} )
   % this happens when there's only one undo item
   % (length is length of that item, not the list)
   top = 1;
end

for ui = top:-1:1
   try
      a = strcmp( handles.undolist{ui}{1}, 'delete' );
   catch % happened once, not replicated
      keyboard
   end
   if strcmp( handles.undolist{ui}{1}, 'delete' )
      fprintf( 1, 'undoing deletion item %d\n', ui );
      f = handles.undolist{ui}{2};
      fly = handles.undolist{ui}{3};
      trk = handles.undolist{ui}{4};
      fly_seqs = handles.undolist{ui}{5};
      
      if isdummytrk( handles.trx(fly) )
         handles.trx(fly) = trk;
         [handles.hellipse(fly), handles.hcenter(fly), handles.hhead(fly),...
            handles.htail(fly), handles.hleft(fly), handles.hright(fly),...
            handles.htailmarker(fly), handles.hpath(fly)] = ...
            InitFly( handles.colors(fly,:) );
         handles = fix_UpdateFlyPathVisible( handles );
      else
         handles.trx(fly) = fix_CatTracks( handles.trx(fly), trk, handles.trajfns );
      end
      
      for si = fly_seqs
         assert( ~isempty( strfindi( handles.seqs(si).type, 'dummy' ) ) );
         handles.seqs(si).type = handles.seqs(si).type(length( 'dummy' ) + 1:end);
      end
      
      handles = fix_FixUpdateFly( handles, fly );
      handles = fix_FixBirthEvent( handles, fly );
      handles = fix_FixDeathEvent( handles, fly );
      
      break
   elseif strcmp( handles.undolist{ui}{1}, 'swap' )
      fprintf( 1, 'undoing swap item %d\n', ui );
      f = handles.undolist{ui}{2};
      fly1 = handles.undolist{ui}{3}(1);
      fly2 = handles.undolist{ui}{3}(2);
      handles = fix_SwapIdentities( handles, f, fly1, fly2, handles.trajfns );

      fix_SetFlySelected(handles,fly1,false);
      fix_SetFlySelected(handles,fly2,false);
      
      break      
   elseif strcmp( handles.undolist{ui}{1}, 'interpolate' ) || ...
          strcmp( handles.undolist{ui}{1}, 'autotrack' )
      fprintf( 1, 'undoing interpolation/autotracking item %d\n', ui );
      if length( handles.undolist{ui} ) == 4
         f0 = handles.undolist{ui}{2}(1);
         f1 = handles.undolist{ui}{2}(2);
         fly = handles.undolist{ui}{3};
         trk = handles.undolist{ui}{4};

         t0 = fix_GetPartOfTrack( handles.trx(fly), 1, f0 - 1, handles.trajfns );
         t2 = fix_GetPartOfTrack( handles.trx(fly), f1 + 1, inf, handles.trajfns );
         handles.trx(fly) = fix_CatTracks( fix_CatTracks( t0, trk, handles.trajfns ), t2, handles.trajfns );

      else
         firstframe = handles.undolist{ui}{2}(1);
         endframe = handles.undolist{ui}{2}(2);
         fly = handles.undolist{ui}{3};
         
         handles.trx(fly) = fix_GetPartOfTrack( handles.trx(fly), firstframe, endframe, handles.trajfns );
         
         handles = fix_FixDeathEvent( handles, fly );
      end
      
      handles = fix_FixUpdateFly( handles, fly );

      break
   elseif strcmp( handles.undolist{ui}{1}, 'connect' )
      fprintf( 1, 'undoing connection item %d\n', ui );
      f1 = handles.undolist{ui}{2}(1);
      f2 = handles.undolist{ui}{2}(2);
      fly1 = handles.undolist{ui}{3}(1);
      fly2 = handles.undolist{ui}{3}(2);
      trk1 = handles.undolist{ui}{4}(1);
      trk2 = handles.undolist{ui}{4}(2);
      seqs_removed1 = handles.undolist{ui}{5};
      seqs_removed2 = handles.undolist{ui}{6};

      first_trk1 = fix_GetPartOfTrack( handles.trx(fly1), 1, f1, handles.trajfns );
      last_trk2 = fix_GetPartOfTrack( handles.trx(fly1), f2, inf, handles.trajfns );

      handles.trx(fly1) = fix_CatTracks( first_trk1, trk1, handles.trajfns );
      handles = fix_FixUpdateFly( handles, fly1 );
      handles = fix_FixDeathEvent( handles, fly1 );
      for si = seqs_removed1
         assert( ~isempty( strfindi( handles.seqs(si).type, 'dummy' ) ) );
         handles.seqs(si).type = handles.seqs(si).type(length( 'dummy' ) + 1:end);
      end

      handles.trx(fly2) = fix_CatTracks( trk2, last_trk2, handles.trajfns );
      [handles.hellipse(fly2), handles.hcenter(fly2), handles.hhead(fly2), ...
         handles.htail(fly2), handles.hleft(fly2), handles.hright(fly2), ...
         handles.htailmarker(fly2), handles.hpath(fly2)] = ...
         InitFly( handles.colors(fly2,:) );
      handles = fix_UpdateFlyPathVisible( handles );
      handles = fix_FixUpdateFly( handles, fly2 );
      handles = fix_FixBirthEvent( handles, fly2 );
      handles = fix_FixDeathEvent( handles, fly2 );
      for si = seqs_removed2
         assert( ~isempty( strfindi( handles.seqs(si).type, 'dummy' ) ) );
         handles.seqs(si).type = handles.seqs(si).type(length( 'dummy' ) + 1:end);
      end

      break
   elseif strcmp( handles.undolist{ui}{1}, 'flip' )
      fprintf( 1, 'undoing flip item %d\n', ui );
      frame = handles.undolist{ui}{2};
      f = handles.undolist{ui}{3};
      fly = handles.undolist{ui}{4};

      fix_SetFlySelected(handles,fly,false);
      for f = frame:f,
         i = handles.trx(fly).off+(f);
         handles.trx(fly).theta(i) = modrange(handles.trx(fly).theta(i)+pi,-pi,pi);
      end
      handles = fix_FixUpdateFly(handles,fly);
      
      break
   elseif strcmp( handles.undolist{ui}{1}, 'manytrack' )
      fprintf( 1, 'undoing manytrack item %d\n', ui );

      f0 = handles.undolist{ui}{2}(1);
      f1 = handles.undolist{ui}{2}(2);
      flies = handles.undolist{ui}{3};
      oldtrx = handles.undolist{ui}{4};

      for fi = 1:length( flies )
         fly = flies(fi);
         t0 = fix_GetPartOfTrack( handles.trx(fly), 1, f0 - 1, handles.trajfns );
         t2 = fix_GetPartOfTrack( handles.trx(fly), f1 + 1, inf, handles.trajfns );
         handles.trx(fly) = fix_CatTracks( fix_CatTracks( t0, oldtrx(fi), handles.trajfns ), t2, handles.trajfns );
      end
         
      for fly = flies
         handles = fix_FixUpdateFly( handles, fly );
      end

      break
   elseif strcmp( handles.undolist{ui}{1}, 'addnew' )
      fprintf( 1, 'undoing addnewtrack item %d\n', ui );
      
      fly = handles.undolist{ui}{2};

      fix_DeleteFly( handles, fly );
      
      break
   elseif strcmp( handles.undolist{ui}{1}, 'superpose' )
      fprintf( 1, 'undoing superposetrack item %d\n', ui )
      
      fly = handles.undolist{ui}{2};
      f0 = handles.undolist{ui}{3};
      f1 = handles.undolist{ui}{4};
      trk = handles.undolist{ui}{5};

      t0 = fix_GetPartOfTrack( handles.trx(fly), 1, f0 - 1, handles.trajfns );
      t2 = fix_GetPartOfTrack( handles.trx(fly), f1 + 1, inf, handles.trajfns );
      handles.trx(fly) = fix_CatTracks( fix_CatTracks( t0, trk ), t2, handles.trajfns );

      fix_FixUpdateFly( handles, fly );

      break
   elseif ~strcmp( handles.undolist{ui}{1}, 'correct' )
      warning( 'don''t know how to undo action ''%s'', item %d\n', handles.undolist{ui}{1}, ui );
   end
end

% remove undone item from undo list
if ui == 1
   if length( handles.undolist ) == 1
      handles.undolist = {};
   else
      handles.undolist = handles.undolist{2:end};
   end
elseif ui == length( handles.undolist )
   handles.undolist(end) = [];
elseif ui > 0
   try % untested
      handles.undolist = handles.undolist{[1:ui-1 ui+1:length( handles.undolist )]};
   catch err
      keyboard
      handles.undolist
      ui
      handles.seq
      rethrow( err )
   end
end

handles.nselect = 0;
handles.selected = [];
handles.needssaving = 1;
guidata(hObject,handles);


% --- Executes on button press in deletedoitbutton.
function deletedoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to deletedoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty( handles.selected )|| handles.selected == 0,
  errordlg('You must first select a fly track to delete. See Delete Track Instructions Panel',...
    'No Fly Selected');
  return;
end

fly = handles.selected;
if handles.f <= handles.trx(fly).firstframe,
  handles.undolist{end+1} = {'delete',handles.f,fly,...
    handles.trx(fly)};
  handles = fix_DeleteFly(handles,fly);
  % remove events involving this fly
  [handles, evts_removed] = fix_RemoveFlyEvent(handles,fly,-inf,inf);
else  
   handles.undolist{end+1} = {'delete',handles.f,fly,...
      fix_GetPartOfTrack(handles.trx(fly),handles.f,inf,handles.trajfns)};
  handles.trx(fly) = fix_GetPartOfTrack(handles.trx(fly),1,handles.f-1,handles.trajfns);
  % remove events involving this fly in the deleted interval
  [handles, evts_removed] = fix_RemoveFlyEvent(handles,fly,handles.f,inf);
  fix_SetFlySelected(handles,fly,false);
  fix_FixUpdateFly(handles,fly);
end
handles.undolist{end}{end+1} = evts_removed;

handles.nselect = 0;
handles.selected = [];
handles.needssaving = 1;
fix_EnablePanel(handles.editpanel,'on');
set(handles.deletepanel,'visible','off');
guidata(hObject,handles);


% --- Executes on button press in deletecancelbutton.
function deletecancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to deletecancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

fix_ActionCancelled( hObject, handles, handles.deletepanel )


% --- Executes on button press in renamedoitbutton.
function renamedoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to renamedoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if length(handles.selected) ~= 2,
    errordlg('You must first select the two flies two swap. See Swap Identities Instructions Panel',...
    'Bad Selection');
  return;
end

fly1 = handles.selected(1);
fly2 = handles.selected(2);
f = handles.f;

if ~isalive(handles.trx(fly1),f) || ~isalive(handles.trx(fly2),f),
  errordlg('Both flies must be alive in the selected frame.',...
    'Bad Selection');
  return;
end

handles = fix_SwapIdentities( handles, f, fly1, fly2, handles.trajfns );
handles.undolist{end+1} = {'swap',f,[fly1,fly2]};

fix_SetFlySelected(handles,fly1,false);
fix_SetFlySelected(handles,fly2,false);
handles.nselect = 0;
handles.selected = [];
set(handles.swappanel,'visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);


% --- Executes on button press in renamecancelbutton.
function renamecancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to renamecancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

fix_ActionCancelled( hObject, handles, handles.swappanel )


% --- Executes on mouse press over axes background.
function mainaxes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to mainaxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

uiresume(handles.figure1);

% Hint: delete(hObject) closes the figure
%delete(hObject);


% --- Executes on button press in debugbutton.
function debugbutton_Callback(hObject, eventdata, handles)
% hObject    handle to debugbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
keyboard;


% --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles,'motionobj') || isempty(handles.motionobj), return; end

if strcmpi(handles.motionobj{1},'center'),
  handles = move_center(handles.motionobj{2},handles);
elseif strcmpi(handles.motionobj{1},'head'),
  handles = move_head(handles.motionobj{2},handles);
elseif strcmpi(handles.motionobj{1},'tail'),
  handles = move_tail(handles.motionobj{2},handles);
elseif strcmpi(handles.motionobj{1},'left'),
  handles = move_left(handles.motionobj{2},handles);
elseif strcmpi(handles.motionobj{1},'right'),
  handles = move_right(handles.motionobj{2},handles);
end

guidata(hObject,handles);

% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonUpFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.motionobj = [];
guidata(hObject,handles);


% --- Executes on selection change in editmenu.
function editmenu_Callback(hObject, eventdata, handles)
% hObject    handle to editmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns editmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from editmenu


% --- Executes during object creation, after setting all properties.
function editmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on button press in gobutton.
function gobutton_Callback(hObject, eventdata, handles)
% hObject    handle to gobutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% what are we doing?
contents = get(handles.editmenu,'string');
s = contents{get(handles.editmenu,'value')};
fix_EnablePanel(handles.editpanel,'off');
handles.nselect = 1;
handles.selected = [];
if strcmpi(s,'delete track...'),
  set(handles.deletepanel,'visible','on');
elseif strcmpi(s,'interpolate...'),
  set(handles.interpolatepanel,'visible','on');
  handles.interpolatefirstframe = -1;
  set(handles.interpolatedoitbutton,'enable','off');
elseif strcmpi(s,'connect tracks...'),
  set(handles.connectpanel,'visible','on');
  handles.connectfirstframe = -1;
  handles.connectfirstfly = -1;
  set(handles.connectdoitbutton,'enable','off');
elseif strcmpi(s,'swap identities...')
  set(handles.swappanel,'visible','on');
  handles.nselect = 2;
elseif strcmpi(s,'extend track...'),
  set(handles.extendpanel,'visible','on');
  handles.extendfirstframe = -1;
  set(handles.extenddoitbutton,'enable','off');
elseif strcmpi(s,'auto-track...'),
  set(handles.autotrackpanel,'visible','on');
  handles.autotrackframe = -1;
  set(handles.autotrackdoitbutton,'enable','off');
  set(handles.autotracksettingsbutton,'enable','off');
elseif strcmpi(s,'flip orientation...'),
  set(handles.flippanel,'visible','on');
  handles.flipframe = -1;
  set(handles.flipdoitbutton,'enable','off');
elseif strcmpi(s,'auto-track multiple...'),
  set(handles.manytrackpanel,'visible','on');
  handles.nselect = handles.nflies;
  handles.manytrackframe = -1;
  set(handles.manytrackdoitbutton,'enable','off');
  set(handles.manytracksettingsbutton,'enable','off');
elseif strcmpi( s, 'add new track...' )
   set( handles.addnewtrackpanel, 'visible', 'on' );
   set( handles.addnewtrackdoitbutton, 'enable', 'on' );
elseif strcmpi( s, 'superpose tracks...' )
   set( handles.superposetrackspanel, 'visible', 'on' );
   handles.nselect = 1;
   handles.superposefirstframe = -1;
   handles.superposefirstfly = -1;
   set( handles.superposedoitbutton, 'visible', 'off' );
   set( handles.superposefirstflybutton, 'visible', 'on' );
else
   fprintf( 1, 'unknown action selected: %s\n', s )
end
guidata(hObject,handles);


% --- Executes on selection change in seekmenu.
function seekmenu_Callback(hObject, eventdata, handles)
% hObject    handle to seekmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns seekmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from seekmenu


% --- Executes during object creation, after setting all properties.
function seekmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to seekmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on button press in previousbutton.
function previousbutton_Callback(hObject, eventdata, handles)
% hObject    handle to previousbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

value = get(handles.seekmenu,'value');
contents = get(handles.seekmenu,'string');
s = contents{value};

if strcmpi(s,'birth nearby'),
  
  nextnearbirth = -1;
  nextnearframe = -inf;
  xlim = get(handles.mainaxes,'xlim');
  ylim = get(handles.mainaxes,'ylim');
  for i = 1:length(handles.seqs),
    if ~strcmpi(handles.seqs(i).type,'birth'),
      continue;
    end
    f = handles.seqs(i).frames;
    if f >= handles.f, 
      continue;
    end
    fly = handles.seqs(i).flies;
    j = handles.trx(fly).off+(f);
    x = handles.trx(fly).x(j);
    y = handles.trx(fly).y(j);
    if x >= xlim(1) && x <= xlim(2) && y >= ylim(1) && y <= ylim(2),
      if nextnearframe < f,
        nextnearbirth = i;
        nextnearframe = f;
      end
    end
  end
  
  if nextnearbirth == -1,
    msgbox('Sorry! There are no fly births in the current axes before the current frame.',...
      'Could Not Find Birth');
    return;
  end
  
  handles.lastframe = handles.f;
  handles.f = nextnearframe;
  fix_SetFrameNumber(handles,hObject);
  fix_PlotFrame(handles);
  
  guidata(hObject,handles);
  
elseif strcmpi(s,'death nearby'),
  
  nextneardeath = -1;
  nextnearframe = -inf;
  xlim = get(handles.mainaxes,'xlim');
  ylim = get(handles.mainaxes,'ylim');
  for i = 1:length(handles.seqs),
    if ~strcmpi(handles.seqs(i).type,'death'),
      continue;
    end
    f = handles.seqs(i).frames;
    if f >= handles.f, 
      continue;
    end
    fly = handles.seqs(i).flies;
    j = handles.trx(fly).off+(f);
    x = handles.trx(fly).x(j);
    y = handles.trx(fly).y(j);
    if x >= xlim(1) && x <= xlim(2) && y >= ylim(1) && y <= ylim(2),
      if nextnearframe < f,
        nextneardeath = i;
        nextnearframe = f;
      end
    end
  end
  
  if nextneardeath == -1,
    msgbox('Sorry! There are no fly deaths in the current axes before the current frame.',...
      'Could Not Find Death');
    return;
  end
  
  handles.lastframe = handles.f;
  handles.f = nextnearframe;
  fix_SetFrameNumber(handles,hObject);
  fix_PlotFrame(handles);
  
  guidata(hObject,handles);
  
end

% --- Executes on button press in nextbutton.
function nextbutton_Callback(hObject, eventdata, handles)
% hObject    handle to nextbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

value = get(handles.seekmenu,'value');
contents = get(handles.seekmenu,'string');
s = contents{value};

if strcmpi(s,'birth nearby'),
  
  nextnearbirth = -1;
  nextnearframe = inf;
  xlim = get(handles.mainaxes,'xlim');
  ylim = get(handles.mainaxes,'ylim');
  for i = 1:length(handles.seqs),
    if ~strcmpi(handles.seqs(i).type,'birth'),
      continue;
    end
    f = handles.seqs(i).frames;
    if f <= handles.f, 
      continue;
    end
    fly = handles.seqs(i).flies;
    j = handles.trx(fly).off+(f);
    x = handles.trx(fly).x(j);
    y = handles.trx(fly).y(j);
    if x >= xlim(1) && x <= xlim(2) && y >= ylim(1) && y <= ylim(2),
      if nextnearframe > f,
        nextnearbirth = i;
        nextnearframe = f;
      end
    end
  end
  
  if nextnearbirth == -1,
    msgbox('Sorry! There are no fly births in the current axes after the current frame.',...
      'Could Not Find Birth');
    return;
  end
  
  handles.lastframe = handles.f;
  handles.f = nextnearframe;
  fix_SetFrameNumber(handles,hObject);
  fix_PlotFrame(handles);
  
  guidata(hObject,handles);
  
elseif strcmpi(s,'death nearby'),
  
  nextneardeath = -1;
  nextnearframe = inf;
  xlim = get(handles.mainaxes,'xlim');
  ylim = get(handles.mainaxes,'ylim');
  for i = 1:length(handles.seqs),
    if ~strcmpi(handles.seqs(i).type,'death'),
      continue;
    end
    f = handles.seqs(i).frames;
    if f <= handles.f, 
      continue;
    end
    fly = handles.seqs(i).flies;
    j = handles.trx(fly).off+(f);
    x = handles.trx(fly).x(j);
    y = handles.trx(fly).y(j);
    if x >= xlim(1) && x <= xlim(2) && y >= ylim(1) && y <= ylim(2),
      if nextnearframe > f,
        nextneardeath = i;
        nextnearframe = f;
      end
    end
  end
  
  if nextneardeath == -1,
    msgbox('Sorry! There are no fly deaths in the current axes after the current frame.',...
      'Could Not Find Death');
    return;
  end
  
  handles.lastframe = handles.f;
  handles.f = nextnearframe;
  fix_SetFrameNumber(handles,hObject);
  fix_PlotFrame(handles);
  
  guidata(hObject,handles);
  
end


% --- Executes on selection change in plotpathmenu.
function plotpathmenu_Callback(hObject, eventdata, handles)
% hObject    handle to plotpathmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns plotpathmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from plotpathmenu
handles = fix_UpdateFlyPathVisible(handles);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function plotpathmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plotpathmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


function nframesplotedit_Callback(hObject, eventdata, handles)
% hObject    handle to nframesplotedit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nframesplotedit as text
%        str2double(get(hObject,'String')) returns contents of nframesplotedit as a double
v = str2double(get(hObject,'string'));
if isempty(v), 
  set(hObject,'string',num2str(handles.f));
else
  handles.nframesplot = v;
  for fly = 1:handles.nflies,
    fix_FixUpdateFly(handles,fly);
  end
end
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function nframesplotedit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nframesplotedit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on selection change in zoommenu.
function zoommenu_Callback(hObject, eventdata, handles)
% hObject    handle to zoommenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns zoommenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from zoommenu
contents = get(hObject,'String');
s = contents{get(hObject,'Value')};
if strcmpi(handles.zoommode,s),
  return;
end
handles.zoommode = s;
if strcmpi(s,'whole arena'),
  xlim = [1,handles.nc];
  ylim = [1,handles.nr];
  % match aspect ratio
  [xlim,ylim] = match_aspect_ratio(xlim,ylim,handles);
  set(handles.mainaxes,'xlim',xlim,'ylim',ylim);
else
  fix_ZoomInOnSeq(handles);
end
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function zoommenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoommenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
fix_SetCreatedObjectBgColor( hObject, 'white' );


% --- Executes on button press in interpolatedoitbutton.
function interpolatedoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to interpolatedoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isalive(handles.trx(handles.interpolatefly),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end

fix_SetFlySelected(handles,handles.interpolatefly,false);
handles.selected = [];

f0 = handles.interpolatefirstframe;
f1 = handles.f;
if f0 > f1,
  tmp = f0; f0 = f1; f1 = tmp;
end
fly = handles.interpolatefly;

% save to undo list
handles.undolist{end+1} = {'interpolate',[f0,f1],fly,...
  fix_GetPartOfTrack(handles.trx(fly),f0,f1,handles.trajfns)};

% interpolate between f0 and f1
i0 = handles.trx(fly).off+(f0);
i1 = handles.trx(fly).off+(f1);
nframesinterp = f1-f0+1;

for fni = 1:numel(handles.trajfns),
  fn = handles.trajfns{fni};
  if strcmpi(fn,'theta'),
    continue;
  end
  x0 = handles.trx(fly).(fn)(i0);
  x1 = handles.trx(fly).(fn)(i1);
  handles.trx(fly).(fn)(i0:i1) = linspace(x0,x1,nframesinterp);
end
  
% x0 = handles.trx(fly).x(i0);
% y0 = handles.trx(fly).y(i0);
% a0 = handles.trx(fly).a(i0);
% b0 = handles.trx(fly).b(i0);
theta0 = handles.trx(fly).theta(i0);
% x1 = handles.trx(fly).x(i1);
% y1 = handles.trx(fly).y(i1);
% a1 = handles.trx(fly).a(i1);
% b1 = handles.trx(fly).b(i1);
theta1 = handles.trx(fly).theta(i1);
% handles.trx(fly).x(i0:i1) = linspace(x0,x1,nframesinterp);
% handles.trx(fly).y(i0:i1) = linspace(y0,y1,nframesinterp);
% handles.trx(fly).a(i0:i1) = linspace(a0,a1,nframesinterp);
% handles.trx(fly).b(i0:i1) = linspace(b0,b1,nframesinterp);

dtheta = modrange(theta1-theta0,-pi,pi);
thetainterp = linspace(0,dtheta,nframesinterp)+theta0;
handles.trx(fly).theta(i0:i1) = modrange(thetainterp,-pi,pi);

delete(handles.hinterpolate);
set(handles.interpolatefirstframebutton,'string','First Frame','Enable','on');
set(handles.interpolatedoitbutton,'enable','off');
set(handles.interpolatepanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly(handles,fly);


% --- Executes on button press in cancelinterpolatebutton.
function cancelinterpolatebutton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelinterpolatebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'hinterpolate') && ishandle(handles.hinterpolate),
  delete(handles.hinterpolate);
end
if isfield(handles,'interpolatefly'),
  fix_SetFlySelected(handles,handles.interpolatefly,false);
end
set(handles.interpolatefirstframebutton,'string','First Frame','Enable','on');
set(handles.interpolatedoitbutton,'enable','off');
fix_ActionCancelled( hObject, handles, handles.interpolatepanel )


% --- Executes on button press in interpolatefirstframebutton.
function interpolatefirstframebutton_Callback(hObject, eventdata, handles)
% hObject    handle to interpolatefirstframebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to interpolate first.','No Fly Selected');
  return;
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end
handles.interpolatefly = handles.selected;
handles.nselect = 0;
handles.selected = [];
handles.interpolatefirstframe = handles.f;
set(handles.interpolatedoitbutton,'enable','on');
set(handles.interpolatefirstframebutton,'enable','off');
set(handles.interpolatefirstframebutton,'string',sprintf('First = %d',handles.f));

% draw the fly
fly = handles.interpolatefly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hinterpolate = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hinterpolate,'color',color*.75,'linewidth',3,'linestyle','--',...
  'hittest','off');

guidata(hObject,handles);


% --- Executes on button press in interpolatefirstframebutton.
function extendfirstflybutton_Callback(hObject, eventdata, handles)
% hObject    handle to interpolatefirstframebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to extend first.','No Fly Selected');
  return;
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end
handles.extendfly = handles.selected;
handles.nselect = 0;
handles.selected = [];
set(handles.extenddoitbutton,'enable','on');
set(handles.extendfirstflybutton,'enable','off');

% draw the fly
fly = handles.extendfly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hextend = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hextend,'color',color*.75,'linewidth',3,'linestyle','--',...
  'hittest','off');

guidata(hObject,handles);


% --- Executes on button press in connectdoitbutton.
function connectdoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to connectdoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to connect first.','No Fly Selected');
  return;
end

fly2 = handles.selected;

if ~isalive(handles.trx(fly2),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end

fix_SetFlySelected(handles,handles.connectfirstfly,false);
fix_SetFlySelected(handles,fly2,false);
handles.selected = [];
handles.nselect = 0;

f1 = handles.connectfirstframe;
f2 = handles.f;
fly1 = handles.connectfirstfly;

if f1 > f2,
  tmp = f1; f1 = f2; f2 = tmp;
  tmp = fly1; fly1 = fly2; fly2 = tmp;
end

% save to undo list
handles.undolist{end+1} = {'connect',[f1,f2],[fly1,fly2],...
  [fix_GetPartOfTrack(handles.trx(fly1),f1+1,inf,handles.trajfns),...
  fix_GetPartOfTrack(handles.trx(fly2),1,f2-1,handles.trajfns)], [], [], handles.trajfns};

% interpolate between f1 and f2
i1 = handles.trx(fly1).off+(f1);
i2 = handles.trx(fly2).off+(f2);
nframesinterp = f2-f1+1;
xinterp = struct;
for fni = 1:numel(handles.trajfns),
  fn = handles.trajfns{fni};
  x1 = handles.trx(fly1).(fn)(i1);
  x2 = handles.trx(fly1).(fn)(i2);
  if strcmp(fn,'theta'),
    dtheta = modrange(x2-x1,-pi,pi);
    xinterp.(fn) = modrange(linspace(0,dtheta,nframesinterp)+x1,-pi,pi);
  else
    xinterp.(fn) = linspace(x1,x2,nframesinterp);
  end
end
% x1 = handles.trx(fly1).x(i1);
% y1 = handles.trx(fly1).y(i1);
% a1 = handles.trx(fly1).a(i1);
% b1 = handles.trx(fly1).b(i1);
% theta1 = handles.trx(fly1).theta(i1);
% x2 = handles.trx(fly2).x(i2);
% y2 = handles.trx(fly2).y(i2);
% a2 = handles.trx(fly2).a(i2);
% b2 = handles.trx(fly2).b(i2);
% theta2 = handles.trx(fly2).theta(i2);
if isfield( handles.trx, 'timestamps' )
   ts1 = handles.trx(fly1).timestamps(i1);
   ts2 = handles.trx(fly2).timestamps(i2);
end

% xinterp = linspace(x1,x2,nframesinterp);
% yinterp = linspace(y1,y2,nframesinterp);
% ainterp = linspace(a1,a2,nframesinterp);
% binterp = linspace(b1,b2,nframesinterp);
% dtheta = modrange(theta2-theta1,-pi,pi);
% thetainterp = modrange(linspace(0,dtheta,nframesinterp)+theta1,-pi,pi);
if isfield( handles.trx, 'timestamps' )
   tsinterp = linspace( ts1, ts2, nframesinterp );
end

% will we need to cut?
f3 = handles.trx(fly2).endframe;
if f3 < handles.trx(fly1).endframe,
  % if fly1 outlives fly2, then delete all of fly1 after death of fly2
  handles.trx(fly1) = fix_GetPartOfTrack(handles.trx(fly1),1,f3,handles.trajfns);
  % delete events involving fly1 in frames f3 and after
  [handles, seqs_removed] = fix_RemoveFlyEvent(handles,fly1,f3+1,inf);
  handles.undolist{end}{end-1} = seqs_removed;
elseif f3 > handles.trx(fly1).endframe,
  % we will need to append track
  nappend = f3 - handles.trx(fly1).endframe;
  for fni = 1:numel(handles.trajfns),
    fn = handles.trajfns{fni};
    handles.trx(fly1).(fn)(end+1:end+nappend) = 0;
  end
%   handles.trx(fly1).x(end+1:end+nappend) = 0;
%   handles.trx(fly1).y(end+1:end+nappend) = 0;
%   handles.trx(fly1).a(end+1:end+nappend) = 0;
%   handles.trx(fly1).b(end+1:end+nappend) = 0;
%   handles.trx(fly1).theta(end+1:end+nappend) = 0;
  if isfield( handles.trx, 'timestamps' )
     handles.trx(fly1).timestamps(end+1:end+nappend) = 0;
  end
  handles.trx(fly1).nframes = handles.trx(fly1).nframes+nappend;
  handles.trx(fly1).endframe = f3;
end

% copy over the interpolation
idx = i1:handles.trx(fly1).off+(f2);
for fni = 1:numel(handles.trajfns),
  fn = handles.trajfns{fni};
  handles.trx(fly1).(fn)(idx) = xinterp.(fn);
end
% handles.trx(fly1).x(idx) = xinterp;
% handles.trx(fly1).y(idx) = yinterp;
% handles.trx(fly1).a(idx) = ainterp;
% handles.trx(fly1).b(idx) = binterp;
% handles.trx(fly1).theta(idx) = thetainterp;
if isfield( handles.trx, 'timestamps' )
   handles.trx(fly1).timestamps(idx) = tsinterp;
end

% copy over fly2
idx1 = handles.trx(fly1).off+(f2):handles.trx(fly1).off+(f3);
idx2 = handles.trx(fly2).off+(f2):handles.trx(fly2).off+(f3);
for fni = 1:numel(handles.trajfns),
  fn = handles.trajfns{fni};
  handles.trx(fly1).(fn)(idx1) = handles.trx(fly2).(fn)(idx2);
end
% handles.trx(fly1).x(idx1) = handles.trx(fly2).x(idx2);
% handles.trx(fly1).y(idx1) = handles.trx(fly2).y(idx2);
% handles.trx(fly1).a(idx1) = handles.trx(fly2).a(idx2);
% handles.trx(fly1).b(idx1) = handles.trx(fly2).b(idx2);
% handles.trx(fly1).theta(idx1) = handles.trx(fly2).theta(idx2);
if isfield( handles.trx, 'timestamps' )
   handles.trx(fly1).timestamps(idx1) = handles.trx(fly2).timestamps(idx2);
end

% delete fly
handles = fix_DeleteFly(handles,fly2);
% replace fly2 with fly1 for frames f2 thru f3
handles = ReplaceFlyEvent(handles,fly2,fly1,f2,f3);
[handles, seqs_removed] = fix_RemoveFlyEvent(handles,fly2,-inf,inf);
handles.undolist{end}{end} = seqs_removed;
handles = fix_FixDeathEvent(handles,fly1);

delete(handles.hconnect);
set(handles.connectfirstflybutton,'string','First Fly','Enable','on');
set(handles.connectdoitbutton,'enable','off');
set(handles.connectpanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly(handles,fly1);


function handles = ReplaceFlyEvent(handles,fly0,fly1,f0,f1)
% replace appearances of fly0 with fly1 in sequences between frames f0 and f1
% don't know why this is commented out... it seems important JAB 9/30/11
% though it also seems like it should test && ~ismember(fly1), too
%for i = 1:length(handles.seqs)
%  if ismember(fly0,handles.seqs(i).flies) && f0 <= min(handles.seqs(i).frames) && ...
%      f1 >= max(handles.seqs(i).frames)
%    handles.seqs(i).flies = union(setdiff(handles.seqs(i).flies,fly0),fly1);
%  end
%end


% --- Executes on button press in connectcancelbutton.
function connectcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to connectcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'connectfirstfly') && handles.connectfirstfly > 0,
  fix_SetFlySelected(handles,handles.connectfirstfly,false);
end
if isfield(handles,'hconnect') && ishandle(handles.hconnect),
  delete(handles.hconnect);
end
set(handles.connectfirstflybutton,'enable','on','string','First Fly');
fix_ActionCancelled( hObject, handles, handles.connectpanel )


% --- Executes on button press in connectfirstflybutton.
function connectfirstflybutton_Callback(hObject, eventdata, handles)
% hObject    handle to connectfirstflybutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to connect first.','No Fly Selected');
  return;
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end
handles.connectfirstfly(end) = handles.selected;
handles.nselect = 1;
handles.selected = [];
handles.connectfirstframe = handles.f;
set(handles.connectdoitbutton,'enable','on');
set(handles.connectfirstflybutton,'enable','off');
set(handles.connectfirstflybutton,'string',sprintf('First = %d',handles.f));

% draw the fly
fly = handles.connectfirstfly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hconnect = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hconnect,'color',color*.75,'linewidth',3,'linestyle','--',...
  'hittest','off');

guidata(hObject,handles);


% --- Executes on button press in playstopbutton.
function playstopbutton_Callback(hObject, eventdata, handles)
% hObject    handle to playstopbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if strcmpi(get(hObject,'string'),'play'),
  fix_Play(handles,hObject);
else
  handles.isplaying = false;
  guidata(hObject,handles);
end


% --- Executes on button press in extenddoitbutton.
function extenddoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to extenddoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isalive(handles.trx(handles.extendfly),handles.f),
  errordlg('Selected fly is alive in current frame!','Bad Selection');
  return;
end

fix_SetFlySelected(handles,handles.extendfly,false);
handles.selected = [];

f = handles.f;
fly = handles.extendfly;

% save to undo list
handles.undolist{end+1} = {'interpolate',[handles.trx(fly).firstframe,handles.trx(fly).endframe],fly};

% extend
if f < handles.trx(fly).firstframe,
  n = handles.trx(fly).firstframe - f;
  for fni = 1:numel(handles.trajfns),
    fn = handles.trajfns{fni};
    handles.trx(fly).(fn) = [zeros(1,n),handles.trx(fly).(fn)];
  end
    
%   handles.trx(fly).x = [zeros(1,n),handles.trx(fly).x];
%   handles.trx(fly).y = [zeros(1,n),handles.trx(fly).y];
%   handles.trx(fly).a = [zeros(1,n),handles.trx(fly).a];
%   handles.trx(fly).b = [zeros(1,n),handles.trx(fly).b];
%   handles.trx(fly).theta = [zeros(1,n),handles.trx(fly).theta];
  for fni = 1:numel(handles.trajfns),
    fn = handles.trajfns{fni};
    handles.trx(fly).(fn)(1:n) = handles.trx(fly).(fn)(n+1);
  end
%   handles.trx(fly).x(1:n) = handles.trx(fly).x(n+1);
%   handles.trx(fly).y(1:n) = handles.trx(fly).y(n+1);
%   handles.trx(fly).a(1:n) = handles.trx(fly).a(n+1);
%   handles.trx(fly).b(1:n) = handles.trx(fly).b(n+1);
%   handles.trx(fly).theta(1:n) = handles.trx(fly).theta(n+1);
  handles.trx(fly).firstframe = f;
  handles.trx(fly).off = -handles.trx(fly).firstframe + 1;
  if isfield( handles.trx, 'timestamps' )
     if isfield( handles, 'timestamps' )
        handles.trx(fly).timestamps = [handles.timestamps(1:n), handles.trx(fly).timestamps];
     else
        handles.trx(fly).timestamps = [ones(1,n).*handles.trx(fly).timestamps(1), handles.trx(fly).timestamps];
     end
  end
  if ~all( size( handles.trx(fly).timestamps ) == size( handles.trx(fly).x ) )
     keyboard
  end
  %handles.trx(fly).f2i = @(f) f - handles.trx(fly).firstframe + 1;
  handles.trx(fly).nframes = length(handles.trx(fly).x);
  % move the death event
  handles = fix_FixDeathEvent(handles,fly);
else
  n = f - handles.trx(fly).endframe; % n frames to add
  for fni = 1:numel(handles.trajfns),
    fn = handles.trajfns{fni};
    handles.trx(fly).(fn) = [handles.trx(fly).(fn), zeros(1,n)];
  end

%   handles.trx(fly).x = [handles.trx(fly).x, zeros(1,n)];
%   handles.trx(fly).y = [handles.trx(fly).y, zeros(1,n)];
%   handles.trx(fly).a = [handles.trx(fly).a, zeros(1,n)];
%   handles.trx(fly).b = [handles.trx(fly).b, zeros(1,n)];
%   handles.trx(fly).theta = [handles.trx(fly).theta, zeros(1,n)];
  if isfield( handles.trx, 'timestamps' )
     handles.trx(fly).timestamps = [handles.trx(fly).timestamps, zeros(1,n)];
  end
  for fni = 1:numel(handles.trajfns),
    fn = handles.trajfns{fni};
    handles.trx(fly).(fn)(end-n+1:end) = handles.trx(fly).(fn)(end-n);
  end
%   handles.trx(fly).x(end-n+1:end) = handles.trx(fly).x(end-n);
%   handles.trx(fly).y(end-n+1:end) = handles.trx(fly).y(end-n);
%   handles.trx(fly).a(end-n+1:end) = handles.trx(fly).a(end-n);
%   handles.trx(fly).b(end-n+1:end) = handles.trx(fly).b(end-n);
%   handles.trx(fly).theta(end-n+1:end) = handles.trx(fly).theta(end-n);
  if isfield( handles.trx, 'timestamps' )
     if isfield( handles, 'timestamps' )
        handles.trx(fly).timestamps(end-n+1:end) = handles.timestamps(handles.trx(fly).endframe+1:f);
     else
        handles.trx(fly).timestamps(end-n+1:end) = handles.trx(fly).timestamps(end-n) + (1:n)*(handles.trx(fly).timestamps(2) - handles.trx(fly).timestamps(1));
     end
  end
  if ~all( size( handles.trx(fly).timestamps ) == size( handles.trx(fly).x ) )
     keyboard
  end
  handles.trx(fly).nframes = length(handles.trx(fly).x);
  handles.trx(fly).endframe = f;
  % move the death event
  handles = fix_FixDeathEvent(handles,fly);
end

delete(handles.hextend);
set(handles.extendfirstflybutton,'Enable','on');
set(handles.extenddoitbutton,'enable','off');
set(handles.extendpanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly(handles,fly);


% --- Executes on button press in extendcancelbutton.
function extendcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to extendcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'hextend') && ishandle(handles.hextend),
  delete(handles.hextend);
end
if isfield(handles,'extendfly'),
  fix_SetFlySelected(handles,handles.extendfly,false);
end
set(handles.extendfirstflybutton,'Enable','on');
set(handles.extenddoitbutton,'enable','off');
fix_ActionCancelled( hObject, handles, handles.extendpanel )


% --- Executes on button press in autotrackdoitbutton.
function autotrackdoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to autotrackdoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

f0 = min(handles.f,handles.autotrackframe);
f1 = max(handles.f,handles.autotrackframe);

fix_SetFlySelected(handles,handles.autotrackfly,false);
handles.selected = [];

fly = handles.autotrackfly;

% save to undo list
handles.undolist{end+1} = {'autotrack',[f0,f1],fly,fix_GetPartOfTrack(handles.trx(fly),f0,f1,handles.trajfns)};

set(handles.autotrackcancelbutton,'string','Stop');
set(handles.autotrackdoitbutton,'enable','off');
handles.stoptracking = false;

% track
seq.flies = fly;
seq.frames = f0:min(f1,handles.trx(fly).endframe);
if get(handles.showtrackingbutton,'value')
  fix_ZoomInOnSeq(handles,seq);
end
handles.stoptracking = false;
handles = fix_FixTrackFlies([fly],f0,f1,handles);

if isfield( handles, 'trackingstoppedframe' )
%    handles.f = handles.trackingstopped;
   handles = rmfield( handles, 'trackingstoppedframe' );

%    fix_SetFrameNumber( handles, hobject );
%    fix_PlotFrame( handles );
end

handles = fix_FixDeathEvent(handles,fly);

delete(handles.hautotrack);
set(handles.autotrackcancelbutton,'string','Cancel');
set(handles.autotrackfirstframebutton,'Enable','on');
set(handles.autotrackdoitbutton,'enable','off');
set(handles.autotrackpanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly(handles,fly);


% --- Executes on button press in autotrackcancelbutton.
function autotrackcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to autotrackcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if strcmpi(get(handles.autotrackcancelbutton,'string'),'stop')
  handles.stoptracking = true;
else
  if isfield(handles,'hautotrack') && ishandle(handles.hautotrack),
    delete(handles.hautotrack);
  end
  if isfield(handles,'autotrackfly'),
    fix_SetFlySelected(handles,handles.autotrackfly,false);
  end
  set(handles.autotrackfirstframebutton,'Enable','on');
  set(handles.autotrackdoitbutton,'enable','off');
  fix_ActionCancelled( hObject, handles, handles.autotrackpanel )
end
guidata(hObject,handles);


% --- Executes on button press in autotrackfirstframebutton.
function autotrackfirstframebutton_Callback(hObject, eventdata, handles)
% hObject    handle to autotrackfirstframebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to track first.','No Fly Selected');
  return;
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end
handles.autotrackfly = handles.selected;
handles.autotrackframe = handles.f;

handles.nselect = 0;
handles.selected = [];
set(handles.autotrackdoitbutton,'enable','on');
set(handles.autotrackfirstframebutton,'enable','off');
set(handles.autotracksettingsbutton,'enable','on');
% draw the fly
fly = handles.autotrackfly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hautotrack = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hautotrack,'color',color*.75,'linewidth',3,'linestyle','--',...
  'hittest','off');
handles.bgcurr = handles.bgmed;

guidata(hObject,handles);

% --- Executes on button press in autotracksettingsbutton.
function autotracksettingsbutton_Callback(hObject, eventdata, handles)
% hObject    handle to autotracksettingsbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = retrack_settings(handles);
guidata(hObject,handles);


% --- Executes on button press in showtrackingbutton.
function showtrackingbutton_Callback(hObject, eventdata, handles)
% hObject    handle to showtrackingbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of showtrackingbutton


% --- Executes on button press in flipdoitbutton.
function flipdoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to flipdoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isalive(handles.trx(handles.flipfly),handles.f),
  errordlg('Selected fly is not alive in current frame','Bad Selection');
  return;
end

fix_SetFlySelected(handles,handles.flipfly,false);
handles.selected = [];

f = handles.f;
fly = handles.flipfly;

% save to undo list
handles.undolist{end+1} = {'flip',handles.flipframe,f,fly};

% flip
for f = handles.flipframe:f,
  i = handles.trx(fly).off+(f);
  handles.trx(fly).theta(i) = modrange(handles.trx(fly).theta(i)+pi,-pi,pi);
end

delete(handles.hflip);
set(handles.flipfirstframebutton,'Enable','on');
set(handles.flipdoitbutton,'enable','off');
set(handles.flippanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly(handles,fly);


% --- Executes on button press in flipcancelbutton.
function flipcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to flipcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'hflip') && ishandle(handles.hflip),
  delete(handles.hflip);
end
if isfield(handles,'flipfly'),
  fix_SetFlySelected(handles,handles.flipfly,false);
end
set(handles.flipfirstframebutton,'Enable','on');
set(handles.flipdoitbutton,'enable','off');
fix_ActionCancelled( hObject, handles, handles.flippanel )


% --- Executes on button press in flipfirstframebutton.
function flipfirstframebutton_Callback(hObject, eventdata, handles)
% hObject    handle to flipfirstframebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to flip first.','No Fly Selected');
  return;
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return;
end
handles.flipfly = handles.selected;
handles.flipframe = handles.f;
handles.nselect = 0;
handles.selected = [];
set(handles.flipdoitbutton,'enable','on');
set(handles.flipfirstframebutton,'enable','off');

% draw the fly
fly = handles.flipfly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hflip = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hflip,'color',color*.75,'linewidth',3,'linestyle','--',...
  'hittest','off');

guidata(hObject,handles);


% --- Executes on button press in printbutton.
function printbutton_Callback(hObject, eventdata, handles)
% hObject    handle to printbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

for fly = 1:length(handles.trx)
  fprintf('Track %d: firstframe = %d, endframe = %d, nframes = %d, length(x) = %d\n',...
    fly,handles.trx(fly).firstframe,handles.trx(fly).endframe,handles.trx(fly).nframes,...
    length(handles.trx(fly).x));
end


% --- Executes on button press in manytrackdoitbutton.
function manytrackdoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to manytrackdoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

f0 = min(handles.f,handles.manytrackframe);
f1 = max(handles.f,handles.manytrackframe);

for fly = handles.manytrackflies(:)',
  fix_SetFlySelected(handles,fly,false);
end
handles.selected = [];

flies = handles.manytrackflies;

% save to undo list
for i = 1:length(flies),
  fly = flies(i);
  oldtrx(i) = fix_GetPartOfTrack(handles.trx(fly),f0,f1,handles.trajfns);
end
handles.undolist{end+1} = {'manytrack',[f0,f1],flies,oldtrx};

set(handles.manytrackcancelbutton,'string','Stop');
set(handles.manytrackdoitbutton,'enable','off');
handles.stoptracking = false;

% track
seq.flies = flies;
seq.frames = f0:min(f1,[handles.trx(flies).endframe]);
if get(handles.manytrackshowtrackingbutton,'value')
  fix_ZoomInOnSeq(handles,seq);
end
handles.stoptracking = false;
handles = fix_FixTrackFlies(flies,f0,f1,handles);
for fly = flies(:)',
  handles = fix_FixDeathEvent(handles,fly);
end
delete(handles.hmanytrack);
set(handles.manytrackcancelbutton,'string','Cancel');
set(handles.manytrackfirstframebutton,'Enable','on');
set(handles.manytrackdoitbutton,'enable','off');
set(handles.manytrackpanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');

handles.needssaving = 1;

guidata(hObject,handles);

for fly = flies(:)',
  fix_FixUpdateFly(handles,fly);
end


% --- Executes on button press in manytrackcancelbutton.
function manytrackcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to manytrackcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if strcmpi(get(handles.manytrackcancelbutton,'string'),'stop')
  handles.stoptracking = true;
else
  if isfield(handles,'hmanytrack')
    idx = ishandle(handles.hmanytrack);
    delete(handles.hmanytrack(idx));
  end
  if isfield(handles,'manytrackflies'),
    for fly = handles.manytrackflies(:)',
      fix_SetFlySelected(handles,fly,false);
    end
  end
  set(handles.manytrackfirstframebutton,'Enable','on');
  set(handles.manytrackdoitbutton,'enable','off');
  fix_ActionCancelled( hObject, handles, handles.manytrackpanel )
end
guidata(hObject,handles);


% --- Executes on button press in manytrackfirstframebutton.
function manytrackfirstframebutton_Callback(hObject, eventdata, handles)
% hObject    handle to manytrackfirstframebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%handles.selected = handles.selected(handles.selected > 0);
if isempty(handles.selected),
  errordlg('Please select flies track to track first.','No Fly Selected');
  return;
end
for fly = handles.selected(:)',
  if ~isalive(handles.trx(fly),handles.f),
    errordlg('One of the selected flies is not alive in current frame!','Bad Selection');
    return;
  end
end
handles.autotrackfly = handles.selected;
handles.autotrackframe = handles.f;
handles.manytrackflies = handles.selected;
handles.manytrackframe = handles.f;

handles.nselect = 0;
handles.selected = [];
set(handles.manytrackdoitbutton,'enable','on');
set(handles.manytrackfirstframebutton,'enable','off');
set(handles.manytracksettingsbutton,'enable','on');
% draw the fly
handles.hmanytrack = [];
for fly = handles.manytrackflies(:)',
  i = handles.trx(fly).off+(handles.f);
  x = handles.trx(fly).x(i);
  y = handles.trx(fly).y(i);
  a = 2*handles.trx(fly).a(i);
  b = 2*handles.trx(fly).b(i);
  theta = handles.trx(fly).theta(i);
  handles.hmanytrack(end+1) = ellipsedraw(a,b,x,y,theta);
  color = handles.colors(fly,:);
  set(handles.hmanytrack(end),'color',color*.75,'linewidth',3,'linestyle','--',...
    'hittest','off');
end
handles.bgcurr = handles.bgmed;

guidata(hObject,handles);


% --- Executes on button press in manytracksettingsbutton.
function manytracksettingsbutton_Callback(hObject, eventdata, handles)
% hObject    handle to manytracksettingsbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = retrack_settings(handles);
guidata(hObject,handles);


% --- Executes on button press in manytrackshowtrackingbutton.
function manytrackshowtrackingbutton_Callback(hObject, eventdata, handles)
% hObject    handle to manytrackshowtrackingbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of manytrackshowtrackingbutton


% --- Executes on button press in addnewtrackdoitbutton.
function addnewtrackdoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to addnewtrackdoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

new_id = 0;
new_timestamp = -1;
for fly = 1:length( handles.trx )
   new_id = max( [handles.trx(fly).id + 1, new_id] );
   if new_timestamp == -1 && ...
         handles.trx(fly).firstframe <= handles.f && ...
         handles.trx(fly).endframe >= handles.f
      new_timestamp = handles.trx(fly).timestamps(handles.trx(fly).firstframe + handles.f - 1);
   end
end

% fill in new fly
fly = length( handles.trx ) + 1;
handles.trx(fly).id = new_id;
handles.trx(fly).timestamps = new_timestamp;
handles.trx(fly).firstframe = handles.f;
handles.trx(fly).off = -handles.trx(fly).firstframe + 1;
handles.trx(fly).endframe = handles.f;
handles.trx(fly).nframes = 1;
handles.trx(fly).moviename = handles.trx(1).moviename;
handles.trx(fly).arena = handles.trx(1).arena;
handles.trx(fly).matname = handles.trx(1).matname;
handles.trx(fly).pxpermm = handles.trx(1).pxpermm;
handles.trx(fly).fps = handles.trx(1).fps;
xlim = get( handles.mainaxes, 'xlim' );
ylim = get( handles.mainaxes, 'ylim' );
handles.trx(fly).x = mean( xlim );
handles.trx(fly).y = mean( ylim );
handles.trx(fly).theta = 0;
handles.trx(fly).a = diff( xlim )/10;
handles.trx(fly).b = diff( ylim )/30;
handles.trx(fly).xpred = handles.trx(fly).x;
handles.trx(fly).ypred = handles.trx(fly).y;
handles.trx(fly).thetapred = handles.trx(fly).theta;
handles.trx(fly).dx = 0;
handles.trx(fly).dy = 0;
handles.trx(fly).v = 0;
if isfield(handles,'trajfns'),
  extrafns = setdiff(handles.trajfns,{'x','y','a','b','theta'});
else
  extrafns = {};
end
for fni = 1:numel(extrafns),
  handles.trx(fly).(extrafns{fni}) = nan;
end

% save to undo list
handles.undolist{end+1} = {'addnew',fly};

% draw
handles.nflies = handles.nflies + 1;
handles = fix_SetFlyColors(handles);
[handles.hellipse(fly),handles.hcenter(fly),handles.hhead(fly),...
   handles.htail(fly),handles.hleft(fly),handles.hright(fly),...
   handles.htailmarker(fly),handles.hpath(fly)] = ...
   InitFly(handles.colors(fly,:));
handles = fix_UpdateFlyPathVisible(handles);
handles = fix_FixUpdateFly(handles,fly);

set(handles.addnewtrackdoitbutton,'Enable','off');
set(handles.addnewtrackpanel','visible','off');
fix_EnablePanel(handles.editpanel,'on');
handles.needssaving = 1;

guidata(hObject,handles);


% --- Executes on button press in addnewtrackcancelbutton.
function addnewtrackcancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to addnewtrackcancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.addnewtrackdoitbutton,'Enable','off');
fix_ActionCancelled( hObject, handles, handles.addnewtrackpanel )


% --- Executes on button press in superposedoitbutton.
function superposedoitbutton_Callback(hObject, eventdata, handles)
% hObject    handle to superposedoitbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty( handles.selected )
  errordlg('Please select another fly track.','No Fly Selected');
  return
elseif length( handles.selected ) ~= 1
   errordlg( 'Must select only one slave fly.', 'Bad Selection' );
   return
elseif ~isalive( handles.trx(handles.superposefirstfly), handles.f )
  errordlg('First fly is not alive in current frame.','Bad Selection');
  return
elseif ~isalive( handles.trx(handles.selected), handles.f )
  errordlg('Second fly is not alive in current frame.','Bad Selection');
  return
elseif ~isalive( handles.trx(handles.selected), handles.superposefirstframe )
  errordlg('Second fly is not alive in first frame.','Bad Selection');
  return
end

% calculate indices
fly1 = handles.superposefirstfly;
fly2 = handles.selected;
idx1 = handles.trx(fly1).off + (handles.superposefirstframe:handles.f);
idx2 = handles.trx(fly2).off + (handles.superposefirstframe:handles.f);

% save to undo list
olddata = fix_GetPartOfTrack( handles.trx(fly2), handles.superposefirstframe, handles.f, handles.trajfns );
handles.undolist{end+1} = {'superpose', handles.selected, ...
   handles.superposefirstframe, handles.f, olddata};

% superpose
for fni = 1:numel(handles.trajfns),
  fn = handles.trajfns{fni};
  handles.trx(fly2).(fn)(idx2) = handles.trx(fly1).(fn)(idx1);
end
% handles.trx(fly2).x(idx2) = handles.trx(fly1).x(idx1);
% handles.trx(fly2).y(idx2) = handles.trx(fly1).y(idx1);
% handles.trx(fly2).a(idx2) = handles.trx(fly1).a(idx1);
% handles.trx(fly2).b(idx2) = handles.trx(fly1).b(idx1);
% handles.trx(fly2).theta(idx2) = handles.trx(fly1).theta(idx1);
if isfield( handles.trx, 'timestamps' )
   handles.trx(fly2).timestamps(idx2) = handles.trx(fly1).timestamps(idx1);
end

% clean up
delete(handles.hsuperpose);
fix_SetFlySelected( handles, fly1, false );
fix_SetFlySelected( handles, fly2, false );

handles.nselect = 0;
handles.selected = [];
set(handles.superposetrackspanel,'visible','off');
fix_EnablePanel(handles.editpanel,'on');
handles.needssaving = 1;

guidata(hObject,handles);

fix_FixUpdateFly( handles, fly1 );
fix_FixUpdateFly( handles, fly2 );


% --- Executes on button press in superposefirstflybutton.
function superposefirstflybutton_Callback(hObject, eventdata, handles)
% hObject    handle to superposefirstflybutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.selected),
  errordlg('Please select fly track to superpose first.','No Fly Selected');
  return
end
if ~isalive(handles.trx(handles.selected),handles.f),
  errordlg('Selected fly is not alive in current frame!','Bad Selection');
  return
end

handles.superposefirstframe = handles.f;
handles.superposefirstfly = handles.selected;
handles.selected = [];

% draw the fly
fly = handles.superposefirstfly;
i = handles.trx(fly).off+(handles.f);
x = handles.trx(fly).x(i);
y = handles.trx(fly).y(i);
a = 2*handles.trx(fly).a(i);
b = 2*handles.trx(fly).b(i);
theta = handles.trx(fly).theta(i);
handles.hsuperpose = ellipsedraw(a,b,x,y,theta);
color = handles.colors(fly,:);
set(handles.hsuperpose,'color',color*.75,'linewidth',3,'linestyle','--','hittest','off');

set(handles.superposedoitbutton,'visible','on');
set(handles.superposefirstflybutton,'visible','off');
guidata(hObject,handles);


% --- Executes on button press in superposecancelbutton.
function superposecancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to superposecancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'hsuperpose') && ishandle(handles.hsuperpose),
  delete(handles.hsuperpose);
end
if isfield( handles, 'superposefirstfly' )
   fix_SetFlySelected( handles, handles.superposefirstfly, false );
end
fix_SetFlySelected( handles, handles.selected, false );
set( handles.superposefirstflybutton, 'visible', 'on' );
set( handles.superposedoitbutton, 'visible', 'off' );
fix_ActionCancelled( hObject, handles, handles.superposetrackspanel );


% --- Executes when figure1 is resized.
function figure1_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

figpos = get(handles.figure1,'Position');

% right panels: keep width, bottom dist, height, right dist the same
if isfield( handles, 'rightpanel_tags' )
   ntags = numel(handles.rightpanel_tags);
else
   ntags = 0;
end
for fni = 1:ntags,
  fn = handles.rightpanel_tags{fni};
  h = handles.(fn);
  pos = get(h,'Position');
  pos(1) = figpos(3) - handles.rightpanel_dright(fni);
  set(h,'Position',pos);
end

% stuff below axes: keep dist bottom, height same, scale dleft, width
if isfield( handles, 'bottom_tags' )
   ntags = numel(handles.bottom_tags);
else
   ntags = 0;
end
for fni = 1:ntags,
  fn = handles.bottom_tags{fni};
  h = handles.(fn);
  pos = get(h,'Position');
  pos(1) = figpos(3)*handles.bottom_dleft_norm(fni);
  pos(3) = figpos(3)*handles.bottom_width_norm(fni);
  set(h,'Position',pos); 
end

% axes should fill everything else
sliderpos = get(handles.frameslider,'Position');
rightpanelpos = get(handles.seqinfopanel,'Position');
pos = get(handles.mainaxes,'Position');
if isfield( handles, 'axes_dslider' )
   pos(2) = sliderpos(2)+sliderpos(4)+handles.axes_dslider;
   pos(4) = figpos(4)-pos(2)-handles.axes_dtop;
   pos(3) = rightpanelpos(1)-pos(1)-handles.axes_drightpanels;
end
set(handles.mainaxes,'Position',pos);
sliderpos([1,3]) = pos([1,3]);
set(handles.frameslider,'Position',sliderpos);


% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)

switch eventdata.Key,
  
  case 'rightarrow',

    if handles.f < handles.nframes,
      handles.f = handles.f+1;
      fix_SetFrameNumber(handles,handles.f);
      fix_PlotFrame(handles);
      guidata(hObject,handles);
    end
    
  case 'leftarrow',

    if handles.f > 1,
      handles.f = handles.f-1;
      fix_SetFrameNumber(handles,handles.f);
      fix_PlotFrame(handles);
      guidata(hObject,handles);
    end
    
end


% --- Executes on button press in flipimage_checkbox.
function flipimage_checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to flipimage_checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.flipud = get( hObject, 'value' );
fix_PlotFrame( handles )
guidata( hObject, handles )


% --- Executes on button press in showdead_checkbox.
function showdead_checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to showdead_checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.show_dead = get( hObject, 'value' );
fix_PlotFrame( handles )
guidata( hObject, handles )
