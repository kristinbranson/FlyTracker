function varargout = retrack_settings(varargin)
% RETRACK_SETTINGS M-file for retrack_settings.fig
%      RETRACK_SETTINGS, by itself, creates a new RETRACK_SETTINGS or raises the existing
%      singleton*.
%
%      H = RETRACK_SETTINGS returns the handle to a new RETRACK_SETTINGS or the handle to
%      the existing singleton*.
%
%      RETRACK_SETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RETRACK_SETTINGS.M with the given input arguments.
%
%      RETRACK_SETTINGS('Property','Value',...) creates a new RETRACK_SETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before retrack_settings_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to retrack_settings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help retrack_settings

% Last Modified by GUIDE v2.5 31-May-2014 14:40:29

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @retrack_settings_OpeningFcn, ...
                   'gui_OutputFcn',  @retrack_settings_OutputFcn, ...
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


% --- Executes just before retrack_settings is made visible.
function retrack_settings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to retrack_settings (see VARARGIN)

handles.fixhandles = varargin{1};

% set defaults
set(handles.eyedropperbutton,'value',0);
axes(handles.bgcolorax);
handles.fixhandles.bgcurr = handles.fixhandles.bgmed;
set(handles.threshtext,'string',sprintf('Threshold: %.1f',handles.fixhandles.bgthresh));
if handles.fixhandles.lighterthanbg == 1,
  set(handles.lighterthanbgmenu,'value',1);
elseif handles.fixhandles.lighterthanbg == -1,
  set(handles.lighterthanbgmenu,'value',2);
else
  set(handles.lighterthanbgmenu,'value',3);
end
set(handles.radiustext,'string',sprintf('Track Radius: %.1f px',handles.fixhandles.maxjump));

handles.choosepatch = false;
handles.buttondownfcn = get(handles.axes1,'buttondownfcn');

handles.choosefg = isfield( handles.fixhandles, 'temp_arena' );
set( handles.setfgboundary_checkbox, 'value', handles.choosefg );
handles.choosefg_phi = 0:1e-2:2*pi;
handles.choosefg_x = cos( handles.choosefg_phi );
handles.choosefg_y = sin( handles.choosefg_phi );

handles = ShowCurrentFrame(handles);

if ~isfield(handles.fixhandles,'bgcolor') || isnan(handles.fixhandles.bgcolor)
  handles.fixhandles.bgcolor = median(handles.im(:));
end
axes(handles.bgcolorax);
image(repmat(uint8(handles.fixhandles.bgcolor),[1,1,3]));
axis off;

% Choose default command line output for retrack_settings
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes retrack_settings wait for user response (see UIRESUME)
uiwait(handles.figure1);


function handles = ShowCurrentFrame(handles)

flies = handles.fixhandles.autotrackfly;
f = handles.fixhandles.autotrackframe;
[isfore,dfore,xpred,ypred,thetapred,handles.r0,handles.r1,handles.c0,handles.c1,handles.im] = ...
  fix_FixBgSub(flies,f,handles.fixhandles);

% black out the area outside the circular arena
if isfield( handles.fixhandles, 'circular_arena' ) && ...
      isfield( handles.fixhandles.circular_arena, 'do_set_circular_arena' ) && ...
      handles.fixhandles.circular_arena.do_set_circular_arena
   [cc, rr] = meshgrid( handles.c0:handles.c1, handles.r0:handles.r1 );
   non_arena_mask = sqrt( ...
      (cc - handles.fixhandles.circular_arena.arena_center_x).^2 + ...
      (rr - handles.fixhandles.circular_arena.arena_center_y).^2 ) ...
      > handles.fixhandles.circular_arena.arena_radius;
   handles.im(non_arena_mask) = 0;
end

% black out the area outside the temp foreground selection
if isfield( handles.fixhandles, 'temp_arena' )
   [cc, rr] = meshgrid( handles.c0:handles.c1, handles.r0:handles.r1 );
   non_arena_mask = sqrt( ...
      (cc - handles.fixhandles.temp_arena.center_x).^2 + ...
      (rr - handles.fixhandles.temp_arena.center_y).^2 ) ...
      > handles.fixhandles.temp_arena.radius;
   handles.im(non_arena_mask) = 0;
end

% plot frame
handles.nr = handles.r1-handles.r0+1;
handles.nc = handles.c1-handles.c0+1;
axes(handles.axes1);
hold off;
handles.him = imagesc(handles.im);
set(handles.him,'buttondownfcn',handles.buttondownfcn);
axis image;
colormap gray;
hold on;

