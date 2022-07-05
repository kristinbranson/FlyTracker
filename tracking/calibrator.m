
% Obtain tracking parameters via user input.
%
% To start the calibration, use:
%
%    success = calibrator(f_vid, f_info)
%
% where:
%    success       - indicates wheter calibration was completed
%    f_vid         - path of input video
%    f_calib       - path to which calibration file will be saved
%
function success = calibrator(f_vid, f_calib)
    success = 1;

    % set fontscale
    fs = 72/get(0,'ScreenPixelsPerInch'); % scale fonts to resemble the mac    
    
    % open wait dialog while loading video file 
    wait_h = customDialog('wait','Loading calibrator...',12*fs);
    
    % video data
    files.f_vid  = f_vid;
    vinfo = video_open(f_vid,1); 
    
    % initialize calibration data  
    files.f_info = f_calib;
    calib.auto_detect   = 1;
    calib.n_chambers    = 1;
    calib.n_rows        = 1;
    calib.n_cols        = 1;
    calib.roi_type      = 1;
    
    % initialize background data  
    [~,vid_name] = fileparts(f_vid); info_dir = fileparts(f_calib);
    parent_dir = fullfile(info_dir,vid_name);
    files.f_bg   = fullfile(parent_dir, [vid_name '-bg.mat']);
    if ~exist(parent_dir,'dir')
        mkdir(parent_dir);
    end
    bg    = []; 
    
    % set constants
    const.sub_height = 500; 
    const.menu_pos_y = zeros(1,4);    
    const.clr.body   = [.8 .1 .6];
    const.clr.wings  = [.1 .3  1];
    const.clr.legs   = [.2 .8 .3];    
    
    % interface variables
    vars.img = video_read_frame(vinfo,floor(vinfo.n_frames/2));
    vars.dets            = [];   
    vars.mask_id         = 1;    
    vars.overlay_seg     = true; 
    vars.pointsize       = 1;    % 1:thin, 4:thick     
    vars.total_n_flies   = 0;    
    vars.overridden_n_flies = false;   
    vars.pref_pointsize  = [];

    % set default params
    default = [];
    
    % interface handles
    handles = [];
    
    % initialize interface
    init_interface()   
    
    % close wait dialog now that interface is fully loaded
    delete(wait_h);
    
    % wait until figure handle has been deleted before exiting function
    waitfor(handles.fig_h)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Interface setup functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function init_interface()
    % set up main window
    scrsz = get(0,'ScreenSize');
    im_height  = size(vars.img,1);
    im_width   = size(vars.img,2);
    sub_width  = im_width*const.sub_height/im_height;
    fig_height = const.sub_height + 60;
    fig_width  = sub_width + 300;
    fig_h = figure('Name','FlyTracker-1.0.5: Calibrator','NumberTitle','off', ...
        'Position',[scrsz(3)/2-fig_width/2 scrsz(4)/2-fig_height/2 fig_width fig_height],...
        'Color',.94*[1 1 1]);
    set(fig_h,'MenuBar','none','Resize','off','CloseRequestFcn',@uiClose)
    figclr = get(fig_h,'Color');    

    % display sample frame from video
    sub_h = subplot('Position',[20/fig_width 30/fig_height sub_width/fig_width const.sub_height/fig_height]);
    set(sub_h,'box','on')
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    im_h = imshow(vars.img);
    set(sub_h,'XTickLabel',[], 'YTickLabel',[], 'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)
    hold on
    colormap(gray)  
    % add handle to zoom function
    zoom_h = zoom;
    set(zoom_h,'ActionPostCallback',@autoSetPointsize)
    % display name of video
    filename = vinfo.filename;    
    h_file = uicontrol('Style', 'text', 'String', filename, ...
        'Position', [20 fig_height-28 sub_width 20], ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12); 
    extent = get(h_file,'extent');
    while extent(3) > sub_width
        [~,filename] = strtok(filename,filesep); 
        set(h_file,'String',['... ' filename]);
        extent = get(h_file,'extent');
    end
    % button to load new video
    vid_button_h = uicontrol('Style', 'pushbutton', 'String', 'v', ...
        'Position', [21 fig_height-26 18 18], ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12,...
        'Callback',@update_video);
    
    % vertical menu divider
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+40 1 1 fig_height], ...
        'BackgroundColor',.5*[1 1 1]);    
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+41 1 1 fig_height], ...
        'BackgroundColor',figclr);    
    min_step_y = 25;
    max_step_y = 57;
    margin_x = 7;
    margin_x2 = 166; 

    % store handles
    handles.fig_h = fig_h;
    handles.h_file = h_file;
    handles.vid_button_h = vid_button_h;
    handles.sub_h = sub_h;
    handles.im_h  = im_h;

    % RESOLUTION ==========================================================
    const.menu_pos_y(1) = fig_height;

    % editable ruler
    ruler_h = imline(sub_h,[im_width/2-20 im_height/2; im_width/2+20 im_height/2]);
    setColor(ruler_h,'r')
    addNewPositionCallback(ruler_h,@updateROI);

    text_x = sub_width+54;
    text_y = fig_height-33;    
    res_hs = [];
    % title shade    
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+41 text_y-2 315 36], ...
        'BackgroundColor',figclr*.93);       
    % title    
    uicontrol('Style', 'text', 'String', 'Resolution', ...
        'Position', [text_x text_y 250 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr*.93, ...
        'FontSize',fs*16);   

    % frame rate
    text_y = text_y - min_step_y*1.3;
    res_hs(end+1) = uicontrol('Style', 'text', 'String', 'frame rate (fps): ', ...
        'Position', [text_x+margin_x text_y-5 150 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12,...
        'ToolTipString','Verify that framerate is correct'); 
    h_fps = uicontrol('Style', 'edit', 'String', num2str(round(vinfo.fps*10)/10), ...
        'Position', [text_x+margin_x2 text_y 56 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12,...
        'Callback',@editResolution);
    res_hs(end+1) = h_fps;

    % ruler length
    text_y = text_y - min_step_y;
    res_hs(end+1) = uicontrol('Style', 'text', 'String', 'length of ruler (mm): ', ...
        'Position', [text_x+margin_x text_y-5 150 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12,...
        'ToolTipString','Adjust ruler and enter its length in mm'); 
    h_ruler_len = uicontrol('Style', 'edit', 'String', '', ...
        'Position', [text_x+margin_x2 text_y 56 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12,...
        'Callback',@editResolution);
    res_hs(end+1) = h_ruler_len;

    % continue button
    text_y = text_y - min_step_y*1.2;
    res_hs(end+1) = uicontrol('Style', 'pushbutton', 'String', 'continue', ...        
        'Position', [text_x+margin_x-1 text_y-4 218 30], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12,...
        'Callback',@setResolution);    

    % horizontal menu divider
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+40 text_y-max_step_y*.35-1 315 1], ...
        'BackgroundColor',.5*[1 1 1]);

    % store handles
    handles.ruler_h         = ruler_h;
    handles.res_hs          = res_hs;
    handles.h_fps           = h_fps;
    handles.h_ruler_len     = h_ruler_len;
    handles.ROIsize_h       = [];
    handles.ROIsize_h_auto 	= [];
    handles.roi_h           = [];
    handles.roi_h_auto      = [];
    handles.roi_h_full      = [];

    % EXPERIMENTAL SETUP ==================================================    
    const.menu_pos_y(2) = text_y-max_step_y*.35-3;    
    exp_hs = [];

    % title shade
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+41 text_y-max_step_y*.35-38 315 37], ...
        'BackgroundColor',figclr*.93);       

    % title
    text_y = text_y - max_step_y;
    uicontrol('Style', 'text', 'String', 'Experimental setup', ...
        'Position', [text_x text_y 250 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr*.93, ...
        'FontSize',fs*16); 

    % chamber detection method
    text_y = text_y - min_step_y*1.3;
    h_chamber_method = uicontrol('Style', 'popup', 'String', ...
        'automatically detect chambers|manually set chambers|use entire image', ...
        'Position', [text_x+margin_x-5 text_y-8 226 30], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12, ...
        'Callback', @setChamberMethod);
    exp_hs(end+1) = h_chamber_method;

    % number of chambers
    text_y = text_y - min_step_y;
    exp_hs(end+1) = uicontrol('Style', 'text', 'String', '# chambers: ', ...
        'Position', [text_x+margin_x text_y-5 120 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12,...
        'ToolTipString','Enter the total number of chambers, including empty ones'); 
    h_n_chambers = uicontrol('Style', 'edit', 'String', '', ...
        'Position', [text_x+95 text_y 30 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12,...
        'Callback',@editNumChambers);       
    exp_hs(end+1) = h_n_chambers;

    % chamber detect button (if automatic selected)
    auto_hs = uicontrol('Style', 'pushbutton', 'String', 'detect', ...
        'Position', [text_x+margin_x2-2 text_y-3 59  27], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12,...
        'Callback',@detectChambers);
    exp_hs(end+1) = auto_hs;

    % chamber grid (if manual selected)
    man_hs = [];
    man_hs(1) = uicontrol('Style', 'text', 'String', '(', ...
        'Position', [text_x+129 text_y 5 20], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr,...
        'FontSize',fs*12);   
    h_n_chamber_rows = uicontrol('Style', 'edit', 'String', '', ...
        'Position', [text_x+135 text_y 25 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12, ...
        'Callback',@editNumChamberRows,...
        'ToolTipString','rows');   
    man_hs(end+1) = h_n_chamber_rows;
    man_hs(end+1) = uicontrol('Style', 'text', 'String', 'x', ...
        'Position', [text_x+163 text_y 5 20], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr,...
        'FontSize',fs*12);   
    h_n_chamber_cols = uicontrol('Style', 'edit', 'String', '', ...
        'Position', [text_x+171 text_y 25 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12, ...
        'Enable','off',...
        'ToolTipString','columns');   
    man_hs(end+1) = h_n_chamber_cols;
    man_hs(end+1) = uicontrol('Style', 'text', 'String', ')', ...
        'Position', [text_x+197 text_y 5 20], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr,...
        'FontSize',fs*12);      

    % chamber shape (if manual selected)
    text_y = text_y - min_step_y;
    h_chamber_shape = uicontrol('Style', 'popup', 'String', 'rectangular|circular', ...
        'Position', [text_x+89 text_y-8 119 30], ...
        'HorizontalAlignment', 'center', ...
        'FontSize',fs*12, ...
        'BackgroundColor',figclr, ...
        'Visible', 'off', ...
        'Callback', @selectChamberShape);
    man_hs(end+1) = h_chamber_shape;
    exp_hs = [exp_hs man_hs];

    % fix chambers
    h_fix_chambers = uicontrol('Style', 'checkbox', 'String', 'fixed', ...
        'Position', [text_x+margin_x-2 text_y 60 25], ...
        'FontSize',fs*12, ...
        'Value', 0, 'BackgroundColor',figclr,...
        'ToolTipString','If checked, use this exact chamber position for all movies');           
    exp_hs(end+1) = h_fix_chambers;

    % number of flies per chamber
    text_y = text_y - min_step_y*1.3;
    exp_hs(end+1) = uicontrol('Style', 'text', 'String', '# flies per chamber: ', ...
        'Position', [text_x+margin_x text_y-5 150 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12,...
        'ToolTipString','Verify number of flies per chamber'); 
    h_n_flies = uicontrol('Style', 'edit', 'String', '', ...
        'Position', [text_x+margin_x2 text_y 56 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor','w',...
        'FontSize',fs*12, ...
        'Callback', @editNFlies);    
    exp_hs(end+1) = h_n_flies;

    % continue button
    text_y = text_y - min_step_y*1.2;
    exp_hs(end+1) = uicontrol('Style', 'pushbutton', 'String', 'continue', ...
        'Position', [text_x+margin_x text_y-4 218 30], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',figclr, ...
        'FontSize',fs*12,...
        'Callback', @acceptChambers);

    % horizontal menu divider
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+40 text_y-max_step_y*.35-1 315 1], ...
        'BackgroundColor',.5*[1 1 1]);        

    % hide manual settings
    for idx=1:numel(man_hs)
        set(man_hs(idx),'Visible','off');
    end

    % store handles
    handles.exp_hs              = exp_hs;
    handles.h_chamber_method    = h_chamber_method;
    handles.h_n_chambers        = h_n_chambers;
    handles.auto_hs             = auto_hs;
    handles.man_hs              = man_hs;
    handles.h_n_chamber_rows    = h_n_chamber_rows;
    handles.h_n_chamber_cols    = h_n_chamber_cols;
    handles.h_chamber_shape     = h_chamber_shape;
    handles.h_fix_chambers      = h_fix_chambers;
    handles.h_n_flies           = h_n_flies;    

    % PARAMETER TUNING ====================================================
    const.menu_pos_y(3) = text_y-max_step_y*.35-3; 

    % title shade
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+41 text_y-max_step_y*.35-38 315 37], ...
        'BackgroundColor',figclr*.93);       

    % title
    text_y = text_y - max_step_y;
    uicontrol('Style', 'text', 'String', 'Parameter tuning', ...
        'Position', [text_x text_y 250 25], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', figclr*.93, ...
        'FontSize',fs*16);     

    % foreground threshold
    text_y = text_y - min_step_y*1.3;
    uicontrol('Style','text','String','foreground threshold:',...
        'BackgroundColor', figclr, ...
        'HorizontalAlignment', 'left', ...
        'FontSize',fs*12, ...
        'Position',[text_x+margin_x text_y-5 150 25],...
        'ToolTipString','Adjust until all fly pixels are labeled (conservative is better)');    
    text_y = text_y - min_step_y+5;
    fg_slider_h = uicontrol('Style', 'slider',...
        'Min',0,'Max',1,'Value',.5,...
        'Position', [text_x+margin_x text_y 150 20],...
        'BackgroundColor',figclr, ...
        'Callback', @fgThrSlider); 
    fg_thr_h = uicontrol('Style','edit', ...
        'String','0.5',...
        'Position',[text_x+margin_x+160 text_y+2 35 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12, ...
        'Callback',@fgThrTextbox); 
    uicontrol('Style','pushbutton','String','~','Fontsize',fs*12,...
        'BackgroundColor',figclr,'Callback',@resetDefaultFg,...
        'Position',[text_x+margin_x+202 text_y+6 14 14],...
        'ToolTipString','Reset to default');    
    
    % body threshold
    text_y = text_y - min_step_y*.8;
    uicontrol('Style','text','String','body threshold:',...
        'BackgroundColor', figclr, ...
        'HorizontalAlignment', 'left', ...
        'FontSize',fs*12, ...
        'Position',[text_x+margin_x text_y-5 150 25],...
        'ToolTipString','Adjust until body is the right size (liberal is better)');
    text_y = text_y - min_step_y+5;
    bod_slider_h = uicontrol('Style', 'slider',...
        'Min',0,'Max',1,'Value',.5,...
        'Position', [text_x+margin_x text_y 150 20],...
        'BackgroundColor',figclr, ...
        'Callback', @bodThrSlider);     
    bod_thr_h = uicontrol('Style','edit', ...
        'String','0.5',...
        'Position',[text_x+margin_x+160 text_y+2 35 22], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12, ...
        'Callback',@bodThrTextbox); 
    uicontrol('Style','pushbutton','String','~','Fontsize',fs*12,...
        'BackgroundColor',figclr,'Callback',@resetDefaultBod,...
        'Position',[text_x+margin_x+202 text_y+6 14 14],...
        'ToolTipString','Reset to default');        

    % horizontal menu divider
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+40 text_y-max_step_y*.35+4 315 1], ...
        'BackgroundColor',.5*[1 1 1]);           

    % store handles
    handles.fg_slider_h     = fg_slider_h;
    handles.fg_thr_h        = fg_thr_h;
    handles.bod_slider_h    = bod_slider_h;
    handles.bod_thr_h       = bod_thr_h;

    % SAVE ================================================================
    % title shade
    uicontrol('Style', 'text', 'String', '', ...
        'Position', [sub_width+41 1 315 text_y-max_step_y*.35+3], ...
        'BackgroundColor',figclr*.93);       

    % save only
    text_y = text_y - max_step_y-10;
    uicontrol('Style', 'pushbutton', 'String', 'FINISH', ...
        'Position',[text_x+margin_x text_y 218 35], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12, ...
        'Callback', @finish,...
        'ToolTipString','Save calibration file'); 

    % SEGMENTATION VIEW ===================================================
    text_x = 17;
    text_y = 1;
    h_segview = [];
    % Generate new samples button
    h_segview(end+1) = uicontrol('Style', 'pushbutton', ...
        'String', 'random >>', ...
        'Position',[text_x text_y+1 80 25], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', figclr, ...
        'FontSize',fs*12, ...
        'Callback', @randomPic);  

    % Overlay pointsize list    
    h_segview(end+1) = uicontrol('Style', 'text', ...
        'String', 'overlay size:', ...
        'Position',[sub_width-130 text_y-2 100 25], ...
        'Value',2,...
        'HorizontalAlignment', 'left', ...
        'FontSize',fs*12, ...
        'BackgroundColor',figclr);
    segsize_h = uicontrol('Style', 'popup', ...
        'String', 'none|thin|thick', ...
        'Position',[sub_width-51 text_y 80 25], ...
        'Value',2,...
        'BackgroundColor',figclr,...
        'FontSize',fs*12, ...
        'Callback',@setPointsize);
    h_segview(end+1) = segsize_h;
    for idx=1:numel(h_segview)
        set(h_segview(idx),'Visible','off')
    end

    % hide everything
    cover_position = [sub_width+41 1 315 const.menu_pos_y(2)];    
    h_cover = uicontrol('Style', 'text', 'String', '', ...
        'Position', cover_position, ...
        'BackgroundColor',figclr);     

    const.menu_pos_y(4) = 1;

    % store handles
    handles.seg_h       = [];   
    handles.h_segview   = h_segview;
    handles.segsize_h   = segsize_h;  
    handles.h_cover     = h_cover;
end

function update_video(~,~)
    [path,~,ext] = fileparts(files.f_vid);
    [video_file, path] = uigetfile({ext},'Select video file',path);
    if ~video_file
        return
    end
    try 
        vinfo_ = video_open(fullfile(path,video_file),1);
        img = video_read_frame(vinfo_,floor(vinfo_.n_frames/2));
    catch
        customDialog('warn','Could not load video file',12*fig.fs)
        return; 
    end        
    files.f_vid  = fullfile(path,video_file);
    vars.img = img;
    set(handles.im_h,'cdata',vars.img);
    vinfo = vinfo_;    
    filename = vinfo.filename;    
    set(handles.h_file,'String',filename);
    pos = get(handles.h_file,'Position');
    sub_width = pos(3);
    extent = get(handles.h_file,'extent');
    while extent(3) > sub_width
        [~,filename] = strtok(filename,filesep); 
        set(handles.h_file,'String',['... ' filename]);
        extent = get(h_file,'extent');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% RESOLUTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editResolution(hObj,event) 
    % setResolution if 'return' key was pressed
    currentKey = get(gcf,'CurrentKey');
    if strcmp(currentKey,'return')
        setResolution(hObj,event);
    end
end    

% [continue] button pressed
function setResolution(~,~) 
    val = get(handles.h_fps,'String');
    fps = str2double(val);
    if isnan(fps), return; end
    val = get(handles.h_ruler_len,'String');
    length = str2double(val);        
    if isnan(length), return; end        

    % set temporal resolution
    calib.FPS = fps;

    % set spatial resolution
    points = getPosition(handles.ruler_h);
    pixdist = sqrt(sum((points(1,:)-points(2,:)).^2));
    ppm = pixdist/length;
    calib.PPM = ppm;

    % compute background
    bg = calib_bg_estimate(vinfo, ppm);
    if isnumeric(bg) && ~bg
        return
    end    

    % disable current componenets
    set(handles.ruler_h,'Visible','off')
    set(handles.vid_button_h,'Visible','off');
    try
    set(handles.ruler_h,'PickableParts','none');
    catch
    end
    for i=1:numel(handles.res_hs)
        set(handles.res_hs(i),'Enable','off')
    end
    drawnow
    
    % save background
    save(files.f_bg,'bg');    
    
    % fill in our best guess for number of flies
    tmp_vinfo = vinfo;
    im = video_read_frame(tmp_vinfo,0);    
    if bg.invert,
      bw_diff = abs((1-im)-bg.bg_mean);
    else
      bw_diff = abs(im-bg.bg_mean);
    end

    [~,b] = hist(bw_diff(:),10);
    thresh = b(5);    
    
    
    hfigbg = findall(0,'Name','Background model','type','figure');
    if isempty(hfigbg),
      hfigbg = figure('Name','Background model');
    else
      hfigbg = hfigbg(1);
      clf(hfigbg);
    end
    if bg.invert,
      bg_mean = 1 - bg.bg_mean;
    else
      bg_mean = bg.bg_mean ;
    end
    haxbg(1) = subplot(1,3,1,'Parent',hfigbg);
    if ndims(bg_mean) == 3,
      image(bg_mean,'Parent',haxbg(1));
    else      
      imagesc(bg_mean,'Parent',haxbg(1),[0,1]);
    end
    title(haxbg(1),'Bg Mean');
    haxbg(2) = subplot(1,3,2,'Parent',hfigbg);
    if ndims(bg.bg_var) == 3,
      image(bg.bg_var,'Parent',haxbg(2));
    else      
      imagesc(bg.bg_var,'Parent',haxbg(2),[0,prctile(bg.bg_var(:),99)]);
    end
    title(haxbg(2),'Bg Var');
    haxbg(3) = subplot(1,3,3,'Parent',hfigbg);
    if ndims(im) == 3,
      image(im,'Parent',haxbg(3));
    else
      imagesc(im,'Parent',haxbg(3),[0,1]);
    end
    title(haxbg(3),'Sample image');
    axis(haxbg,'image');
    linkaxes(haxbg);
    colormap(hfigbg,'gray');
    impixelinfo(hfigbg);
    
    frames = unique(round(linspace(0,vinfo.n_frames-2,20)));
    %frames = [0 vinfo.n_frames-2 floor(vinfo.n_frames/2)];
    blob_count = zeros(1,numel(frames));
    fprintf('Number of flies counted per frame:\n');
    for i=1:numel(frames) 
        im = video_read_frame(tmp_vinfo,frames(i));
        if bg.invert,
          bw_diff = abs((1-im)-bg.bg_mean);
        else
          bw_diff = abs(im-bg.bg_mean);
        end
        bw_th_diff = bw_diff > thresh;
        cc = bwconncomp(bw_th_diff);
        props = regionprops(cc,{'MinorAxisLength','MajorAxisLength','Centroid'});
        n_candidates = 0;
        axis_lengths = zeros(cc.NumObjects,2);
        for c=1:cc.NumObjects
            axis_lengths(c,1) = props(c).MinorAxisLength;
            axis_lengths(c,2) = props(c).MajorAxisLength;
            if props(c).MajorAxisLength < calib.PPM*4.5 && ...
               props(c).MajorAxisLength > calib.PPM && ...
               props(c).MinorAxisLength > calib.PPM/2
                n_candidates = n_candidates + 1;
            end
        end
        blob_count(i) = n_candidates;
        fprintf('  Frame %d: %d flies\n',frames(i),blob_count(i));
    end        
    vars.total_n_flies = median(blob_count);
    set(handles.h_n_flies,'String',num2str(vars.total_n_flies)); 
    set(handles.h_n_chambers,'String','1');

%     % update image to white out background
%     if bg.invert,
%       bw_diff = 1-abs((1-vars.img)-bg.bg_mean);
%     else
%       bw_diff = 1-abs(vars.img-bg.bg_mean);
%     end
%     bw_diff = (bw_diff-min(bw_diff(:)))/(max(bw_diff(:))-min(bw_diff(:)));
%     set(handles.im_h,'cdata',(2*bw_diff+vars.img)/3);
    set(handles.im_h,'cdata',vars.img);

    % make next step visible
    cover_position = get(handles.h_cover,'Position');
    cover_position(end) = const.menu_pos_y(3);    
    set(handles.h_cover,'Position',cover_position);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EXPERIMENTAL SETUP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setChamberMethod(hObj,~) 
    val = get(hObj,'Value');
    if val == 1             % automatic detection
        % change visibilities
        calib.auto_detect = 1;
        for i=1:numel(handles.man_hs)
            set(handles.man_hs(i),'Visible','off');
        end
        for i=1:numel(handles.auto_hs)
            set(handles.auto_hs(i),'Visible','on');
        end            
        set(handles.h_fix_chambers,'Value',0)
        set(handles.h_fix_chambers,'Enable','on');
        set(handles.h_n_chambers,'Enable','on');
        % hide rois
        for i=1:numel(handles.roi_h)
            set(handles.roi_h(i),'Visible','off')
            try
            set(handles.roi_h(i),'PickableParts','none');
            catch
            end
        end
        if ~isempty(handles.ROIsize_h)
            set(handles.ROIsize_h,'Visible','off');
        end
        if ~isempty(handles.ROIsize_h_auto)
            set(handles.ROIsize_h_auto,'Visible','off');
        end
        % hide roi_full
        if ~isempty(handles.roi_h_full)
            set(handles.roi_h_full,'Visible','off')
            try
            set(handles.roi_h_full,'PickableParts','none');
            catch
            end
        end
        % show roi_autos
        for i=1:numel(handles.roi_h_auto)
            set(handles.roi_h_auto(i),'Visible','on')          
            try
            set(handles.roi_h_auto(i),'PickableParts','none');
            catch            
            setResizable(handles.roi_h_auto(i),0);    
            end
        end
        if ~isempty(handles.ROIsize_h_auto)
            set(handles.ROIsize_h_auto,'Visible','on');
        end
        if numel(handles.roi_h_auto) > 0
            set(handles.h_n_chambers,'String',numel(handles.roi_h_auto));
            % set arena type to correspond to detected chamber
            if isa(handles.roi_h_auto(1),'imellipse'), 
                calib.roi_type = 2;
            else
                calib.roi_type = 1;
            end
            % update number of flies per chamber if it hasn't been validated
            n_flies = ceil(vars.total_n_flies/numel(handles.roi_h_auto));        
            set(handles.h_n_flies,'String',num2str(n_flies));             
        end           
    elseif val == 2         % manual setting
        % change visibilities
        calib.auto_detect = 0;
        for i=1:numel(handles.man_hs)
            set(handles.man_hs(i),'Visible','on');
        end
        for i=1:numel(handles.auto_hs)
            set(handles.auto_hs(i),'Visible','off');
        end
        set(handles.h_fix_chambers,'Value',1)
        set(handles.h_fix_chambers,'Enable','on');
        set(handles.h_chamber_shape,'Value',calib.roi_type);
        set(handles.h_n_chambers,'Enable','on');
        % hide current roi_autos
        for i=1:numel(handles.roi_h_auto)
            set(handles.roi_h_auto(i),'Visible','off')
            try
            set(handles.roi_h_auto(i),'PickableParts','none');
            catch
            end
        end        
        if ~isempty(handles.ROIsize_h_auto)
            set(handles.ROIsize_h_auto,'Visible','off');
        end 
        % hide roi_full
        if ~isempty(handles.roi_h_full)
            set(handles.roi_h_full,'Visible','off')
            try
            set(handles.roi_h_full,'PickableParts','none');
            catch
            end
        end
        if numel(handles.roi_h) > 0
            % show rois
            for i=1:numel(handles.roi_h)
                set(handles.roi_h(i),'Visible','on')
                try
                set(handles.roi_h(i),'PickableParts','all');
                catch
                end
            end
            if ~isempty(handles.ROIsize_h)
                set(handles.ROIsize_h,'Visible','on');
            end
            set(handles.h_n_chambers,'String',numel(handles.roi_h));
            set(handles.h_n_chamber_rows,'String','');
            set(handles.h_n_chamber_cols,'String','');
            % set arena type to correspond to detected chamber
            if isa(handles.roi_h(1),'imellipse'), 
                calib.roi_type = 2;
            else
                calib.roi_type = 1;
            end
            set(handles.h_chamber_shape,'Value',calib.roi_type);
        else
            % split areas into number of areas selected                                            
            calib.n_rows = floor(sqrt(calib.n_chambers));
            calib.n_cols = ceil(calib.n_chambers/calib.n_rows);
            set(handles.h_n_chamber_rows,'String',num2str(calib.n_rows));
            set(handles.h_n_chamber_cols,'String',num2str(calib.n_cols));                
            % set dummy roi 
            handles.roi_h = imrect(handles.sub_h,[20 20 size(vars.img,2)-40 size(vars.img,1)-40]);
            setColor(handles.roi_h,'b')
            addNewPositionCallback(handles.roi_h,@updateROI);                 
            % set rois
            arrangeChambers(calib.n_chambers,calib.n_rows,calib.n_cols);            
        end
        % update number of flies per chamber if it hasn't been validated
        n_flies = ceil(vars.total_n_flies/numel(handles.roi_h));        
        set(handles.h_n_flies,'String',num2str(n_flies)); 
    else                % use entire image
        % change visibilities
        calib.auto_detect = 0;
        calib.roi_type = 1;
        calib.n_chambers = 1;
        % update number of flies per chamber if it hasn't been validated
        set(handles.h_n_flies,'String',num2str(vars.total_n_flies)); 
        calib.n_rows = 1;
        calib.n_cols = 1;
        for i=1:numel(handles.man_hs)
            set(handles.man_hs(i),'Visible','off');
        end
        for i=1:numel(handles.auto_hs)
            set(handles.auto_hs(i),'Visible','off');
        end
        set(handles.h_fix_chambers,'Value',1)
        set(handles.h_fix_chambers,'Enable','off');
        set(handles.h_n_chambers,'String','1');
        set(handles.h_n_chambers,'Enable','off');        
        % hide current roi_autos
        for i=1:numel(handles.roi_h_auto)
            set(handles.roi_h_auto(i),'Visible','off')
            try
            set(handles.roi_h_auto(i),'PickableParts','none');
            catch
            end
        end
        if ~isempty(handles.ROIsize_h_auto)
            set(handles.ROIsize_h_auto,'Visible','off');
        end           
        % hide current roi_manual
        for i=1:numel(handles.roi_h)
            set(handles.roi_h(i),'Visible','off')
            try
            set(handles.roi_h(i),'PickableParts','none');
            catch
            end
        end
        if ~isempty(handles.ROIsize_h)
            set(handles.ROIsize_h,'Visible','off');
        end
        % set dummy roi 
        if ~isempty(handles.roi_h_full)
            set(handles.roi_h_full,'Visible','on'); 
        else
            handles.roi_h_full = imrect(handles.sub_h,[1 1 size(vars.img,2)-1 size(vars.img,1)-1]);
            setColor(handles.roi_h_full,'b')       
            rect = getPosition(handles.roi_h_full);
            Xlim = rect(1)+[0 rect(3)];
            Ylim = rect(2)+[0 rect(4)];
            tmp_fnc = makeConstrainToRectFcn('imrect',Xlim,Ylim);
            setPositionConstraintFcn(handles.roi_h_full,tmp_fnc);  
        end
        setResizable(handles.roi_h_full,0);    
    end
    updateROI();
end

function editNumChambers(hObj,event)
    str = get(hObj,'String');
    n_chambers = str2double(str);        
    if isnan(n_chambers) || round(n_chambers)~= n_chambers || numel(handles.roi_h)==n_chambers
        return        
    end

    % update number of flies per chamber if it hasn't been validated
    %if ~vars.overridden_n_flies
        % set number of flies guess
        n_flies = ceil(vars.total_n_flies/n_chambers);        
        set(handles.h_n_flies,'String',num2str(n_flies)); 
    %end

    if calib.auto_detect
        % detectChambers if 'return' key was pressed and auto detect is on
        currentKey = get(gcf,'CurrentKey');
        calib.n_chambers = n_chambers;
        if strcmp(currentKey,'return')
            detectChambers(hObj,event);
        end
    else
        % split areas into number of areas selected                                            
        n_rows = floor(sqrt(n_chambers));
        n_cols = ceil(n_chambers/n_rows);
        calib.n_chambers = n_chambers;
        calib.n_rows = n_rows;
        calib.n_cols = n_cols;
        set(handles.h_n_chamber_rows,'String',num2str(n_rows));
        set(handles.h_n_chamber_cols,'String',num2str(n_cols));
        arrangeChambers(n_chambers,n_rows,n_cols);                
    end
end

function editNumChamberRows(hObj,~) 
    str = get(hObj,'String');
    val = str2double(str);
    if isnan(val) || round(val)~= val 
        return;
    else % split areas into number of areas selected  
        n_rows = max(1,min(val,calib.n_chambers));
        n_cols = ceil(calib.n_chambers/n_rows);
        set(handles.h_n_chamber_rows,'String',num2str(n_rows));
        set(handles.h_n_chamber_cols,'String',num2str(n_cols));
        arrangeChambers(calib.n_chambers,n_rows,n_cols);
        calib.n_rows = n_rows;
        calib.n_cols = n_cols;
    end             
end

function detectChambers(~,~) 
    val = get(handles.h_n_chambers,'String');
    n_chambers = str2double(val);
    calib.n_chambers = n_chambers;
    if isnan(n_chambers), return; end

    [centers, r, w, h] = calib_chamber_detect(bg,n_chambers);
    if numel(centers) == 1 && ~centers
        return
    end

    [~,first] = min(sum(centers,2));
    centers = [centers(first,:); centers([1:first-1 first+1:end],:)];

    % remove old detections
    roi_h_auto = handles.roi_h_auto;
    for i=1:numel(roi_h_auto)
        delete(roi_h_auto(i));
    end

    % add new detections
    if ~isempty(r)
        % chamber is circular
        imshape = 'imellipse';
        for i=1:size(centers,1)
            center = centers(i,:);
            if i==1
                roi_h_auto = imellipse(handles.sub_h,[center(2)-r center(1)-r r*2+1 r*2+1]);
            else
                roi_h_auto(i) = imellipse(handles.sub_h,[center(2)-r center(1)-r r*2+1 r*2+1]);
            end
        end
        calib.roi_type = 2;
    else
        % chamber is rectangular
        imshape = 'imrect';
        for i=1:size(centers,1)
            center = centers(i,:);
            x_1 = center(2)-w/2; x_1 = max(1,x_1);
            y_1 = center(1)-h/2; y_1 = max(1,y_1);
            if i==1
                roi_h_auto = imrect(handles.sub_h,[x_1 y_1 w h]);
            else
                roi_h_auto(i) = imrect(handles.sub_h,[x_1 y_1 w h]);
            end
        end
        calib.roi_type = 1;
    end
    for i=1:numel(roi_h_auto)
        % make sure user can't delete rois
        try roi_h_auto(i).Deletable = 0; 
        catch
        end
        % fix the chambers to their original positions
        setResizable(roi_h_auto(i),0);
        rect = getPosition(roi_h_auto(i));
        Xlim = rect(1)+[0 rect(3)];
        Ylim = rect(2)+[0 rect(4)];
        tmp_fnc = makeConstrainToRectFcn(imshape,Xlim,Ylim);
        setPositionConstraintFcn(roi_h_auto(i),tmp_fnc);                     
    end
    calib.centroids = centers;
    calib.r = r;
    calib.w = w;
    calib.h = h;
    calib.auto_detect = 1;
    handles.roi_h_auto = roi_h_auto;
    set(handles.h_fix_chambers,'Value',0)
    updateROI();
end

function editNFlies(hObj,~) 
    val = get(hObj,'String');
    n_flies = str2double(val);
    if ~isempty(n_flies)
        vars.overridden_n_flies = 1;
        vars.total_n_flies = n_flies * calib.n_chambers;
    end
end

function setOtherBboxes(~,~) 
    if calib.n_chambers == 1
        return
    end
    rects = cell(1,calib.n_chambers);
    for i=1:calib.n_chambers
        rects{i} = getPosition(handles.roi_h(i));
    end

    % find size of control box
    size_x = rects{1}(3);
    size_y = rects{1}(4);

    % check whether object was moved or scaled
    moved = size_x == calib.w && size_y  == calib.h;        
    if ~moved
        % scale all other boxes the same way as the control box
        start_x = rects{1}(1);
        start_y = rects{1}(2);
        x_prev = calib.centroids(1,1)-calib.w/2;
        y_prev = calib.centroids(1,2)-calib.h/2;
        dx = start_x-x_prev;
        dy = start_y-y_prev;
        for i=2:numel(rects)
            rects{i} = [rects{i}(1)+dx rects{i}(2)+dy size_x size_y];
        end
        calib.w = size_x;
        calib.h = size_y;
    end
    % update positions
    for i=1:numel(handles.roi_h)
        setPosition(handles.roi_h(i),rects{i})
        calib.centroids(i,1) = rects{i}(1)+rects{i}(3)/2;
        calib.centroids(i,2) = rects{i}(2)+rects{i}(4)/2;
    end 
end

function updateROI(~,~) 
    detect_method = get(handles.h_chamber_method,'Value');
    if detect_method == 1
        h = handles.roi_h_auto;
        size_h = handles.ROIsize_h_auto;
    else
        h = handles.roi_h;
        size_h = handles.ROIsize_h;
    end

    if numel(h) == 0
        return;
    end
    str = get(handles.h_ruler_len,'String');
    mmdist = str2double(str);
    if ~isnan(mmdist)
        points = getPosition(handles.ruler_h);
        pixdist = sqrt(sum((points(1,:)-points(2,:)).^2));
        ppm = pixdist/mmdist;
        bbox = getPosition(h(1));
        w = round(bbox(3)/ppm*10)/10;
        h = round(bbox(4)/ppm*10)/10;
        if ~isempty(size_h)
            delete(size_h);
        end
        size_h = text(bbox(1)+10,bbox(2)+15,[num2str(w) ' mm x ' num2str(h) ' mm'],'Color',[.2 .2 .2], 'FontSize',fs*12, 'FontWeight','bold');
    end
    if detect_method == 1
        handles.ROIsize_h_auto = size_h;
    else
        handles.ROIsize_h = size_h;
    end
end

function selectChamberShape(hObj,~) 
    val = get(hObj,'Value');
    if calib.roi_type == val, return; end
    if val == 1
        for i=1:calib.n_chambers
            rect = getPosition(handles.roi_h(i));
            delete(handles.roi_h(i));
            temp_roi_h(i) = imrect(handles.sub_h,rect);
            try temp_roi_h(i).Deletable = 0; end
            if i==1
                setColor(temp_roi_h(i),'b')
            else
                setColor(temp_roi_h(i),[0 .8 0])
            end
        end
        handles.roi_h = temp_roi_h;
        calib.roi_type = 1;
        addNewPositionCallback(handles.roi_h(1),@updateROI);
        addNewPositionCallback(handles.roi_h(1),@setOtherBboxes);
    elseif val == 2
        for i=1:calib.n_chambers
            rect = getPosition(handles.roi_h(i));
            delete(handles.roi_h(i));
            temp_roi_h(i) = imellipse(handles.sub_h,rect);
            try temp_roi_h(i).Deletable = 0; end
            if i==1
                setColor(temp_roi_h(i),'b')
            else
                setColor(temp_roi_h(i),[0 .8 0])
            end
        end
        handles.roi_h = temp_roi_h;
        calib.roi_type = 2;
        addNewPositionCallback(handles.roi_h(1),@updateROI);
        addNewPositionCallback(handles.roi_h(1),@setOtherBboxes);
    end
end

function arrangeChambers(val,n_rows,n_cols) 
    % get current ROI range
    roi_h = handles.roi_h;
    rects = cell(1,calib.n_chambers);
    min_x = inf; max_x = -inf;
    min_y = inf; max_y = -inf;
    for i=1:numel(roi_h)
        rects{i} = getPosition(roi_h(i));
        min_x = min(rects{i}(1),min_x);
        max_x = max(rects{i}(1)+rects{i}(3),max_x);
        min_y = min(rects{i}(2),min_y);
        max_y = max(rects{i}(2)+rects{i}(4),max_y);
    end
    rect = [min_x min_y max_x-min_x max_y-min_y];

    % delete current ROIs            
    for i=1:numel(roi_h)
        delete(roi_h(i));
    end

    % set new ROIs                                 
    if n_cols == 1
        size_x = rect(3);
        buff_x = 0;
    else
        size_x = rect(3)/n_cols * 0.9;
        buff_x = (rect(3)-n_cols*size_x)/(n_cols-1);
    end
    if n_rows == 1
        size_y = rect(4);
        buff_y = 0;
    else
        size_y = rect(4)/n_rows * 0.9;
        buff_y = (rect(4)-n_rows*size_y)/(n_rows-1);
    end
    i = 1;
    rects = cell(1,val); 
    for y=1:n_rows
        for x=1:n_cols
            rects{i} = [rect(1)+(size_x+buff_x)*(x-1) ...
                        rect(2)+(size_y+buff_y)*(y-1) ...
                        size_x size_y];
            i = i+1;
        end
    end

    for i=1:val
        if calib.roi_type == 1
            if i==1
                roi_h = imrect(handles.sub_h,rects{i});
            else
                roi_h(i) = imrect(handles.sub_h,rects{i});
            end
        else
            if i==1
                roi_h = imellipse(handles.sub_h,rects{i});
            else
                roi_h(i) = imellipse(handles.sub_h,rects{i});
            end
        end
        try roi_h(i).Deletable = 0; end
        if i==1
            setColor(roi_h(i),'b')
        else
            setColor(roi_h(i),[0 .8 0])
        end
    end
    calib.n_chambers = val;  
    calib.centroids = zeros(numel(rects),2);
    for i=1:numel(rects)
        calib.centroids(i,1) = rects{i}(1)+rects{i}(3)/2;
        calib.centroids(i,2) = rects{i}(2)+rects{i}(4)/2;            
    end
    calib.r = 0;
    calib.w = rects{1}(3);
    calib.h = rects{1}(4);

    addNewPositionCallback(roi_h(1),@updateROI);
    addNewPositionCallback(roi_h(1),@setOtherBboxes);
    handles.roi_h = roi_h;
    updateROI        
end

% [continue] button pressed
function acceptChambers(~,~) 
    % get number of flies
    val = get(handles.h_n_flies,'String');
    n_flies = str2double(val);
    if isnan(n_flies), return; end

    % get chamber info
    detect_method = get(handles.h_chamber_method,'Value');
    if detect_method == 1
        h = handles.roi_h_auto;
        h_size = handles.ROIsize_h_auto;
    elseif detect_method == 2
        h = handles.roi_h;
        h_size = handles.ROIsize_h;
    else
        h = handles.roi_h_full;
    end
    if isempty(h),
        errordlg('No chambers exist.  You have to detect/draw them before you click the "continue" button.') ;
        return
    end

    % generate chamber masks and rois
    masks = cell(1,numel(h));
    rois = cell(1,numel(h));
    full_mask = zeros(size(bg.bg_mean));
    for i=1:numel(h)
        if detect_method == 3
            mask = true(size(bg.bg_mean));
            rois{i} = [1 1 size(mask)];
        else
            mask = h(i).createMask;
            [I,J] = find(mask);
            rois{i} = [min(I) min(J) max(I)-min(I)+1 max(J)-min(J)+1];
        end
        full_mask = full_mask + mask;
        masks{i} = mask;        
    end
    calib.masks = masks;
    calib.mask = calib.masks{1};
    calib.full_mask = full_mask;  
    calib.rois = rois;    
    calib.n_flies = n_flies;
    calib.magnet = 0;
    calib.dead_female = 0;

    % hide chamber detections
    for i=1:numel(h)
        set(h(i),'Visible','off')
        try
        set(h(i),'PickableParts','none');
        catch
        end
    end
    if exist('h_size','var')
        set(h_size,'Visible','off')
    end
    % disable components
    for i=1:numel(handles.exp_hs)
        set(handles.exp_hs(i),'Enable','off')
    end
    drawnow
    
    % infer parameters
    calib.params = infer_tracker_params();     
    
    % make next step visible
    cover_position = get(handles.h_cover,'Position');
    cover_position(end) = const.menu_pos_y(4);    
    set(handles.h_cover,'Position',cover_position);   
    for i=1:numel(handles.h_segview)
        set(handles.h_segview(i),'Visible','on')
    end

    % enable zooming
    zoom on

    % display legend for segmentation colors
    hold on
    hs = [];
    hs(1) = plot(-1,-1,'o','markerEdgeColor','k','markerFaceColor',const.clr.body,'markersize',10,'linewidth',1);
    hs(2) = plot(-1,-1,'o','markerEdgeColor','k','markerFaceColor',const.clr.wings,'markersize',10,'linewidth',1);
    hs(3) = plot(-1,-1,'o','markerEdgeColor','k','markerFaceColor',const.clr.legs,'markersize',10,'linewidth',1);
    hs(4) = plot(-1,-1,'o','markerEdgeColor','k','markerFaceColor','w','markersize',10,'linewidth',1);

    % update image to white out background
    img = vars.img;
    if bg.invert,
      bw_diff = 1-abs((1-img)-bg.bg_mean);
    else
      bw_diff = 1-abs(img-bg.bg_mean);
    end
    bw_diff = (bw_diff-min(bw_diff(:)))/(max(bw_diff(:))-min(bw_diff(:)));
    im_disp = (2*bw_diff+img)/3;
    im_disp(~calib.mask) = im_disp(~calib.mask)*.8;
    set(handles.im_h,'cdata',im_disp);
    
    % set FOV to show just one chamber
    mask_id = vars.mask_id;
    setAxis(mask_id,size(img));
    
    % set slider values
    fg_thr = 1-calib.params.fg_th_weak;
    set(handles.fg_slider_h,'Value',fg_thr);
    str = sprintf('%0.2f',fg_thr);
    set(handles.fg_thr_h,'String',str);
    body_thr = 1-calib.params.body_th_weak;    
    set(handles.bod_slider_h,'Value',body_thr);
    str = sprintf('%0.2f',body_thr);
    set(handles.bod_thr_h,'String',str);

    % set pointsize to fit the size of pixels per screen-mm 
    autoSetPointsize();

    % segment flies
    vars.dets = track_detect(vinfo,bg,calib,[],{img}, true);  
    vars.dets = track_segment(vars.dets,calib,0);
    updateSeg()
    
    legend(hs,{'body','wings','legs','other'},'FontSize',fs*11,'AutoUpdate','off');
    legend('boxoff')

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SEGMENTATION OVERLAY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateSeg() 
    % remove previous segmentation overlay
    delete(handles.seg_h(ishandle(handles.seg_h)));
%     for i=1:numel(handles.seg_h),
%         delete(handles.seg_h(i));
%     end

    pointsize = vars.pointsize;
    
    % display segmentation
    seg_h = [];         
    if vars.overlay_seg                     
        % overlay foreground
        shift = [0 0];
        roi_sz = size(vars.img);
        if isfield(vars.dets,'roi')
            shift = [vars.dets.roi(1)-1 vars.dets.roi(2)-1];
            roi_sz = [vars.dets.roi(3)-vars.dets.roi(1)+1 vars.dets.roi(4)-vars.dets.roi(2)+1];
        end
        fg_list = vars.dets.frame_data{1}.fg_cc.PixelIdxList;
        for i=1:numel(fg_list)
            [I,J] = ind2sub(roi_sz,fg_list{i});
            I = I+shift(1); J = J+shift(2);
            if numel(I)>0
                seg_h(end+1) = plot(J,I,'ow','MarkerSize',pointsize,'markerEdgeColor','none','markerFaceColor','w');
            end
        end
        % overlay body
        body_list = vars.dets.frame_data{1}.body_cc.PixelIdxList;
        for i=1:numel(body_list)
            [I,J] = ind2sub(roi_sz,body_list{i});
            I = I+shift(1); J = J+shift(2);
            if numel(I)>0
                seg_h(end+1) = plot(J,I,'o','color',const.clr.body,'MarkerSize',pointsize,'markerEdgeColor','none','markerFaceColor',const.clr.body);
            end
        end        

        % overlay wings
        wing_list = vars.dets.frame_data{1}.seg.body_wing_pixels;
        for i=1:numel(wing_list)
            [I,J] = ind2sub(roi_sz,wing_list{i});
            I = I+shift(1); J = J+shift(2);
            if numel(I)>0
                seg_h(end+1) = plot(J,I,'o','color',const.clr.wings,'MarkerSize',pointsize,'markerEdgeColor','none','markerFaceColor',const.clr.wings);
            end
        end   
        % overly legs
        leg_list = vars.dets.frame_data{1}.seg.body_leg_pixels;
        for i=1:numel(leg_list)
            [I,J] = ind2sub(roi_sz,leg_list{i});
            I = I+shift(1); J = J+shift(2);
            if numel(I)>0
                seg_h(end+1) = plot(J,I,'o','color',const.clr.legs,'MarkerSize',pointsize,'markerEdgeColor','none','markerFaceColor',const.clr.legs);
            end
        end
    end
    handles.seg_h = seg_h;
end

function autoSetPointsize(hObj,~) 
    ax = axis; 
    img_width = ax(2)-ax(1); img_height = ax(4)-ax(3);  
    mask_width = calib.rois{vars.mask_id}(4);
    mask_height = calib.rois{vars.mask_id}(3);
    if ~isempty(vars.pref_pointsize) && ...
          (img_width == mask_width || img_height == mask_height)
           vars.pointsize = vars.pref_pointsize; 
           if vars.pointsize == 4
               set(handles.segsize_h,'value',3)
           else
               set(handles.segsize_h,'value',2)
           end
    else
        sub_width = img_width/img_height*const.sub_height;
        screen_pix_sz = sub_width/img_width;        
        if screen_pix_sz>3
            vars.pointsize = 4;
            set(handles.segsize_h,'value',3)
        else
            vars.pointsize = 1.4;
            set(handles.segsize_h,'value',2)
        end       
    end
    vars.overlay_seg = 1;
    if nargin > 0 && ~isempty(hObj)
        updateSeg()
    end
end

function setPointsize(hObj,~) 
    val = get(hObj,'Value');
    if val == 1
        vars.overlay_seg = 0;
    elseif val == 2
        vars.overlay_seg = 1;
        vars.pointsize = 1.4;
    elseif val == 3
        vars.overlay_seg = 2;
        vars.pointsize = 4;
    end
    if val > 1
        % check whether fully zoomed out and set preferred pointsize
        ax = axis; 
        img_width = ax(2)-ax(1); img_height = ax(4)-ax(3);
        mask_width = calib.rois{vars.mask_id}(4);
        mask_height = calib.rois{vars.mask_id}(3);
        if img_width == mask_width || img_height == mask_height
           vars.pref_pointsize = vars.pointsize; 
        end
    end
    updateSeg()
end

function setAxis(mask_id,imsz)
    x_min = calib.rois{mask_id}(2);
    y_min = calib.rois{mask_id}(1);
    x_max = x_min + calib.rois{mask_id}(4) - 1;
    y_max = y_min + calib.rois{mask_id}(3) - 1;
    % keep aspect ratio
    w = x_max-x_min+1;
    h = y_max-y_min+1;
    if w/h > imsz(2)/imsz(1)
        % adjust height of fov
        h_new = round(w/imsz(2)*imsz(1));
        d = round((h_new-h)/2);
        y_min = max(1,y_min-d);
        y_max = min(imsz(1),y_min+h_new-1);
        y_min = y_max-h_new+1;
    elseif w/h < imsz(2)/imsz(1)
        % adjust width of fov
        w_new = round(h/imsz(1)*imsz(2));
        d = round((w_new-w)/2);
        x_min = max(1,x_min-d);
        x_max = min(imsz(2),x_min+w_new-1);
        x_min = x_max-w_new+1;
    end
    axis equal
    axis([x_min-.5 x_max+.5 y_min-.5 y_max+.5]);
end

function randomPic(~,~) 
    tmp_vinfo = vinfo;
    frame = randi(tmp_vinfo.n_frames,1,1);
    img = video_read_frame(tmp_vinfo,frame);        
    % set FOV to be a random mask
    mask_id = randi(numel(calib.rois));
    setAxis(mask_id,size(img));    
    calib.mask = calib.masks{mask_id};
    % update segmentation overlay
    vars.dets = track_detect(vinfo,bg,calib,[],{img}, true);
    vars.dets = track_segment(vars.dets,calib,0);
    % update image to white out background
    if bg.invert,
      bw_diff = 1-abs((1-img)-bg.bg_mean);
    else
      bw_diff = 1-abs(img-bg.bg_mean);
    end
    bw_diff = (bw_diff-min(bw_diff(:)))/(max(bw_diff(:))-min(bw_diff(:)));
    im_disp = (2*bw_diff+img)/3;
    im_disp(~calib.mask) = im_disp(~calib.mask)*.8;
    set(handles.im_h,'cdata',im_disp);
    vars.img = img;
    vars.mask_id = mask_id;
    % automatically set pointsize
    autoSetPointsize();
    % update segmentation overlay
    updateSeg()
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PARAMETER TUNING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function params = infer_tracker_params() 
    % scale factors
    ref_ppm = 12;   % resolution of video used to set params initially
    sf = calib.PPM/ref_ppm;

    % kernels for erosion and dilation of body and fg masks,
    % used in detectionand segmentation
    se_disk = cell(1,5);
    body_border = max(1,round(1*sf));  
    se_disk{1} = strel('disk',1,0);                                        % NEVER USED
    se_disk{2} = strel('disk',body_border,0);
    radius = max(1,floor(round(2* 3*sf^.5)/2));
    se_disk{3} = strel('disk',radius,0);
    se_disk{4} = strel('disk',max(radius+1,floor(round(2*(3+1)*sf^.5)/2)),0);
    params.strels = se_disk;
    
    % MATCHING
    params.match_cost_th         = calib.PPM*10;         % 5 fly lengths
    params.min_cost_mat_diff     = calib.PPM;            % 1/2 fly length
    % (these are updated later to match the distribution of the data)
    factor = 1.5;
    params.mean_major_axis = calib.PPM*2;         % approx fly length
    params.mean_minor_axis = calib.PPM;
    params.mean_area       = calib.PPM^2*1.5;
    params.quartile_major_axis = params.mean_major_axis*(1+[-1,1]/4);
    params.quartile_minor_axis = params.mean_minor_axis*(1+[-1,1]/4);
    params.quartile_area = params.mean_area*(1+[-1,1]/4);
    params.max_major_axis  = params.mean_major_axis*factor;
    params.max_minor_axis  = params.mean_minor_axis*factor;
    params.max_area        = params.mean_area*factor;    
    
    % DETECTION
    params.r_props = {'Area','Centroid','Orientation' ...
                      'MajorAxisLength','MinorAxisLength'};
    params.fg_mask_buff         = round(5*sf);          
    params.fg_min_size          = 70*sf^2;              
    params.fg_max_size          = params.fg_min_size * 30;
    params.fly_comp             = 3;                    
    % - infer params from video statistics
    % (these are updated later in interface)
    a = params.mean_major_axis/2;
    b = params.mean_minor_axis/2;
    num_pix = round(a*b*pi) * (calib.n_flies+calib.magnet+calib.dead_female);    
    im_fg = max((bg.bg_mean - vars.img),[],3);
    im_fg = im_fg./max(.1,bg.bg_mean); % to account for difference on food
    im_fg = im_fg/max(max(im_fg(:)),max(vars.img(:))); % normalize
    sorted_pix = sort(im_fg(calib.mask==1),'descend');
    sorted_thr = min(sorted_pix(1:num_pix));
    %sorted_thr = prctile(sorted_pix(1:num_pix),1);
    params.body_th_weak  = sorted_thr;
    params.fg_th_weak    = 0.1;  
    params.fg_th_strong  = .2*params.fg_th_weak + .8*params.body_th_weak;    
    % set default params
    default.fg_th_weak   = params.fg_th_weak;
    default.body_th_weak = params.body_th_weak;
    
    % SEGMENTATION
    % - legs
    params.joint_dist_th          = 2;                   
    params.joint_area_max         = 8*sf;                
    % - wings
    params.max_body_wing_ang      = 1.8;  
    params.wing_area_min          = 20*sf^2;                                
    params.min_ori_discr_length   = 8*sf;                
    % - fix ori    
    params.min_resting_body_ratio = 1.5;                
    params.min_resting_body_area  = max(7,100*sf^2);      
    params.min_wing_area          = max(7,10*sf^2);       
    params.vel_thresh             = 20*calib.PPM/calib.FPS; %20 mm/sec
    params.spike_thresh           = 2.5;
    % .2 seconds with velocity or wings incorrect will give a cost of 
    % .2*calib.FPS 
    % we want this to be equal to the cost of flipping by 180 degrees twice
    % w*2*pi = .2*calib.FPS
    % w = .2*calib.FPS/(2*pi)
    params.choose_orientations_weight_theta = .2*calib.FPS/(2*pi);
    vel_fil_w = ceil(calib.FPS/30); % filter for computing velocities
    params.vel_fil = normpdf(linspace(-2,2,vel_fil_w));
    params.vel_fil = params.vel_fil / sum(params.vel_fil);
    params.vel_fil = conv([-1,0,1]/2,params.vel_fil)';
end    

function updateFgThr(val)     
    calib.params.fg_th_weak = 1-val;
    calib.params.fg_th_strong = .2*calib.params.fg_th_weak + .8*calib.params.body_th_weak;
    vars.dets = track_detect(vinfo,bg,calib,[],{vars.img}, true);
    vars.dets = track_segment(vars.dets,calib,0);
    str = sprintf('%0.2f',val);
    set(handles.fg_thr_h,'String',str);
    set(handles.fg_slider_h,'Value',val);
    updateSeg()        
end
function fgThrSlider(hObj,~) 
    val = get(hObj,'Value');
    updateFgThr(val);
end
function fgThrTextbox(hObj,~) 
    str = get(hObj,'String');
    val = str2double(str);
    if isnan(val), return; end
    updateFgThr(val);
end    

function updateBodThr(val)
    %calib.params.body_th_weak = val;
    calib.params.body_th_weak = 1-val;
    calib.params.fg_th_strong = .2*calib.params.fg_th_weak + .8*calib.params.body_th_weak;
    vars.dets = track_detect(vinfo,bg,calib,[],{vars.img}, true);
    vars.dets = track_segment(vars.dets,calib,0);
    str = sprintf('%0.2f',val);
    set(handles.bod_thr_h,'String',str);
    set(handles.bod_slider_h,'Value',val);
    updateSeg()        
end
function bodThrSlider(hObj,~) 
    val = get(hObj,'Value');
    updateBodThr(val);
end
function bodThrTextbox(hObj,~) 
    str = get(hObj,'String');
    val = str2double(str);
    if isnan(val), return; end
    updateBodThr(val);
end    

function resetDefaultFg(~,~)
    updateFgThr(1-default.fg_th_weak);    
end
function resetDefaultBod(~,~)
    updateBodThr(1-default.body_th_weak);
end

% [FINISH] button pressed
function finish(~,~)    
    % load more images
    tmp_vinfo = vinfo;
    n_frames = tmp_vinfo.n_frames;
    step = round(n_frames/6);
    start = step;
    limit = step*4+1;
    imgs = cell(1,4);
    frames = start:step:limit;
    for idx=1:4
        imgs{idx} = video_read_frame(tmp_vinfo,frames(idx));
    end       
    % remove masks where no flies are present
    nonempty_chambers = zeros(1,numel(calib.rois));    
    blob_count = zeros(1,numel(calib.rois));
    calib.full_mask = zeros(size(calib.full_mask));
    for i=1:numel(calib.rois)
        calib.mask = calib.masks{i};
        dets = track_detect(tmp_vinfo,bg,calib,[],imgs, true);
        n_flies = 0;
        for j=1:numel(imgs)
            n_flies = n_flies + dets.frame_data{j}.body_cc.NumObjects;
        end
        blob_count(i) = n_flies/numel(imgs);
        if n_flies > 0
            nonempty_chambers(i) = 1;
            calib.full_mask = calib.full_mask | calib.masks{i};
        else
            disp(['Chamber ' num2str(i) ' appears to be empty'])
        end
    end    
    if sum(nonempty_chambers) == 0
        return
    end         
    calib.valid_chambers = nonempty_chambers;
    
    % determine body size thresholds using 100 sparse frames from video
    calib.mask = calib.full_mask;
    n_flies = calib.n_flies;
    calib.n_flies = calib.n_flies * sum(calib.valid_chambers);
    fr.start = 1;
    fr.step = round(tmp_vinfo.n_frames/100);
    fr.limit = tmp_vinfo.n_frames;
    dets = track_detect(tmp_vinfo,bg,calib,fr,[],true);    
    n_frms = numel(dets.frame_data);
    
    num_flies = calib.n_flies;
    body_sizes = zeros(n_frms*num_flies,3);
    contrasts = zeros(n_frms*num_flies,1);
    c_count = 0;
    count = 0;
    for f=1:n_frms
       body_cc = dets.frame_data{f}.body_cc;       
       body_props = dets.frame_data{f}.body_props;
       body_contrast = dets.frame_data{f}.body_contrast;
       contrasts(c_count+(1:numel(body_contrast))) = body_contrast;
       c_count = c_count+numel(body_contrast);
       if body_cc.NumObjects ~= calib.n_flies
           continue;
       end
       big_enough = 1;
       for c=1:body_cc.NumObjects
           if body_props(c).MajorAxisLength < calib.PPM
               big_enough = 0; break;
           end
       end
       if ~big_enough, continue; end
       for c=1:body_cc.NumObjects
           count = count + 1;
           body_sizes(count,1) = body_props(c).MajorAxisLength;
           body_sizes(count,2) = body_props(c).MinorAxisLength;
           body_sizes(count,3) = body_props(c).Area;
       end
    end
    if count > 0
       body_sizes = body_sizes(1:count,:); 
       medians = prctile(body_sizes,50,1);
       quartiles1 = prctile(body_sizes,25,1);
       quartiles2 = prctile(body_sizes,75,1);
       maxs = prctile(body_sizes,95) * 1.15;
       calib.params.mean_major_axis = medians(1);
       calib.params.mean_minor_axis = medians(2);    
       calib.params.mean_area       = medians(3);
       calib.params.quartile_major_axis = [quartiles1(1),quartiles2(1)];
       calib.params.quartile_minor_axis = [quartiles1(2),quartiles2(2)];
       calib.params.quartile_area = [quartiles1(3),quartiles2(3)];

       calib.params.max_major_axis  = maxs(1);
       calib.params.max_minor_axis  = maxs(2);    
       calib.params.max_area        = maxs(3)*1.15;       
    end  
    contrasts = contrasts(contrasts>0);
    m = median(contrasts);
    s = median(abs(contrasts-m));
    calib.params.contrast_th = m-5*s;
    calib.n_flies = n_flies;
    
    % delete figure
    delete(handles.fig_h)
    % save results
    save(files.f_info,'calib')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Close interface function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function uiClose(~,~) 
    success = 0;
    % delete figure
    delete(handles.fig_h);  
end

end