% plot foreground areas
bw = bwperim(isfore);
[r,c] = find(bw);
plot(c,r,'r.','hittest','off');

if isfield(handles,'choosepatchpt1') && isfield(handles,'choosepatchpt2')
  handles.hchoose = plot(...
    [handles.choosepatchpt1(1),handles.choosepatchpt1(1),...
    handles.choosepatchpt2(1),handles.choosepatchpt2(1),handles.choosepatchpt1(1)],...
    [handles.choosepatchpt1(2),handles.choosepatchpt2(2),...
    handles.choosepatchpt2(2),handles.choosepatchpt1(2),handles.choosepatchpt1(2)],'g');
end

% --- Outputs from this function are returned to the command line.
function varargout = retrack_settings_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
try
   varargout{1} = handles.fixhandles;
   delete(handles.figure1);
catch err
   whos handles
   rethrow( err )
end

% --- Executes on button press in upthresh.
function upthresh_Callback(hObject, eventdata, handles)
% hObject    handle to upthresh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.fixhandles.bgthresh = handles.fixhandles.bgthresh + .1;
set(handles.threshtext,'string',sprintf('Threshold: %.1f',handles.fixhandles.bgthresh));
handles = ShowCurrentFrame(handles);
guidata(hObject,handles);

% --- Executes on button press in threshdown.
function threshdown_Callback(hObject, eventdata, handles)
% hObject    handle to threshdown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.fixhandles.bgthresh = handles.fixhandles.bgthresh - .1;
set(handles.threshtext,'string',sprintf('Threshold: %.1f',handles.fixhandles.bgthresh));
handles = ShowCurrentFrame(handles);
guidata(hObject,handles);


% --- Executes on selection change in lighterthanbgmenu.
function lighterthanbgmenu_Callback(hObject, eventdata, handles)
% hObject    handle to lighterthanbgmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns lighterthanbgmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from lighterthanbgmenu

v = get(hObject,'value');
if v == 1
  
  if handles.fixhandles.lighterthanbg == 1
    return;
  end
  handles.fixhandles.lighterthanbg = 1;
  handles = ShowCurrentFrame(handles);
  
elseif v == 2

  if handles.fixhandles.lighterthanbg == -1
    return;
  end
  handles.fixhandles.lighterthanbg = -1;
  handles = ShowCurrentFrame(handles);
  
else 
  
  if handles.fixhandles.lighterthanbg == 0
    return;
  end
  handles.fixhandles.lighterthanbg = 0;
  handles = ShowCurrentFrame(handles);

end
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function lighterthanbgmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lighterthanbgmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in donebutton.
function donebutton_Callback(hObject, eventdata, handles)
% hObject    handle to donebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

uiresume(handles.figure1);


% --- Executes on button press in eyedropperbutton.
function eyedropperbutton_Callback(hObject, eventdata, handles)
% hObject    handle to eyedropperbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of eyedropperbutton


% --- Executes on mouse press over axes background.
function axes1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

pt = get(handles.axes1,'currentpoint');
x = min(max(1,round(pt(1,1))),handles.nc);
y = min(max(1,round(pt(1,2))),handles.nr);

if get(handles.eyedropperbutton,'Value')
   handles.fixhandles.bgcolor = handles.im(y,x);
   axes(handles.bgcolorax);
   image(repmat(uint8(handles.fixhandles.bgcolor),[1,1,3]));
   axis off;

elseif handles.choosefg
   if isfield( handles, 'hchoosefg' ) && ishandle( handles.hchoosefg )
      delete( handles.hchoosefg )
   end
   handles.choosefgpt1 = [x,y];
   handles.hchoosefg = plot( handles.choosefg_x + x, handles.choosefg_y + y, 'b' );

else
   if isfield(handles,'hchoose') && ishandle(handles.hchoose)
      delete(handles.hchoose);
   end
   handles.choosepatchpt1 = [x,y];
   handles.hchoose = plot([x,x,x,x,x],[y,y,y,y,y],'g');
   handles.choosepatch = true;
end

guidata(hObject,handles);


% --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield( handles, 'nc' ) || ~isfield( handles, 'nr' ), return, end

pt = get(handles.axes1,'currentpoint');
x = pt(1,1);
y = pt(1,2);
if x < 1 || x > handles.nc || y > handles.nr || y < 1
   return
end
x = min(max(1,round(x)),handles.nc);
y = min(max(1,round(y)),handles.nr);

if isfield(handles,'choosepatch') && handles.choosepatch
   handles.choosepatchpt2 = [x,y];
   set(handles.hchoose,...
     'xdata',[handles.choosepatchpt1(1),handles.choosepatchpt1(1),x,x,handles.choosepatchpt1(1)],...
     'ydata',[handles.choosepatchpt1(2),y,y,handles.choosepatchpt1(2),handles.choosepatchpt1(2)]);  
  
elseif isfield( handles, 'choosefg' ) && handles.choosefg && isfield( handles, 'choosefgpt1' )
   r = pdist( [handles.choosefgpt1; [x, y]] );
   circ_x = r*handles.choosefg_x + handles.choosefgpt1(1);
   circ_y = r*handles.choosefg_y + handles.choosefgpt1(2);
   set( handles.hchoosefg, 'xdata', circ_x, 'ydata', circ_y );
end

guidata(hObject,handles);


% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonUpFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.choosepatch = false;

% select fg area, if applicable
if isfield( handles, 'choosefg' ) && handles.choosefg && isfield( handles, 'choosefgpt1' )
   pt = get(handles.axes1,'currentpoint');
   arena.center_x = handles.choosefgpt1(1,1) + handles.c0;
   arena.center_y = handles.choosefgpt1(1,2) + handles.r0;
   arena.radius = pdist( [handles.choosefgpt1; [pt(1,1), pt(1,2)]] );
   handles.fixhandles.temp_arena = arena;
   handles = rmfield( handles, 'choosefgpt1' );
   handles = ShowCurrentFrame( handles );
end

guidata(hObject,handles);


% --- Executes on button press in debugbutton.
function debugbutton_Callback(hObject, eventdata, handles)
% hObject    handle to debugbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

keyboard;


% --- Executes on button press in fillbutton.
function fillbutton_Callback(hObject, eventdata, handles)
% hObject    handle to fillbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles,'choosepatchpt1') || ~isfield(handles,'choosepatchpt2')
  msgbox('Drag a rectangle to select a patch to fill');
  return;
end

r0 = min(handles.choosepatchpt1(2),handles.choosepatchpt2(2));
r1 = max(handles.choosepatchpt1(2),handles.choosepatchpt2(2));
c0 = min(handles.choosepatchpt1(1),handles.choosepatchpt2(1));
c1 = max(handles.choosepatchpt1(1),handles.choosepatchpt2(1));
r0 = max(round(r0+handles.r0-1),1); 
r1 = min(round(r1+handles.r0-1),handles.fixhandles.nr);
c0 = max(round(c0+handles.c0-1),1); 
c1 = min(round(c1+handles.c0-1),handles.fixhandles.nc);
handles.fixhandles.bgcurr = handles.fixhandles.bgmed;
handles.fixhandles.bgcurr(r0:r1,c0:c1) = handles.fixhandles.bgcolor;

handles = ShowCurrentFrame(handles);
guidata(hObject,handles);


% --- Executes on button press in radiusplusbutton.
function radiusplusbutton_Callback(hObject, eventdata, handles)
% hObject    handle to radiusplusbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.fixhandles.maxjump = round(handles.fixhandles.maxjump + 1);
set(handles.radiustext,'string',sprintf('Track Radius: %.1f px',handles.fixhandles.maxjump));
handles = ShowCurrentFrame(handles);
guidata(hObject,handles);


% --- Executes on button press in radiusminusbutton.
function radiusminusbutton_Callback(hObject, eventdata, handles)
% hObject    handle to radiusminusbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.fixhandles.maxjump = round(handles.fixhandles.maxjump - 1);
set(handles.radiustext,'string',sprintf('Track Radius: %.1f px',handles.fixhandles.maxjump));
handles = ShowCurrentFrame(handles);
guidata(hObject,handles);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
uiresume(handles.figure1);


% --- Executes on button press in setfgboundary_checkbox.
function setfgboundary_checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to setfgboundary_checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.choosefg = get( hObject, 'value' );
if ~handles.choosefg && isfield( handles.fixhandles, 'temp_arena' )
   handles.fixhandles = rmfield( handles.fixhandles, 'temp_arena' );
end
handles = ShowCurrentFrame(handles);
guidata( hObject, handles );
