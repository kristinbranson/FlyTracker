
% Visualize tracked videos, correct identities, and annotate behavior.
%
% To run interface, use:
%
%    visualizer
%
function visualizer()

    % files
    files.video_dir = '.';             % default video directory
    parentdir = fileparts(mfilename('fullpath'));
    defpath = fullfile(parentdir,'action_list.txt'); 
    files.action_list_path = defpath;   % contains default list of actions

    % add tracker to path if its not there already
    check = which('is_atomic_detection');
    if isempty(check)
        addpath(genpath(parentdir));
    end
    
    % data
    vinfo   = []; % video data
    trk     = []; % tracking data
    seg     = []; % segmentation data
    feat    = []; % feature data
    actions = []; % action data
    swap    = []; % swap data

    % other variables 
    fig     = []; % figure variables
    state   = []; % state variables
    bool    = []; % boolean variables
    quest   = []; % questions and answers

    % initialize variables
    initVars();

    % interface handles
    handles = [];

    % initialize interface
    initInterface(); 
    
    beep off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Interface setup functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function initInterface()
    % --- MAIN WINDOW
    scrsz = get(0,'ScreenSize');   
    sub_width  = 600;
    sub_height = sub_width/4*3;
    fig_height = sub_height + 300;
    fig_width  = sub_width + 400;
    
    limit = scrsz(3:4)*.9;
    scale = 1;
    if fig_width > limit(1) || fig_height > limit(2)
        scale = min(limit(1)/fig_width, limit(2)/fig_height);
        fig_height = round(fig_height*scale);
        fig_width = round(fig_width*scale);        
    end
    sub_height = round(sub_height*scale);
    fig.sub_height = round(sub_height*scale);
    fig.sub_width = round(sub_width*scale);
    fig.scale = scale;
    fig.height = fig_height;
    fig.width = fig_width;
    
    fig_h = figure('Name','FlyTracker-1.0.5: Visualizer','NumberTitle','off',...
        'Position',[scrsz(3)/2-fig_width/2 scrsz(4)/2-fig_height/2 fig_width fig_height],...
        'Resize','on','Menubar', 'none',...
        'WindowButtonDownFcn',@mousePressed,...
        'WindowButtonUpFcn',@mouseReleased,...
        'KeyPressFcn',@keyPressed,...
        'Color',.94*[1 1 1]);
    set(fig_h,'CloseRequestFcn',@myClose);
    fs = 72/get(0,'ScreenPixelsPerInch'); % scale fonts to resemble the mac    
    fs = fs*scale;
    fig.fs = fs;
    
    figclr = get(fig_h,'color');
    fig.color = figclr;
    fig.zoom_imgs  = getIcons(figclr);
    % Menuitems (Video, Track, GroundTruth, Prediction)
    vid_h = uimenu(fig_h,'Label','Video');
    uimenu(vid_h,'Label','Open','Callback',@openVideo);
    trk_h = uimenu(fig_h,'Label','Track','enable','off');
    uimenu(trk_h,'Label','Open','Callback',@openTrk);
    trkxls_h = uimenu(trk_h,'Label','Save as xls','enable','off','Callback',@saveTrkXls);
    gtm_h = uimenu(fig_h,'Label','GroundTruth','enable','off');
    uimenu(gtm_h,'Label','Open','Callback',@openGTlabel);
    uimenu(gtm_h,'Label','New','Callback',@newGTlabel);
    gtxls_h = uimenu(gtm_h,'Label','Save as xls','enable','off','Callback',@saveGTXls);
    predm_h = uimenu(fig_h,'Label','Prediction','enable','off');
    uimenu(predm_h,'Label','Open','Callback',@openPREDlabel);        
    predxls_h = uimenu(predm_h,'Label','Save as xls','enable','off','Callback',@savePredXls);
    
    % store handles
    handles.fig_h     = fig_h;
    handles.trk_h     = trk_h;
    handles.gtm_h     = gtm_h;
    handles.predm_h   = predm_h;
    handles.trkxls_h  = trkxls_h; 
    handles.gtxls_h   = gtxls_h;
    handles.predxls_h = predxls_h;

    % --- LEFT PANEL
    % Image window
    m_v = 30*scale; % vertical margin
    m_h = 50*scale; % horizontal margin
    sub_h = subplot('Position',[m_h/fig_width 1-(m_v+sub_height)/fig_height fig.sub_width/fig_width sub_height/fig_height]);
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    imshow(ones(sub_height,fig.sub_width)*.9);
    set(sub_h,'box','on','XTickLabel',[], 'YTickLabel',[], 'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)
    hold on
    colormap(gray)  

    % display video path
    position = [m_h fig_height-m_v*.75 fig.sub_width m_v/2];
    videopath_h = addui('text',' ',12*fs,position);       
    % - chamber zoom in
    position = [m_h-22*scale fig_height-m_v-19*scale 20*scale 20*scale];
    chamber_h(1) = addui('pushbutton','+',14*fs,position,@chamberZoomIn);
    set(chamber_h(1),'tooltip','View only current chamber','visible','off');    
    % - chamber zoom out
    position = [m_h-22*scale fig_height-m_v-41*scale 20*scale 20*scale];
    chamber_h(2) = addui('pushbutton','-',14*fs,position,@chamberZoomOut);
    set(chamber_h(2),'tooltip','View all chambers','visible','off');           

    % Navigation slider
    pos_h = m_h;
    pos_v = fig_height-sub_height-m_v-18*scale;
    position = [pos_h pos_v fig.sub_width+2*scale 15*scale];
    slider_h = uicontrol(fig_h,'style','slider','units','normalized',...        
              'position',position./[fig_width fig_height fig_width fig_height],...
              'Min',0,'Max',1,'value',0,'backgroundcolor',figclr,...
              'callback',@vidSlider);   
    video_h(1) = slider_h;

    % Navigation controls
    pos_v = pos_v - 27*scale;
    position = [pos_h pos_v 50*scale 25*scale];
    video_play_h = addui('pushbutton','play',12*fs,position,@playVid,'left');
    set(video_play_h,'backgroundcolor',[.3 .7 .4])
    video_h(end+1) = video_play_h;
   
    pos_h = pos_h+65*scale;
    position = [pos_h pos_v 60*scale 25*scale];
    video_frame_h = addui('edit','1',12*fs,position,@goToFrame); 
    video_h(end+1) = video_frame_h;
    
    position = [pos_h+60*scale pos_v 20*scale 20*scale];
    video_h(end+1) = addui('text','/',12*fs,position);
    
    position = [pos_h+80*scale pos_v 70*scale 20*scale];
    video_nfr_h = addui('text','0',12*fs,position);
    set(video_nfr_h,'horizontalalignment','left');
    video_h(end+1) = video_nfr_h;  

    position = [pos_h+150*scale pos_v 70*scale 20*scale];
    video_h(end+1) = addui('text','framerate:',12*fs,position);

    position = [pos_h+220*scale pos_v 50*scale 25*scale];
    framerate_h = addui('edit',num2str(state.framerate),12*fs,position,@setFramerate);
    video_h(end+1) = framerate_h;
    
    position = [pos_h+330*scale pos_v 75*scale 25*scale];
    jump_button_h = addui('pushbutton','undo jump',12*fs,position,@goBackToFrame,'left');
    set(jump_button_h,'visible','off','backgroundcolor',figclr*.9);
    video_h(end+1) = jump_button_h;      
    for i=1:numel(video_h)
        set(video_h(i),'enable','off')
    end

    % Pan and zoom buttons
    pos_h = m_h + fig.sub_width - 70*scale;
    pos_v = pos_v + 5*scale;
    % - zoom in
    position = [pos_h pos_v 20*scale 20*scale];
    zoom_h(1) = addui('pushbutton','',1,position,@zoomIn);
    set(zoom_h(1),'cdata',fig.zoom_imgs{1});
    % - zoom out
    position = [pos_h+26*scale pos_v 20*scale 20*scale];
    zoom_h(2) = addui('pushbutton','',1,position,@zoomOut);
    set(zoom_h(2),'cdata',fig.zoom_imgs{2});    
    % - pan
    position = [pos_h+26*2*scale pos_v 20*scale 20*scale];
    zoom_h(3) = addui('pushbutton','',1,position,@panFunc);
    set(zoom_h(3),'cdata',fig.zoom_imgs{3});

    % GT and pred visualization
    pos_v = pos_v - 40*scale;
    position = [1 pos_v m_h-5*scale 20*scale];
    gtl_h = addui('text','GT:',12*fs,position);
    set(gtl_h,'enable','off');
    gt_h = subplot('Position',[m_h/fig_width pos_v/fig_height fig.sub_width/fig_width 20*scale/fig_height]);    
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    image(ones(1,fig.sub_width)*.9*255);
    set(gt_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)

    pos_v = pos_v - 40*scale;
    position = [1 pos_v m_h-5*scale 20*scale];
    predl_h = addui('text','Pred.:',12*fs,position);
    set(predl_h,'enable','off');
    pred_h = subplot('Position',[m_h/fig_width pos_v/fig_height fig.sub_width/fig_width 20*scale/fig_height]);    
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    image(ones(1,fig.sub_width)*.9*255);
    set(pred_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)

    % Feature
    pos_v = pos_v - 120*scale;
    feat_h = subplot('Position',[m_h/fig_width pos_v/fig_height fig.sub_width/fig_width 80*scale/fig_height]);    
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    image(ones(1,fig.sub_width)*.9*255);
    set(feat_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)
    % - feature dropdown list
    position = [m_h-6*scale pos_v+72*scale 170*scale 30*scale];
    featl_h = addui('popup','Feature',12*fs,position,@setFeat);
    set(featl_h,'enable','off');
    % - current feature value
    position = [m_h+fig.sub_width/2-20*scale 10*scale 40*scale 15*scale];
    feat_val_h = addui('text','value',11*fs,position);
    set(feat_val_h,'enable','off');
    
    % help annotating functions          
    pos_h = 220*scale;
    pos_v = pos_v + 83*scale;
    position = [pos_h pos_v 145*scale 20*scale];
    help_anno_h = addui('checkbox','apply threshold',11*fs,position,@needHelpRadiobutton);
    set(help_anno_h,'value',0,'enable','off');

    % feat search help
    pos_h = pos_h + 140*scale;      
    position = [pos_h pos_v 55*scale 18*scale];
    feat_nav_h = addui('text','condition:',11*fs,position,[],'left');
    pos_h = pos_h + 57*scale;      
    
    position = [pos_h pos_v 60*scale 20*scale];
    feat_cond_h = addui('popup','>|<',12*fs,position,@setCondition,'left');
    feat_nav_h(end+1) = feat_cond_h;      
    
    pos_h = pos_h + 70*scale;      
    position = [pos_h pos_v 60*scale 18*scale];
    feat_nav_h(end+1) = addui('text','threshold:',11*fs,position,[],'left');

    pos_h = pos_h + 60*scale;      
    position = [pos_h pos_v 40*scale 20*scale];
    feat_thresh_h = addui('edit','0',11*fs,position,@threshEdit);
    feat_nav_h(end+1) = feat_thresh_h; 
    
    pos_h = pos_h + 42*scale;  
    position = [pos_h pos_v 30*scale 20*scale];
    feat_nav_h(end+1) = addui('pushbutton','<<',12*fs,position,@findPrevButton);
    
    pos_h = pos_h + 32*scale;      
    position = [pos_h pos_v 30*scale 20*scale];
    feat_nav_h(end+1) = addui('pushbutton','>>',12*fs,position,@findNextButton);
    for i=1:numel(feat_nav_h)
        set(feat_nav_h(i),'visible','off');
    end
          
    % vertical menu divider
    pos_h = fig.sub_width+m_h+30*scale;
    position = [pos_h 1 1 fig_height];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',.5*[1 1 1]);             

    % store handles
    handles.sub_h         = sub_h;
    handles.videopath_h   = videopath_h;
    handles.chamber_h     = chamber_h;
    handles.slider_h      = slider_h; 
    handles.video_h       = video_h;
    handles.video_play_h  = video_play_h;
    handles.video_frame_h = video_frame_h;
    handles.video_nfr_h   = video_nfr_h;
    handles.framerate_h   = framerate_h;
    handles.jump_button_h = jump_button_h;
    handles.zoom_h        = zoom_h;
    handles.gt_h          = gt_h;
    handles.gtl_h         = gtl_h;
    handles.pred_h        = pred_h;
    handles.predl_h       = predl_h;
    handles.feat_h        = feat_h;
    handles.featl_h       = featl_h;
    handles.feat_val_h    = feat_val_h;

    % --- RIGHT PANEL
    % VISUALS
    % - title
    panel_h = pos_h + 1;
    panel_width = fig_width-pos_h;
    pos_v = fig_height-35*scale;
    
    % set background to make vertical divider is only one pixel
    position = [pos_h+1 1 panel_width-1 fig_height];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr);                 
    
    position = [panel_h pos_v panel_width 36*scale];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr*.93);
    position = [panel_h+15*scale pos_v+3*scale 170*scale 25*scale];
    uicontrol('Style', 'text', 'String', 'Display settings', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'HorizontalAlignment', 'left','BackgroundColor', figclr*.93, 'FontSize',fs*16); 

    % - display options  
    track_h = [];
    pos_h = panel_h + 20*scale;
    pos_v = pos_v - 65*scale;
    
    buff = 20*scale;
    position = [pos_h+5*scale pos_v+buff+2*scale 260*scale 1];
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr*.9);
    position = [pos_h+5*scale pos_v+buff+3*scale 260*scale 1];
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr);          
          
    position = [pos_h+10*scale pos_v 140*scale 20*scale];    
    show_track_h = addui('checkbox','show tracks',13*fs,position,@showAll);
    track_h(end+1) = show_track_h;
    
    position = [pos_h+5*scale pos_v-3*scale 135*scale 1];    
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr*.9);        
    position = [pos_h+4*scale pos_v-4*scale 135*scale 1];    
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr);         
    position = [pos_h+140*scale pos_v-64*scale 1 61*scale];
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr*.9);              
    position = [pos_h+141*scale pos_v-64*scale 1 61*scale];
    uicontrol(fig_h,'style','text','string','','units','normalized',...
              'position', position./[fig_width fig_height fig_width fig_height],...
              'backgroundColor',figclr);                        

    position = [pos_h+150*scale pos_v 140*scale 20*scale];
    show_separate_h = addui('checkbox','ellipse',13*fs,position,@showEllipse);
    
    position = [pos_h+150*scale pos_v-buff 140*scale 20*scale];
    show_separate_h(end+1) = addui('checkbox','trail',13*fs,position,@showTrail);
    
    position = [pos_h+150*scale pos_v-2*buff 140*scale 20*scale];
    show_separate_h(end+1) = addui('checkbox','wings',13*fs,position,@showWings);
     
    position = [pos_h+150*scale pos_v-3*buff 140*scale 20*scale];
    show_separate_h(end+1) = addui('checkbox','legs',13*fs,position,@showLegs);
    track_h = [track_h show_separate_h];
    
    position = [pos_h+10*scale pos_v+1.3*buff 140*scale 20*scale];
    show_img_h = addui('checkbox','show image',13*fs,position,@showImg);                
    track_h(end+1) = show_img_h;      
    
    position = [pos_h+120*scale pos_v+1.3*buff 150*scale 20*scale];
    show_seg_h = addui('checkbox','show segmentation',13*fs,position,@showSeg);
    set(show_seg_h,'visible','off');                
    track_h(end+1) = show_seg_h;      
    
    pos_v = pos_v - 35*scale;
    position = [pos_h+12*scale pos_v 80*scale 20*scale];
    track_h(end+1) = addui('text','Active fly id:',13*fs,position,[],'left');

    position = [pos_h+92*scale pos_v 30*scale 20*scale];
    active_fly_h = addui('text','1',13*fs,position,[],'left');
    track_h(end+1) = active_fly_h;
    
    position = [pos_h+12*scale pos_v-20*scale 100*scale 20*scale];
    auto_zoom_h = addui('checkbox','auto zoom',13*fs,position,@autoZoom);            
    track_h(end+1) = auto_zoom_h;       
    
    % TRACKING CONTROLS
    % - title
    pos_v = pos_v - 95*scale;
    position = [panel_h pos_v+36*scale panel_width 1];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',.5*[1 1 1]);    
    position = [panel_h pos_v panel_width 36*scale];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr*.93);  
    position = [panel_h+15*scale pos_v+3*scale 170*scale 25*scale];
    uicontrol('Style', 'text', 'String', 'Identity correction','units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'HorizontalAlignment', 'left','BackgroundColor', figclr*.93, ...
        'FontSize',fs*16); 
    position = [panel_h+(panel_width-40)*scale pos_v+3*scale 40*scale 25*scale];
    id_hot_h = uicontrol('Style','text','String','*',...
        'units','normalized','FontSize',fs*30,'visible','off',...
        'Position',position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr*.93,'ForegroundColor',[1 1 1],...
        'ToolTip','Hot keys: arrowup (next), arrowdown (prev), spacebar (play), ''s'' (swap)');

    % - potential identity swaps
    pos_v = pos_v - 60*scale;
    position = [pos_h pos_v panel_width 30*scale];
    track_h(end+1) = addui('text','Potential id swaps:',13*fs,position,[],'left');

    position = [pos_h+123*scale pos_v+12*scale 157*scale 20*scale];
    switch_sort_h = addui('popup','sort by frame|sort by ambiguity',12*fs,position,@switchSortBy);        
    track_h(end+1) = switch_sort_h;
    
    pos_v = pos_v - 25*scale;  
    position = [pos_h+10*scale pos_v 15*scale 20*scale];
    track_h(end+1) = addui('pushbutton','<',12*fs,position,@idSwitchDown);

    position = [pos_h+30*scale pos_v-2*scale 35*scale 25*scale];
    swap_id_h = addui('edit','0',12*fs,position,@setIdSwitch);
    track_h(end+1) = swap_id_h;      
    
    position = [pos_h+70*scale pos_v 15*scale 20*scale];
    track_h(end+1) = addui('pushbutton','>',12*fs,position,@idSwitchUp);

    position = [pos_h+86*scale pos_v 15*scale 20*scale];
    track_h(end+1) = addui('text','/',12*fs,position);

    position = [pos_h+100*scale pos_v 35*scale 20*scale];
    nswaps_h = addui('text','0',12*fs,position,[],'left');
    track_h(end+1) = nswaps_h;      
    
    position = [pos_h+130*scale pos_v-2*scale 65*scale 25*scale];
    play_swap_h = addui('pushbutton','play clip',12*fs,position,{@playBout,'swap'});
    set(play_swap_h,'backgroundcolor',[.3 .7 .4]);       
    track_h(end+1) = play_swap_h;      
    
    position = [pos_h+210*scale pos_v-2*scale 60*scale 25*scale];
    do_swap_h = addui('pushbutton','swap',12*fs,position,@swapIds);
    set(do_swap_h,'tooltipstring',' Swap identities at current frame ',...
        'backgroundcolor',[.5 .65 .9]);
    track_h(end+1) = do_swap_h;
    
    pos_v = pos_v - 55*scale;      
    position = [pos_h pos_v fig_width-pos_h-20*scale 35*scale];
    save_swaps_h = addui('pushbutton','save changes',12*fs,position,@saveTrk);
    track_h(end+1) = save_swaps_h;      
    for i=1:numel(track_h)
        set(track_h(i),'enable','off')
    end

    % store handles
    handles.track_h         = track_h;
    handles.show_track_h    = show_track_h;
    handles.show_separate_h = show_separate_h;
    handles.show_seg_h      = show_seg_h;
    handles.show_img_h      = show_img_h;
    handles.active_fly_h    = active_fly_h;
    handles.auto_zoom_h     = auto_zoom_h;
    handles.swap_id_h       = swap_id_h;
    handles.nswaps_h        = nswaps_h;
    handles.play_swap_h     = play_swap_h;
    handles.save_swaps_h    = save_swaps_h;
    handles.do_swap_h       = do_swap_h;
    handles.switch_sort_h   = switch_sort_h;
    handles.id_hot_h        = id_hot_h;

    % BEHAVIOR CONTROLS
    behavior_h = [];
    % - title
    pos_v = pos_v - 75*scale;
    position = [panel_h pos_v+36*scale panel_width 1];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',.5*[1 1 1]);
    position = [panel_h pos_v panel_width 36*scale];
    uicontrol('Style', 'text', 'String', '', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr*.93);       
    position = [panel_h+15*scale pos_v+3*scale 190*scale 25*scale];
    uicontrol('Style', 'text', 'String', 'Behavior annotation', 'units','normalized',...
        'Position', position./[fig_width fig_height fig_width fig_height],...
        'HorizontalAlignment', 'left', 'BackgroundColor', figclr*.93, ...
        'FontSize',fs*16); 
    position = [panel_h+(panel_width-40)*scale pos_v+3*scale 40*scale 25*scale];
    beh_hot_h = uicontrol('Style','text','String','*',...
        'units','normalized','FontSize',fs*30,'visible','off',...
        'Position',position./[fig_width fig_height fig_width fig_height],...
        'BackgroundColor',figclr*.93,'ForegroundColor',[1 1 1],...
        'ToolTip','Hot keys: arrowup (next), arrowdown (prev), spacebar (play), ''a'' (add), ''d'' (delete)');    

    % - select behavior
    pos_v = pos_v - 60*scale;
    position = [pos_h pos_v 70*scale 30*scale];    
    behavior_h(end+1) = addui('text','Action:',13*fs,position,[],'left');

    position = [pos_h+75*scale pos_v 150*scale 30*scale];
    action_h = addui('popup','all|touch|lunge|wing threat|wing extension',...
                     12*fs,position,@setBeh,'left');
    behavior_h(end+1) = action_h;      
    
    pos_v = pos_v - 30*scale;
    position = [pos_h pos_v 100*scale 30*scale];
    behavior_h(end+1) = addui('text','Bout type:',13*fs,position,[],'left');

    position = [pos_h+75*scale pos_v 150*scale 30*scale];
    bout_type_h = addui('popup','ground truth|prediction|false postives|false negatives',...
                        12*fs,position,@setBehType,'left');    
    behavior_h(end+1) = bout_type_h;

    % - go to bout
    pos_v = pos_v - 30*scale;
    position = [pos_h+10*scale pos_v 15*scale 20*scale];
    behavior_h(end+1) = addui('pushbutton','<',12*fs,position,@boutDown);

    position = [pos_h+30*scale pos_v-2*scale 35*scale 25*scale];
    bout_id_h = addui('edit','0',12*fs,position,@setBout);
    behavior_h(end+1) = bout_id_h;      
    
    position = [pos_h+70*scale pos_v 15*scale 20*scale];
    behavior_h(end+1) = addui('pushbutton','>',12*fs,position,@boutUp);

    position = [pos_h+86*scale pos_v-2*scale 15*scale 20*scale];
    behavior_h(end+1) = addui('text','/',12*fs,position);

    position = [pos_h+100*scale pos_v-2*scale 35*scale 20*scale];
    nbouts_h = addui('text','0',12*fs,position,[],'left');  
    behavior_h(end+1) = nbouts_h;          
    
    position = [pos_h+130*scale pos_v-2*scale 65*scale 25*scale];
    play_bout_h = addui('pushbutton','play clip',12*fs,position,{@playBout,'beh'});
    set(play_bout_h,'backgroundcolor',[.3 .7 .4]);
    behavior_h(end+1) = play_bout_h;          
    bout_nav_h = behavior_h;

    % bout manipulation
    pos_v = pos_v - 55*scale;
    % - add bout
    buttonsz = 65*scale;
    buff = 4*scale;
    position = [pos_h pos_v buttonsz+6*scale 30*scale];
    bout_manip_h(1) = addui('pushbutton','ADD NEW',11*fs,position,@addBout);
    set(bout_manip_h(1),'foregroundcolor',[0 .7 0]);
    % - delete bout
    position = [pos_h+buttonsz+buff+6*scale pos_v buttonsz 30*scale];
    bout_manip_h(2) = addui('pushbutton','DELETE',11*fs,position,@deleteBout);
    set(bout_manip_h(2),'foregroundcolor',[.9 0 0]);  
    % - move to other
    position = [pos_h+buttonsz*2+2*buff+6*scale pos_v buttonsz 30*scale];
    bout_manip_h(3) = addui('pushbutton','MOVE',11*fs,position,@moveBout);
    set(bout_manip_h(3),'foregroundcolor',[0 0 .9]);
    % - copy to other
    position = [pos_h+buttonsz*3+3*buff+6*scale pos_v buttonsz 30*scale];
    bout_manip_h(4) = addui('pushbutton','COPY',11*fs,position,@copyBout);
    set(bout_manip_h(4),'foregroundcolor',[.9 .7 0]);
    bout_add_h = bout_manip_h(1);
    bout_move_h = bout_manip_h(3);
    bout_copy_h = bout_manip_h(4);
    behavior_h(end+(1:4)) = bout_manip_h;

    % select certainty of annotation
    pos_v = pos_v - 40*scale;
    position = [pos_h+2*scale pos_v-7*scale 70*scale 30*scale];
    cert_str_h = addui('text','Certainty:',12*fs,position,[],'left');

    position = [pos_h+70*scale pos_v 70*scale 30*scale];
    cert_maybe_h = addui('radiobutton','maybe',10*fs,position,@radioMaybe);

    position = [pos_h+135*scale pos_v 70*scale 30*scale];
    cert_prob_h = addui('radiobutton','probably',10*fs,position,@radioProbably);
    set(cert_prob_h,'value',1);

    position = [pos_h+200*scale pos_v 70*scale 30*scale];
    cert_def_h = addui('radiobutton','definitely',10*fs,position,@radioDefinitely);     
    cert_h = [cert_str_h cert_maybe_h cert_prob_h cert_def_h];
    behavior_h = [behavior_h cert_h];

    % save bouts function      
    pos_v = pos_v - 50*scale;
    position = [pos_h pos_v fig_width-pos_h-20*scale 35*scale];
    save_anno_h = addui('pushbutton','save changes',12*fs,position,@saveLabel);
    behavior_h(end+1) = save_anno_h; 
    % disable behavior components until label files are loaded            
    for i=1:numel(behavior_h)
        set(behavior_h(i),'enable','off')
    end           
          
    % store handles
    handles.behavior_h    = behavior_h;
    handles.action_h      = action_h;
    handles.bout_type_h   = bout_type_h;
    handles.bout_id_h     = bout_id_h;
    handles.nbouts_h      = nbouts_h;
    handles.bout_nav_h    = bout_nav_h;
    handles.bout_manip_h  = bout_manip_h;
    handles.bout_add_h    = bout_add_h;
    handles.bout_move_h   = bout_move_h;
    handles.bout_copy_h   = bout_copy_h;
    handles.play_bout_h   = play_bout_h; 
    handles.cert_str_h    = cert_str_h;
    handles.cert_maybe_h  = cert_maybe_h;
    handles.cert_prob_h   = cert_prob_h;
    handles.cert_def_h    = cert_def_h;
    handles.cert_h        = cert_h;
    handles.save_anno_h   = save_anno_h;
    handles.help_anno_h   = help_anno_h;
    handles.feat_nav_h    = feat_nav_h;
    handles.feat_cond_h   = feat_cond_h;
    handles.feat_thresh_h = feat_thresh_h; 
    handles.beh_hot_h     = beh_hot_h;
    
    % figure handles
    handles.img_h  = [];
    handles.plot_h = [];
end

function h = addui(style,string,fontsz,position,callback,halign)
    figsz = [fig.width fig.height fig.width fig.height];
    h = uicontrol('style',style,'string',string,'fontsize',fontsz,...
        'units','normalized','position',position./figsz,...
        'backgroundcolor',fig.color,...
        'horizontalalignment','center');
    if nargin > 4 && ~isempty(callback)
        set(h,'callback',callback);
    end   
    if nargin > 5 && ~isempty(halign)
        set(h,'horizontalalignment',halign);
    end
end

function resetVars()
    % reset files
    newfiles.video_dir = files.video_dir;
    newfiles.action_list_path = files.action_list_path;
    files = newfiles;

    % reset data
    trk     = [];
    seg     = [];
    feat    = [];    
    actions = [];
    swap    = [];
    
    % reset interface handles
    % - xls handles
    set(handles.trkxls_h,'enable','off');
    set(handles.gtxls_h,'enable','off');
    set(handles.predxls_h,'enable','off');
    % - feature navigation
    set(handles.featl_h,'value',1,'string','Feature','enable','off');
    set(handles.gtl_h,'enable','off');
    set(handles.predl_h,'enable','off');
    set(handles.feat_val_h,'string','value','enable','off');
    set(handles.help_anno_h,'value',0);
    set(handles.help_anno_h,'enable','off');    
    for j=1:numel(handles.feat_nav_h)
        set(handles.feat_nav_h(j),'visible','off');
    end
    % - swaps
    set(handles.id_hot_h,'Visible','off');            
    set(handles.show_track_h,'value',1);    
    for j=1:numel(handles.show_separate_h)
        set(handles.show_separate_h(j),'value',1);
    end    
    set(handles.show_seg_h,'value',0);
    set(handles.show_img_h,'value',1);
    set(handles.active_fly_h,'string',1);
    set(handles.auto_zoom_h,'value',0);
    set(handles.switch_sort_h,'value',1);    
    for j=1:numel(handles.track_h)
        set(handles.track_h(j),'enable','off')
    end       
    % - actions     
    set(handles.beh_hot_h,'Visible','off');
    set(handles.action_h,'value',1);
    set(handles.bout_type_h,'value',1);    
    for j=1:numel(handles.behavior_h)
        set(handles.behavior_h(j),'enable','off')
    end
    
    % clear subplots
    imshowAxesVisible = iptgetpref('ImshowAxesVisible');
    iptsetpref('ImshowAxesVisible','on')
    % gt
    subplot(handles.gt_h)
    hold off; cla
    image(ones(1,fig.sub_width)*.9*255);colormap gray
    set(handles.gt_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    % pred
    subplot(handles.pred_h)
    hold off; cla
    image(ones(1,fig.sub_width)*.9*255);colormap gray
    set(handles.pred_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    % feat
    subplot(handles.feat_h)
    hold off; cla
    image(ones(1,fig.sub_width)*.9*255);colormap gray
    set(handles.feat_h,'box','on','XTick',[],'YTick',[],'tickLength',[0 0]);
    iptsetpref('ImshowAxesVisible',imshowAxesVisible)
end

function initVars()
    % figure variables
    fig.clrs       = [];
    fig.sub_ax     = [];

    % state variables
    state.curr_frame    = 1;
    state.prev_frame    = 1;
    state.curr_feat     = 1;
    state.curr_beh      = 1;
    state.curr_beh_type = 1;
    state.curr_chamber  = 1;
    state.curr_flies    = [];
    state.active_fly    = 1;    
    state.active_bout   = [];
    state.new_bout      = [];
    state.key_mode      = 0; % 0:nothing 1:swaps 2:behaviors
    state.featvec_conditioned = [];
    state.roi = [];
    state.screen_pix_sz = 1;
    state.linewidth     = 1;
    state.framerate     = 30;    
    state.fly_length    = 1; % median length of fly in pixels

    % boolean variables
    bool.show_trk       = 1;
    bool.show_legs      = 1;
    bool.show_wings     = 1;
    bool.show_trail     = 1;
    bool.show_ellipse   = 1;
    bool.show_seg       = 0;
    bool.show_img       = 1;
    bool.do_play        = 0;
    bool.stop_bout_play = 0;
    bool.updating       = 0;
    bool.auto_zoom      = 0;
    bool.moving_bout_boundaries = 0;  
    
    % question data
    quest.ask_overwrite_trk = 1;
    quest.ans_overwrite_trk = '';
    quest.ask_change_cert   = 1;
    quest.ans_change_cert   = '';
    quest.ask_delete_bout   = 1;
    quest.ans_delete_bout   = '';
    
    % action data
    actions.beh_labels = {};
    actions.beh_colors = [];
    actions.gt = [];
    actions.pred = [];
    actions.fn = [];
    actions.fp = [];
    actions.curr_bouts = [];
    actions.curr_frames = [];
    actions.overlapTHRESH = 0.1;    
    
    % swap data
    swap.swaps     = [];
    swap.id_switch = 0;
    swap.switches  = [];
    swap.all_switches = [];
end

function iconImgs = getIcons(figclr)
    icon_names = {'tool_zoom_in.png','tool_zoom_out.png','tool_hand.png'};
    iconImgs = cell(1,numel(icon_names)*2);
    for j=1:numel(icon_names)
        try
            % run from desktop
            cdata = imread(fullfile(parentdir,'tracking','utilities','icons', icon_names{j}));
        catch
            % run from app
            cdata = imread(fullfile('tracking','utilities','icons', icon_names{j}));
        end
        cdata = double(cdata)./(2^16-1);
        r = cdata(:,:,1); g = cdata(:,:,2); b = cdata(:,:,3);
        inds = find((r+g+b)==0);
        r(inds) = figclr(1);
        g(inds) = figclr(2);
        b(inds) = figclr(3);
        icon_im = cdata; icon_im_active = cdata;
        icon_im(:,:,1) = r; icon_im(:,:,2) = g; icon_im(:,:,3) = b;
        r(inds) = figclr(1)-.2;
        g(inds) = figclr(2)-.2;
        b(inds) = figclr(3)-.2;
        icon_im_active(:,:,1) = r; icon_im_active(:,:,2) = g; icon_im_active(:,:,3) = b;    
        iconImgs{j} = icon_im;
        iconImgs{j+numel(icon_names)} = icon_im_active;
    end   
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Open files functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function openVideo(~,~) 
    [video_file, path] = uigetfile({'*.seq;*.wmv;*.mov;*.mp4;*.avi;*.fmf;*.ufmf'},'Select video file',files.video_dir);
    if ~video_file
        return
    end
    openVideoFile(path,video_file);
end

function openVideoFile(path,video_file)
    % load video
    try 
        cache_size = 1;
        vinfo_ = video_open(fullfile(path,video_file),cache_size);
        img = video_read_frame(vinfo_,0);
    catch
        customDialog('warn','Could not load video file',12*fig.fs)
        return; 
    end
    % first check if track or label changes need to be saved
    value = checkSaveSwaps;
    if value == 0, return; end
    value = checkSaveLabel;
    if value == 0, return; end    
    % set new video
    if ~isempty(quest), quest_old = quest; end
    resetVars;
    initVars;
    if exist('quest_old','var'), quest = quest_old; end
    vinfo = vinfo_;
    files.video_dir = path;
    % update video path visualization
    filename = fullfile(path,video_file);
    set(handles.videopath_h,'string',filename,'visible','on');     
    extent = get(handles.videopath_h,'extent');
    while extent(3) > fig.sub_width
        [~,filename] = strtok(filename,filesep); 
        set(handles.videopath_h,'String',['... ' filename]);
        extent = get(handles.videopath_h,'extent');
    end
    figure(handles.fig_h)
    subplot(handles.sub_h)
    hold off
    handles.img_h = imshow(img); colormap gray;
    zoom reset
    handles.plot_h = [];
    set(handles.sub_h,'XTick',[],'YTick',[]);
    total_frames = vinfo.n_frames;
    state.framerate = round(vinfo.fps); 
    set(handles.framerate_h,'string',num2str(state.framerate));
    set(handles.video_nfr_h,'string',num2str(total_frames))
    set(handles.slider_h,'Min',1,'Max',total_frames,'value',1,'sliderstep',[1/total_frames .1]); 
    % enable video viewing components
    for j=1:numel(handles.video_h)
        set(handles.video_h(j),'enable','on')
    end
    % enable video dependent compoenents
    set(handles.trk_h,'enable','on')
    set(handles.gtm_h,'enable','on')
    set(handles.predm_h,'enable','on')
    % plot first frame   
    updateDisplay(state.curr_frame)
    
    z = zoom; p = pan;
    set(z,'ActionPreCallback',@getZoom);
    set(z,'ActionPostCallback',@setZoom);
    set(p,'ActionPreCallback',@getZoom);
    set(p,'ActionPostCallback',{@setZoom,1});

    % load trk file
    [~,rawname] = fileparts(video_file);
    trkfilepath = fullfile(path,rawname,[rawname '-track.mat']);
    if exist(trkfilepath,'file')
       [trk_path,trk_file,ext] = fileparts(trkfilepath);
       openTrkFile(trk_path,[trk_file ext]) 
    end    
    
    % load annotation file
    annofilepath = fullfile(path, rawname, [rawname '-actions.mat']);
    if exist(annofilepath,'file')
        [anno_path,anno_file,ext] = fileparts(annofilepath);
        loadLabelFile(anno_path,[anno_file ext],'gt')
    end
end

function openTrk(~,~) 
    % get track file
    [trk_file, path] = uigetfile('*track.mat','Select track file',files.video_dir);
    if ~trk_file
        return
    end
    openTrkFile(path,trk_file);
end

function openTrkFile(path,trk_file)
    % load trk file    
    try
        D = load(fullfile(path,trk_file)); trk_ = D.trk;
    catch
        customDialog('warn','Could not load trk file',12*fig.fs);
        return
    end
    % first check if track or label changes need to be saved
    value = checkSaveSwaps;
    if value == 0, return; end
    value = checkSaveLabel;
    if value == 0, return; end    
    % reset interface
    if ~isempty(quest), quest_old = quest; end
    resetVars;
    initVars;
    if exist('quest_old','var'), quest = quest_old; end
    state.framerate = round(vinfo.fps); 
    set(handles.framerate_h,'string',num2str(state.framerate));
    % set new track
    n_flies = size(trk_.data,1);
    n_frames = size(trk_.data,2);
    trk = trk_;
    trk.obj_list = zeros(n_flies,n_frames);
    % compute median length of flies
    major_ax = trk.data(:,:,4);
    state.fly_length = nanmedian(major_ax(:));
    % enable track viewing components
    for j=1:numel(handles.track_h)
        set(handles.track_h(j),'enable','on')
    end    
    % check whether enough legs to show them   
    if size(trk.data,3)>17 
        legs = trk.data(1,:,17+(1:2:11));
        bool.show_legs = sum(~isnan(legs(:)))/n_frames > 3; % at least 3 legs on average        
        enabled = 'on';
        if sum(~isnan(legs(:)))==0
            enabled = 'off';
        end
    else
        bool.show_legs = 0;
        enabled = 'off';
    end
    set(handles.show_separate_h(4),'value',bool.show_legs)
    set(handles.show_separate_h(4),'enable',enabled)
    % check whether enough wings to show them
    wings = trk.data(1,:,[10 12]);
    bool.show_wings = sum(~isnan(wings(:)))/n_frames > 1; % at least 1 wing on average
    enabled = 'on';
    if sum(~isnan(wings(:)))==0
        enabled = 'off';
    end
    set(handles.show_separate_h(3),'value',bool.show_wings)
    set(handles.show_separate_h(3),'enable',enabled)
    for j=1:n_flies
        trk.obj_list(j,:) = j;
    end    
    files.trk = trk_file;
    files.path = path;
    set(handles.save_swaps_h,'enable','off');
    set(handles.gtm_h,'enable','on')
    set(handles.predm_h,'enable','on')
    set(handles.trkxls_h,'enable','on');
    % determine handle visibilities
    if isfield(trk,'flies_in_chamber')
        n_chambers = numel(trk.flies_in_chamber);
        for c=1:2
            set(handles.chamber_h(c),'visible','on');
        end
    else
        n_chambers = 1;
        for c=1:2
            set(handles.chamber_h(c),'visible','off');
        end
    end    
    majorax = trk.data(:,:,4);
    radius = nanmean(majorax(:))*10;
    if radius*2 > vinfo.sx && radius*2 > vinfo.sy        
        set(handles.auto_zoom_h,'visible','off');
    else
        set(handles.auto_zoom_h,'visible','on');
    end
    % set colors
    state.curr_chamber = 1;
    state.curr_flies = 1:n_flies;    
    fig.clrs = zeros(n_flies,3);
    tmp = mycolormap(n_flies);
    tmp = tmp*.8+.2;
    if n_flies <= 3
        tmp = [.3 .5 1; 1 .3 .3; .3 .8 .6];
        tmp = tmp(1:n_flies,:);
    end        
    if isfield(trk,'flies_in_chamber') && numel(trk.flies_in_chamber{1}) > 1 ...
            && numel(trk.flies_in_chamber{1}) == n_flies/n_chambers
        for c=1:n_chambers
            flies = trk.flies_in_chamber{c};
            fig.clrs(flies,:) = tmp(c:n_chambers:end,:);
        end
    else
        fig.clrs = tmp(1:n_flies,:);
    end
    % set swaps
    swap.swaps = repmat(1:n_flies,vinfo.n_frames,1);
    if n_chambers > 1   
        % make sure current chamber isn't empty
        for i=1:n_chambers
            if numel(trk.flies_in_chamber{i}) > 0
                state.curr_chamber = i;
                break;
            end
        end
        updateChamber(n_chambers+1)
    end
    % set potential switches
    if ~isfield(trk,'flags')
        flags = zeros(0,5);
    else
        flags = trk.flags(:,1:5);
    end
    % pad the intervals
    n_frames = size(trk.data,2);
    flags(:,3) = max(1,flags(:,3)-2);
    flags(:,4) = min(n_frames,flags(:,4)+2);
    flags = joinSwaps(flags);
    swap.all_switches = flags(:,[3:4 1:2 5]);            
    updateSwaps(0)    
    % load feature file
    try
        featfile = [trk_file(1:end-10) '-feat.mat'];
        if exist(fullfile(path,featfile),'file')
            D = load(fullfile(path,featfile)); feat = D.feat;
            set(handles.featl_h,'enable','on');
            set(handles.feat_val_h,'enable','on');
            set(handles.help_anno_h,'enable','on');
            featstr = feat.names{1};
            for j=2:numel(feat.names)
                featstr = [featstr '|' feat.names{j}];
            end
            set(handles.featl_h,'string',featstr)
        end
        files.feat = featfile;
    catch
        customDialog('warn','Could not load feat file',12*fig.fs);
    end   
    % load segmentation
    try
        segfile = [trk_file(1:end-10) '-seg.mat'];
        if exist(fullfile(path,segfile),'file')
            h = customDialog('wait','Loading segmentation...',12*fig.fs);
            D = load(fullfile(path,segfile)); 
            delete(h)
            seg = D.seg;
            set(handles.show_seg_h,'visible','on');
            files.seg = segfile;
        else
            set(handles.show_seg_h,'visible','off');
        end
    catch
        customDialog('warn','Could not load seg file',12*fig.fs);
    end   
    % try loading unsaved swaps
    swapname = ['tmp_' files.trk(1:end-4) '_swap.mat'];
    swapfile = fullfile(files.path,swapname);
    files.swap = swapname;
    if exist(swapfile,'file')
        D = load(swapfile); tmp_swaps = D.swaps;        
        indic = (tmp_swaps-swap.swaps)~= 0;
        frames = find(sum(indic,2));
        for s=1:numel(frames)
            flies = find(indic(frames(s),:));
            permute = 1:n_flies;
            processed = ones(1,n_flies);
            processed(flies) = 0;
            fly = flies(1);
            other_fly = tmp_swaps(frames(s),fly);
            while sum(processed) < numel(processed)                                
                swapId(frames(s),[fly other_fly],0);
                tmp = permute(fly);
                permute(fly) = permute(other_fly); 
                permute(other_fly) = tmp;
                processed(fly) = 1;                
                if tmp_swaps(frames(s),other_fly) == permute(other_fly)
                    processed(other_fly) = 1;
                    fly = find(~processed, 1);
                    other_fly = tmp_swaps(frames(s),fly);
                else 
                    fly = other_fly;
                    other_fly = tmp_swaps(frames(s),other_fly);
                end
            end            
        end
        swap.swaps = tmp_swaps;
        indic = (swap.swaps - repmat(1:n_flies,vinfo.n_frames,1))~=0;
        if sum(indic(:)) > 0
            set(handles.save_swaps_h,'enable','on');
        else
            set(handles.save_swaps_h,'enable','off');
        end
    end         
    % set pixel size and determine visible component based on it
    updateScreenpixSize;
    if state.linewidth < .9
        bool.show_ellipse = 0;
        bool.show_wings = 0;
        bool.show_legs = 0;
        set(handles.show_separate_h(1),'value',0);
        set(handles.show_separate_h(3),'value',0);
        set(handles.show_separate_h(4),'value',0);
    end
    updateDisplay(state.curr_frame)
end

function loadLabel(gt_pred)
    [label_file, path] = uigetfile({'*.mat'},'Select track file',files.video_dir);
    if ~label_file
        return
    end
    % load label file
    loadLabelFile(path,label_file,gt_pred);
end

function loadLabelFile(path,label_file,gt_pred)
    try    
        D = load(fullfile(path,label_file));
        behaviors = D.behs;
        if ~isempty(actions.beh_labels)
            behaviors = [actions.beh_labels setdiff(behaviors,actions.beh_labels)];
        end
        n_flies = size(D.bouts,1);
        n_behs = numel(behaviors);
        bouts = cell(n_flies,n_behs);
        idxmap = zeros(n_flies,n_behs,vinfo.n_frames);
        for f=1:n_flies
            for b=1:n_behs
                beh_idx = find(strcmp(D.behs,behaviors{b}));
                if beh_idx > 0
                    aaa=D.bouts{f,beh_idx};
                    if (size(aaa,2)~=3)
                        bouts{f,b} = horzcat(aaa,zeros(size(aaa,1),1));
                    else
                        bouts{f,b} =aaa;
                    end
                    for idx = 1:size(bouts{f,b},1)
                        idxmap(f,b,bouts{f,b}(idx,1):bouts{f,b}(idx,2)) = idx;
                    end
                end
            end
        end
        savefile = fullfile(path,[label_file(1:end-12) '-actions.mat']);
    catch
        customDialog('warn','File is of unknown format',12*fig.fs);
        return
    end
    actions.beh_labels = behaviors;
    actions.beh_colors = jet(numel(actions.beh_labels));    
    
    % Set behavior list
    beh_string = actions.beh_labels{1};
    for b=2:numel(actions.beh_labels)
        beh_string = [beh_string '|' actions.beh_labels{b}];
    end
    set(handles.action_h,'string',beh_string);
    
    % Set behavior type list
    have_gt = ~isempty(actions.gt) || strcmp(gt_pred,'gt');
    have_pred = ~isempty(actions.pred) || strcmp(gt_pred,'pred');
    behl_string = '';
    if have_gt && have_pred
        behl_string = 'ground truth|prediction|false negatives|false positives';
    elseif have_gt
        behl_string = 'ground truth';
    elseif have_pred
        behl_string = 'prediction';
    end
    set(handles.bout_type_h,'string',behl_string);
    if strcmp(gt_pred,'gt')
        files.labelfile = savefile;
        files.gt = label_file;
        actions.gt.bouts = bouts;
        actions.gt.idxmap = idxmap;
        actions.gt.idxmap_orig = idxmap;
        set(handles.gtl_h,'enable','on')    
        if ~isempty(actions.pred) && size(actions.gt.bouts,2) > size(actions.pred.bouts,2)
            pred.bouts = cell(size(actions.gt.bouts));
            pred.idxmap = zeros(size(actions.gt.idxmap));
            for ii=1:size(actions.pred.bouts,1)
                for jj=1:size(actions.pred.bouts,2)
                    pred.bouts{ii,jj} = actions.pred.bouts{ii,jj};
                end
            end
            actions.pred.bouts = pred.bouts;
            pred.idxmap(:,1:size(actions.pred.bouts,2),:) = actions.pred.idxmap;
            actions.pred.idxmap = pred.idxmap;
        end
        % try loading unsaved behavior annotations
        [~,filename] = fileparts(label_file);
        tmpname = ['tmp_' filename '_edits.mat'];
        tmpfile = fullfile(path,tmpname);
        files.tmplabelfile = tmpfile;
        if exist(tmpfile,'file')
            D = load(tmpfile); actions = D.actions;
            set(handles.save_anno_h,'enable','on');
        end           
        state.curr_beh_type = 1;
        for j=1:numel(handles.cert_h)
            set(handles.cert_h(j),'enable','on')
        end
        set(handles.bout_type_h,'value',1);
        set(handles.gtxls_h,'enable','on');
    else
        files.pred = label_file;
        actions.pred.bouts = bouts;
        actions.pred.idxmap = idxmap; 
        set(handles.predl_h,'enable','on')    
        if ~isempty(actions.gt) && size(actions.pred.bouts,2) > size(actions.gt.bouts,2)
            gt.bouts = cell(size(actions.pred.bouts));
            gt.idxmap = zeros(size(actions.pred.idxmap));
            for ii=1:size(actions.gt.bouts,1)
                for jj=1:size(actions.gt.bouts,2)
                    gt.bouts{ii,jj} = actions.gt.bouts{ii,jj};
                    gt.idxmap(ii,jj,:) = actions.gt.idxmap(ii,jj,:);
                end
            end
            actions.gt.bouts = gt.bouts;
            actions.gt.idxmap = gt.idxmap;
            actions.gt.idxmap_orig = gt.idxmap;
        end        
        state.curr_beh_type = 2;
        for j=1:numel(handles.cert_h)
            set(handles.cert_h(j),'enable','off')
        end
        for j=1:numel(handles.bout_manip_h)
            set(handles.bout_manip_h(j),'enable','off')
        end
        curr_beh_type = 2;
        if ~have_gt, curr_beh_type = 1; end
        set(handles.bout_type_h,'value',curr_beh_type);
        set(handles.predxls_h,'enable','on');
    end
    for j=1:numel(handles.bout_nav_h)
        set(handles.bout_nav_h(j),'enable','on')
    end
    
    % Find false negatives and positives
    if have_gt && have_pred
        computeLabelDiff()
    end
    
    % Set current bouts 
    setBouts();    
    
    if isempty(state.active_bout)
        state.active_bout = zeros(1,n_flies);
    end
    set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    updateDisplay(state.curr_frame);
end

function openGTlabel(~,~) 
    % first check if there are unsaved changes
    value = checkSaveLabel;
    if value == 0, return; end
    loadLabel('gt');
end

function openPREDlabel(~,~) 
    loadLabel('pred');
end

function newGTlabel(~,~) 
    %first check if there are unsaved changes
    value = checkSaveLabel;
    if value == 0, return; end
    
    state.active_bout = zeros(size(state.active_bout));
    
    if ~isempty(trk)
        label_file = [files.trk(1:end-10) '-actions.mat'];
        label_full_file = fullfile(files.path,label_file);
        n_flies = size(trk.data,1);
    else        
        %customDialog('warn','No tracks loaded, annotation will refer to video globally.', 12*fig.fs);     
        answer = customDialog('question','Flies are untracked. Create global video annotation?',12*fig.fs,{'Yes','No'},'Yes');
        if strcmp(answer,'No'), return; end
        [folder,video,~] = fileparts(vinfo.filename);
        label_full_file = fullfile(folder,[video '-actions.mat']);        
        n_flies = 1;        
    end    
    [label_file,label_path] = uiputfile('*.mat','Select path for the new annotation file',label_full_file);
    if ~label_file, return; end
    
    [~,filename] = fileparts(label_file);
    tmpname = ['tmp_' filename '_edits.mat'];
    tmpfile = fullfile(label_path,tmpname);
    
    % set default behaviors
    [beh_file, beh_path] = uigetfile({'*.txt'},'Select action list file',files.action_list_path);    
    if ~beh_file, return; end
    files.action_list_path = fullfile(beh_path,beh_file);

    behaviors = loadActionList();   
    if isempty(behaviors)
        str = [files.action_list_path ' is empty. Please insert actions to file (line separated).'];
        warnDialog(str,12*fig.fs);
        return
    end
    if ~isempty(actions.beh_labels)
        behaviors = [actions.beh_labels(:); setdiff(behaviors(:),actions.beh_labels(:))];
    end
    
    files.tmplabelfile = tmpfile;
    files.labelfile = fullfile(label_path,label_file);
    files.gt = label_file;
    
    actions.beh_labels = behaviors;
    actions.beh_colors = jet(numel(actions.beh_labels));  
    n_behs = numel(behaviors);    
    
    % load empty bouts
    bouts = cell(n_flies,n_behs);
    idxmap = zeros(n_flies,n_behs,vinfo.n_frames);
    actions.gt.bouts = bouts;
    actions.gt.idxmap = idxmap;
    actions.gt.idxmap_orig = idxmap;
    actions.curr_bouts = zeros(0,2);
    actions.curr_frames = zeros(1,vinfo.n_frames);
    
    % Set behavior list
    beh_string = actions.beh_labels{1};
    for b=2:numel(actions.beh_labels)
        beh_string = [beh_string '|' actions.beh_labels{b}];
    end
    set(handles.action_h,'string',beh_string);
    
    % Set behavior type list
    have_gt = ~isempty(actions.gt);
    have_pred = ~isempty(actions.pred);
    behl_string = '';
    if have_gt && have_pred
        behl_string = 'ground truth|prediction|false negatives|false positives';
    elseif have_gt
        behl_string = 'ground truth';
    elseif have_pred
        behl_string = 'prediction';
    end
    set(handles.bout_type_h,'string',behl_string);
    
    % update display
    for j=1:numel(handles.bout_nav_h)
        set(handles.bout_nav_h(j),'enable','on')
    end
    for j=1:numel(handles.cert_h)
        set(handles.cert_h(j),'enable','on')
    end
    set(handles.gtl_h,'enable','on') 
    set(handles.gtxls_h,'enable','on');
    
    if isempty(state.active_bout)
        state.active_bout = zeros(1,n_flies);
    end
    set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    setBouts();
    updateDisplay(state.curr_frame);
end

function actions = loadActionList()
    actions = cell(0,1);
    if ~exist(files.action_list_path,'file'), return; end
    fid = fopen(files.action_list_path);
    tmp = textscan(fid,'%s','delimiter','\n');
    if numel(tmp) > 0, lines = tmp{1}; end
    valid = ~cellfun(@isempty,lines);
    actions = lines(valid);
end

function computeLabelDiff()
    n_behs  = size(actions.gt.bouts,2);
    n_flies = size(actions.gt.bouts,1);
    actions.fn = cell(n_flies,n_behs);
    actions.fp = cell(n_flies,n_behs);
    for f=1:n_flies
        for b=1:numel(actions.beh_labels)
            % loop through gt bouts and see if there is an overlapping pred bout
            if numel(actions.gt.bouts{f,b}) > 0
                for j=1:size(actions.gt.bouts{f,b},1)
                    gt_frames = actions.gt.bouts{f,b}(j,1):actions.gt.bouts{f,b}(j,2);
                    pred_frames = find(actions.pred.idxmap(f,b,gt_frames)>0);
                    overlap = numel(pred_frames)/numel(gt_frames);
                    if overlap < actions.overlapTHRESH
                        actions.fn{f,b}(end+1) = j;
                    end
                end
            end
            % loop through pred bouts and see if there is an overlapping gt bout
            if numel(actions.pred.bouts{f,b})
                for j=1:size(actions.pred.bouts{f,b},1)
                    pred_frames = actions.pred.bouts{f,b}(j,1):actions.pred.bouts{f,b}(j,2);
                    gt_frames = find(actions.gt.idxmap(f,b,pred_frames)>0);
                    overlap = numel(gt_frames)/numel(pred_frames);
                    if overlap < actions.overlapTHRESH
                        actions.fp{f,b}(end+1) = j;
                    end
                end
            end
        end
    end
end

function setBouts()
    if state.curr_beh_type == 1 % ground truth
        actions.curr_bouts = actions.gt.bouts{state.active_fly,state.curr_beh};
    elseif state.curr_beh_type == 2 % prediction 
        actions.curr_bouts = actions.pred.bouts{state.active_fly,state.curr_beh};
    elseif state.curr_beh_type == 3 % false negatives
        actions.curr_bouts = actions.gt.bouts{state.active_fly,state.curr_beh}(actions.fn{state.active_fly,state.curr_beh},:);
    elseif state.curr_beh_type == 4 % false positives
        actions.curr_bouts = actions.pred.bouts{state.active_fly,state.curr_beh}(actions.fp{state.active_fly,state.curr_beh},:);
    end
    if isempty(actions.curr_bouts)
        actions.curr_bouts = zeros(0,2);
    end
    actions.curr_frames = zeros(1,vinfo.n_frames);
    for b=1:size(actions.curr_bouts,1)
        frames = actions.curr_bouts(b,1):actions.curr_bouts(b,2);
        actions.curr_frames(frames) = 1;
    end    
    % Set number of bouts
    set(handles.nbouts_h,'string',num2str(size(actions.curr_bouts,1)));
    % Set current bout id
    state.curr_bout = 0;
    state.active_bout(:) = 0;
    set(handles.bout_id_h,'string','0')
end

function new_flags = joinSwaps(flags)
    % count how many flags occur at a given frame
    flag_count = zeros(1,max(flags(:,4)));
    for i=1:size(flags,1)
        flag_count(flags(i,3):flags(i,4)) = ...
            flag_count(flags(i,3):flags(i,4)) + 1;
    end

    % loop through all frames that have more than one flag
    multiswaps = find(flag_count>1);
    do_group = zeros(size(flags,1));
    for i=1:numel(multiswaps)
        frame = multiswaps(i);
        % find all flags that contain this frame
        inds = find(flags(:,3) <= frame & flags(:,4) >= frame);   
        % group flags only if they have flies in common
        for i1=1:numel(inds)
            for i2=i1+1:numel(inds)
                if sum(ismember(flags(inds(i1),1:2),flags(inds(i2),1:2))) > 0
                    do_group(inds(i1),inds(i2)) = 1;
                end
            end
        end
    end
    if sum(do_group(:)) == 0
        new_flags = flags; 
        return;
    end

    % gather flags into groups    
    groups = cell(1,size(flags,1));
    group_map = zeros(1,size(flags,1));
    count = 0;
    for i=1:size(flags,1)
        buddies = find(do_group(i,:));      
        group = [i buddies];
        bud_groups = group_map(group); 
        bud_groups = bud_groups(bud_groups>0);
        if numel(bud_groups) > 0
            g = bud_groups(1);
            groups{g} = union(groups{g},group);
            group_map(group) = g;
        else
            count = count+1;
            groups{count} = group;
            group_map(group) = count;
        end
    end
    groups = groups(1:count);

    % find which fly to list first for each group
    % (pick the one with the most ambiguity)
    lead_flies = zeros(1,numel(groups));
    for g=1:numel(groups)
        flypairs = flags(groups{g},1:2); 
        flies = unique(flypairs(:));
        ambigs = flags(groups{g},5);
        fly_ambigs = zeros(numel(flies),1);
        for f=1:numel(flies)
            from = find(flypairs(:,1)==flies(f));
            to = find(flypairs(:,2)==flies(f));
            inds = union(from,to);
            fly_ambigs(f) = min(ambigs(inds));
        end
        [~,minidx] = min(fly_ambigs);        
        lead_flies(g) = flies(minidx);
    end
    
    % recreate flags with the groups
    new_flags = zeros(numel(groups),5);
    for i=1:numel(groups)
        if numel(groups{i}) == 1
            new_flags(i,:) = flags(groups{i},:);
        else            
            fly = lead_flies(i);
            fr_start = min(flags(groups{i},3));
            fr_end   = max(flags(groups{i},4));
            ambig    = min(flags(groups{i},5));
            new_flags(i,:) = [fly 0 fr_start fr_end ambig];
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Display functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateDisplay(frame)
    if bool.updating 
        return
    end
    bool.updating = 1;
    % update image
    vinfo_ = vinfo;
    if bool.show_seg
        if frame <= numel(seg)
            img = renderSegmentation(frame);            
        else
            img = ones(vinfo.sx,vinfo.sy)*.7;
        end
    else   
        if bool.show_img
            try
                img = video_read_frame(vinfo_,frame-1);
                vinfo = vinfo_;
            catch
                disp(['Warning: could not read frame ' num2str(frame)])
                return
            end
        else
            img = ones(vinfo.sx,vinfo.sy)*.7;
        end
    end   
    figure(handles.fig_h)
    subplot(handles.sub_h)
    set(handles.img_h,'cdata',img);

    for ii=1:numel(handles.plot_h)
        delete(handles.plot_h(ii));
    end
    handles.plot_h = zeros(1,100);
    h_count = 0;

    set(handles.video_frame_h,'string',num2str(frame))
    set(handles.slider_h,'value',frame)

    lw = state.linewidth;
    
    % update track
    if ~isempty(trk) && frame <= size(trk.data,2)
        hold on
        if ~bool.show_seg && bool.show_trk   
            wingidx = find(strcmp(trk.names,'wing l x'));
            % check whether transparency is well supported
            try
                tmp_h = plot(1,1,'.','color',[1 1 1 .1]);
                delete(tmp_h);
                alphaOK = 1;
            catch
                alphaOK = 0;
            end
            for oo=1:numel(state.curr_flies)
                o = state.curr_flies(oo);
                pos   = trk.data(o,frame,1:2);
                ori   = trk.data(o,frame,3);
                axes  = trk.data(o,frame,4:5);
                lwing = trk.data(o,frame,wingidx+(0:1));
                rwing = trk.data(o,frame,wingidx+(2:3));     
                % plot trail
                if bool.show_trail
                    first_fr = max(1,frame-100);
                    x_s = trk.data(o,first_fr:(frame),1);
                    y_s = trk.data(o,first_fr:(frame),2);
                    if alphaOK                    
                        handles.plot_h(h_count+1) = plot(x_s,y_s,'-','color',[fig.clrs(o,:) .3],'linewidth',1.2);                                    
                    else
                        handles.plot_h(h_count+1) = plot(x_s,y_s,'-','color',fig.clrs(o,:),'linewidth',1.2);
                    end
                    h_count = h_count+1;
                end
                % plot ellipse
                if bool.show_ellipse
                    if ~bool.show_img
                        h = draworiellipse(pos(1),pos(2),-ori,axes(1)/2,axes(2)/2,'color',fig.clrs(o,:),'linewidth',lw*1.5,'alpha',1);
                    elseif alphaOK
                        h = draworiellipse(pos(1),pos(2),-ori,axes(1)/2,axes(2)/2,'color',fig.clrs(o,:),'linewidth',lw*1.5);
                    else
                        h = draworiellipse(pos(1),pos(2),-ori,axes(1)/2,axes(2)/2,'color',fig.clrs(o,:),'linewidth',lw*1.5,'alpha',0);
                    end
                    handles.plot_h(h_count+(1:numel(h))) = h;
                    h_count = h_count+numel(h);
                end
                % plot wings                
                if bool.show_wings
                    if alphaOK 
                        handles.plot_h(h_count+1) = plot([pos(1) lwing(1)], [pos(2) lwing(2)],'color',[0 1 0 .7],'linewidth',lw*1.5);
                        handles.plot_h(h_count+2) = plot([pos(1) rwing(1)], [pos(2) rwing(2)],'color',[0 1 1 .7],'linewidth',lw*1.5);                
                    else
                        handles.plot_h(h_count+1) = plot([pos(1) lwing(1)], [pos(2) lwing(2)],'color',[0 1 0],'linewidth',lw*1.2);
                        handles.plot_h(h_count+2) = plot([pos(1) rwing(1)], [pos(2) rwing(2)],'color',[0 1 1],'linewidth',lw*1.2);                    
                    end
                    h_count = h_count+2;   
                end
                % plot legs
                if bool.show_legs % data contains leg coordinates
                    for l=1:6
                        lpos = trk.data(o,frame,17+(l-1)*2+(1:2));
                        if isnan(lpos(1)), break; end
                        lang = trk.data(o,frame,29+l);
                        if lang<0, col = [0 1 0]; else col = [0 1 1]; end
                        handles.plot_h(h_count+1) = ...
                          plot(lpos(1),lpos(2),'o','markersize',lw*2.5,...
                             'markerFaceColor',col,'markerEdgeColor','none');
                        h_count = h_count+1;
                    end
                end
                % plot dot on top of trail
                if ~bool.show_ellipse %&& bool.show_trail
                    handles.plot_h(h_count+1) = plot(pos(1),pos(2),'o',...
                        'markerFaceColor',fig.clrs(o,:),'markerEdgeColor','none','markersize',lw*6);
                    h_count = h_count+1;
                end
            end
        end
        active_pos = trk.data(state.active_fly,frame,1:2);  
        if lw >=.9 
            handles.plot_h(h_count+1) = plot(active_pos(1),active_pos(2),'*w','markersize',lw*4.5,'linewidth',1);
        else
            handles.plot_h(h_count+1) = plot(active_pos(1),active_pos(2),'ow','markersize',lw*20,'linewidth',1);
        end
        h_count = h_count+1;
        
        % draw chamber
        if ~isempty(state.roi) && ~all(state.roi == axis)
            border = state.roi;
            handles.plot_h(h_count+1) = plot(border([1 1 2 2 1]), border([3 4 4 3 3]),'-','color',.3*[1 1 1],'linewidth',3);
            handles.plot_h(h_count+2) = plot(border([1 1 2 2 1]), border([3 4 4 3 3]),'-w','linewidth',1);        
            h_count = h_count+2;
        end
    end
    handles.plot_h = handles.plot_h(1:h_count);
    
    n_show = 60; % show 60 frames on either side of current frame
    framerange = max(frame-n_show,1):min(frame+n_show,vinfo.n_frames);
    % update gt
    setBoutModify
    if ~isempty(actions.gt)
        subplot(handles.gt_h)
        hold off
        plot([frame frame],[-100 100],'-k')
        hold on
        if ~isempty(actions.gt)
            inds = find(actions.gt.idxmap(state.active_fly,state.curr_beh,framerange));
            noneinds = setdiff(1:numel(framerange),inds);
            % plot non-actions
            plot(noneinds+framerange(1)-1, zeros(size(noneinds)), 'o',...
                'markerFaceColor', [.5 .5 .5],'markerEdgeColor','none','markersize',3)
            % plot actions
            plot(inds+framerange(1)-1, zeros(size(inds)), 'o',...
                'markerFaceColor', actions.beh_colors(state.curr_beh,:),...
                'markerEdgeColor','none','markersize',6)
            % plot handles on current action
            if state.active_bout(state.active_fly) > 0 && ~isempty(actions.curr_bouts) && state.curr_beh_type == 1
                plot(actions.curr_bouts(state.active_bout(state.active_fly),1:2),zeros(1,2),'o',...
                    'markerFaceColor',actions.beh_colors(state.curr_beh,:),'markerEdgeColor','k','markersize',10)
            end
            % plot actions in creation
            if ~isempty(state.new_bout)
                frame_start = min(state.new_bout.start,state.curr_frame);
                frame_end = max(state.new_bout.start,state.curr_frame);
                inds = frame_start:frame_end;
                plot(inds, zeros(size(inds)), 'o','markerFaceColor','g',...
                    'markerEdgeColor','none','markersize',6)
            end        
        end
        xlim([(frame-n_show) (frame+n_show)]);
        set(handles.gt_h,'XTick',[]);
        set(handles.gt_h,'YTick',[]);        
    end
    
    % update pred
    if ~isempty(actions.pred)
        subplot(handles.pred_h)
        hold off
        plot([frame frame],[-100 100],'-k')
        hold on
        if ~isempty(actions.pred)
            inds = find(actions.pred.idxmap(state.active_fly,state.curr_beh,framerange));
            noneinds = setdiff(1:numel(framerange),inds);
            % plot non-actions
            plot(noneinds+framerange(1)-1, zeros(size(noneinds)), 'o',...
                'markerFaceColor', [.5 .5 .5],'markerEdgeColor','none','markersize',3)
            % plot actions
            plot(inds+framerange(1)-1, zeros(size(inds)), 'o',...
                'markerFaceColor', actions.beh_colors(state.curr_beh,:),...
                'markerEdgeColor','none','markersize',6)      
        end    
        xlim([(frame-n_show) (frame+n_show)]);
        set(handles.pred_h,'XTick',[]);
        set(handles.pred_h,'YTick',[]);
    end
    
    % update features
    if ~isempty(feat) && frame <= size(feat.data,2)
        framerange = max(frame-n_show,1):min(frame+n_show,size(feat.data,2));
        subplot(handles.feat_h)
        hold off
        plot([frame frame],[-100 100],'-k')
        hold on
        featvec = feat.data(:,:,state.curr_feat);
        if all(isnan(featvec))
            set(handles.feat_h,'XTick',[]);
            set(handles.feat_h,'YTick',[]);      
        else
            minfeat = nanmin(featvec(:));
            maxfeat = nanmax(featvec(:));
            plot([frame frame],[minfeat maxfeat],'-k')
            hold on
            plot(framerange,featvec(state.active_fly,framerange),'-',...
                'color',fig.clrs(state.active_fly,:),'linewidth',1.5);
            if strcmp(get(handles.feat_thresh_h,'Visible'),'on') && ~isempty(state.featvec_conditioned)
                feat_cond = state.featvec_conditioned(state.active_fly,framerange)==1;
                plot(framerange(feat_cond),featvec(state.active_fly,framerange(feat_cond)),...
                    'o','markersize',4,'markerEdgeColor','none','markerFaceColor',[0.2 0.6 0.2]);
            end
            hold off;
            ylim([minfeat maxfeat]);            
            if isfield(feat,'units')
                ylabel(feat.units{state.curr_feat},'fontsize',12*fig.fs);
            end
            range = maxfeat-minfeat;            
            ytick = unique([minfeat+range*.1 minfeat+range*.9]);
            ystr = cell(size(ytick));
            for i=1:numel(ytick)
                ystr{i} = sprintf('%0.1f',ytick(i));
            end
            set(handles.feat_h,'YTick',ytick); 
            set(handles.feat_h,'YTickLabel',ystr,'fontsize',10*fig.fs); 
            xlim([(frame-n_show) (frame+n_show)]);
            set(handles.feat_h,'XTick',[]);
            str = sprintf('%0.2f',featvec(state.active_fly,frame));
            set(handles.feat_val_h,'string',str,...
                'foregroundcolor',fig.clrs(state.active_fly,:)*.75);
        end
    end
    drawnow
    bool.updating = 0;
end

function h = draworiellipse(x,y,theta,a,b,varargin)
    % center (x,y), rotation theta, height a*2, base b*2
    % set default parameters
    color = [0 0 1];
    linewidth = 2;
    alpha     = .2;
    drawori   = 1;
    % see whether parameters were given
    idx = find(strcmp(varargin,'color'));
    if ~isempty(idx)
        color = varargin{idx+1};
    end
    idx = find(strcmp(varargin,'linewidth'));
    if ~isempty(idx)
        linewidth = varargin{idx+1};
    end
    idx = find(strcmp(varargin,'alpha'));
    if ~isempty(idx)
        alpha = varargin{idx+1};
    end
    idx = find(strcmp(varargin,'drawori'));
    if ~isempty(idx)
        drawori = varargin{idx+1};
    end
    % draw ellipse
    phi = 0:0.1:2*pi;
    X1 = a*cos(phi);
    Y1 = b*sin(phi);
    costheta = cos(theta);
    sintheta = sin(theta);
    X = costheta*X1 - sintheta*Y1 + x;
    Y = sintheta*X1 + costheta*Y1 + y;
    h = zeros(1,1+drawori*2);
    if alpha == 0
        h(1) = plot(X,Y,'-','color',color,'linewidth',linewidth);
    elseif alpha == 1
        h(1) = patch('Faces',1:numel(X),'Vertices',[X' Y'],'FaceColor',.2*[1 1 1], ...
               'EdgeColor',color,'linewidth',linewidth);        
    else
        h(1) = patch('Faces',1:numel(X),'Vertices',[X' Y'],'FaceColor',color, ...
               'FaceAlpha',alpha,'EdgeColor',color,'linewidth',linewidth);
    end
    % draw radii
    if drawori
        ori_vec = [cos(theta) sin(theta)]*a;
        h(2) = plot([x x+ori_vec(1)],[y y+ori_vec(2)],'color',color,...
            'linewidth',linewidth);         
        ori_vec = [-sin(theta) cos(theta)]*b;
        h(3) = plot([x x+ori_vec(1)],[y y+ori_vec(2)],'color',color,...
            'linewidth',linewidth);           
    end
end

function img = renderSegmentation(frame)
    im_r = zeros(vinfo.sx,vinfo.sy);
    im_g = zeros(vinfo.sx,vinfo.sy);
    im_b = zeros(vinfo.sx,vinfo.sy);
    im_count = zeros(vinfo.sx,vinfo.sy);
    n_objs = numel(seg{frame});
    for j=1:n_objs
        jj = trk.obj_list(j,frame);
        fly = seg{frame}{jj};
        try
            % render body
            im_r(fly.body) = fig.clrs(j,1);
            im_g(fly.body) = fig.clrs(j,2);
            im_b(fly.body) = fig.clrs(j,3);
            im_count(fly.body) = im_count(fly.body)+1;
            % render wings
            im_r(fly.wings) = fig.clrs(j,1)+.2;
            im_g(fly.wings) = fig.clrs(j,2)-.1;
            im_b(fly.wings) = fig.clrs(j,3)+.1;
            im_count(fly.wings) = im_count(fly.wings)+1;
            % render legs
            im_r(fly.legs) = fig.clrs(j,1)-.2;
            im_g(fly.legs) = fig.clrs(j,2)+.2;
            im_b(fly.legs) = fig.clrs(j,3)-.5;
            im_count(fly.legs) = im_count(fly.legs)+1;
        end
    end
    im_count(im_count==0) = 1;
    img = zeros(vinfo.sx,vinfo.sy,3);
    im_r = im_r./im_count; im_g = im_g./im_count; im_b = im_b./im_count;
    img(:,:,1) = im_r; img(:,:,2) = im_g; img(:,:,3) = im_b;
    img = max(0,img); img = min(1,img);
end

function setBoutModify()
    if state.curr_beh_type > 2,  return; end
    if ~isempty(state.new_bout), return; end    
    type = state.curr_beh_type;
    if type == 1 && isempty(actions.gt) && isempty(actions.pred), return; end
    
    if isempty(actions.gt)
        type = type + 1;
    end
    
    curr_bout = get_curr_bout;
    if curr_bout > 0                  
        % update active bout
        state.active_bout(state.active_fly) = curr_bout;
        state.curr_bout = curr_bout;
        set(handles.bout_id_h,'String',num2str(curr_bout))
        % set certainty 
        cert = actions.curr_bouts(curr_bout,3);
        setRadioCertaintyToValue(cert);        
        if type == 2, return; end
        
        % set ADD DEL MOVE COPY, and "certainty" enable
        for ii=1:numel(handles.bout_manip_h)
            set(handles.bout_manip_h(ii),'enable','on')
        end
        set(handles.bout_add_h,'enable','off')
        n_flies = numel(state.curr_flies);
        if isfield(trk,'flies_in_chamber')
            n_flies = numel(trk.flies_in_chamber{state.curr_chamber});
        end
        if n_flies ~= 2
            set(handles.bout_move_h,'enable','off');
            set(handles.bout_copy_h,'enable','off');
        end     
        % enable certainty
        for ii=1:numel(handles.cert_h)
            set(handles.cert_h(ii),'enable','on')
        end
    else
        setRadioCertaintyToValue(0);        
        if type == 2, return; end
        
        % set ADD DEL MOVE COPY, and "certainty" enable
        for ii=1:numel(handles.bout_manip_h)
            set(handles.bout_manip_h(ii),'enable','off')
        end
        set(handles.bout_add_h,'enable','on')     
        % disable certainty
        for ii=1:numel(handles.cert_h)
            set(handles.cert_h(ii),'enable','off')
            set(handles.cert_h(ii),'value',0)
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Mouse and key functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mousePressed(~,~) 
    if isempty(vinfo) && isempty(trk)
        return
    end
    sub_pos  = get(handles.sub_h,'CurrentPoint'); 
    gt_pos   = get(handles.gt_h,'CurrentPoint');
    pred_pos = get(handles.pred_h,'CurrentPoint');
    feat_pos = get(handles.feat_h,'CurrentPoint');    
    if gt_pos(1,3) * gt_pos(2,3) == -1
        h = handles.gt_h;
        pos = gt_pos(1,1:2);        
    elseif pred_pos(1,3) * pred_pos(2,3) == -1
        h = handles.pred_h;
        pos = pred_pos(1,1:2);
    elseif feat_pos(1,3) * feat_pos(2,3) == -1
        h = handles.feat_h;
        pos = feat_pos(1,1:2);
    elseif sub_pos(2,3) == -1%sub_pos(1,3) * sub_pos(2,3) == -1
        h = handles.sub_h;
        pos = sub_pos(1,1:2);        
    else
        return
    end
    subplot(h); ax = axis;
    if pos(1) < ax(1) || pos(1) > ax(2)
        return
    end
    if h==handles.sub_h 
        if size(trk.data,2) < state.curr_frame, return; end
        % check which fly was clicked, if any
        min_dist = inf;
        closest_obj = 0;
        for o=1:numel(state.curr_flies) 
            fly = state.curr_flies(o);
            sq_dist = (pos(1)-trk.data(fly,state.curr_frame,1))^2+(pos(2)-trk.data(fly,state.curr_frame,2))^2;
            if sq_dist < min_dist
                min_dist = sq_dist;
                closest_obj = fly;
            end
        end
        if sqrt(min_dist) <= trk.data(closest_obj,state.curr_frame,4)/2
            state.waitingformouse = 0;
            if state.active_fly ~= closest_obj
                state.active_fly = closest_obj;
                if ~isempty(actions.gt) || ~isempty(actions.pred)
                    setBouts()
                    set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
                end
                findChamber;
                if get(handles.help_anno_h,'value')==1
                    getFeatvecCond()
                end
                updateDisplay(state.curr_frame);
            end
        end        
    else
        if h==handles.gt_h && ~isempty(actions.curr_bouts) && state.active_bout(state.active_fly) > 0 && state.curr_beh_type == 1
            % check whether handles of active bout were clicked
            bout = actions.curr_bouts(state.active_bout(state.active_fly),:);
            if abs(pos(1)-bout(1)) < 1
                bool.moving_bout_boundaries = 1;
                return
            elseif abs(pos(1)-bout(2)) < 1
                bool.moving_bout_boundaries = 2;
                return
            end
        end
        
        % update frame position
        fr = min(vinfo.n_frames,max(1,round(pos(1))));
        state.curr_frame = fr;
        updateDisplay(state.curr_frame);
    end
end

function mouseReleased(~,~) 
    if bool.moving_bout_boundaries == 0
        return
    end
    gt_pos   = get(handles.gt_h,'CurrentPoint');    
    if gt_pos(1,3) * gt_pos(2,3) ~= -1
       bool.moving_bout_boundaries = 0;
       return 
    end
    pos = gt_pos(1,1:2);    
    fr = min(vinfo.n_frames,max(1,round(pos(1))));
    bout = actions.curr_bouts(state.active_bout(state.active_fly),:);
    bout(bool.moving_bout_boundaries) = fr;
    bout = [min(bout(1:2)) max(bout(1:2)) bout(3)];
    % remove active bout
    removeBout(state.active_bout(state.active_fly));
    % add new bout
    insertBout(state.active_fly,bout);
    finishBoutEdit  
    bool.moving_bout_boundaries = 0;
end

function keyPressed(~,event)
    switch event.Key
        case 'leftarrow'    %% go to previous frame            
            state.curr_frame = max(1,state.curr_frame-1);
            updateDisplay(state.curr_frame)
        case 'rightarrow'   %% go to next frame            
            state.curr_frame = min(vinfo.n_frames,state.curr_frame+1);
            updateDisplay(state.curr_frame)
        case 'uparrow'      %% go to next bout            
            if state.key_mode == 1
                idSwitchUp
            elseif state.key_mode == 2
                boutUp
            end
        case 'downarrow'    %% go to previous bout            
            if state.key_mode == 1
                idSwitchDown
            elseif state.key_mode == 2
                boutDown
            end
        case 'space'        %% play stop bout clips            
            if state.key_mode == 1
                playBout(handles.play_swap_h,[],'swap')
            elseif state.key_mode == 2
                playBout(handles.play_bout_h,[],'beh')
            else
                if bool.do_play
                    bool.do_play = 0;
                    set(handles.video_play_h,'string','play')
                    set(handles.video_play_h,'backgroundcolor',[.3 .7 .4])
                else
                    bool.do_play = 1;
                    set(handles.video_play_h,'string','pause')
                    set(handles.video_play_h,'backgroundcolor',[1 .5 .5])
                    play();
                end
            end            
        case '1' % set mode to video navigation
            state.key_mode = 0;
            set(handles.id_hot_h,'Visible','off');
            set(handles.beh_hot_h,'Visible','off');
        case '2' % set mode to identity swaps
            if ~isempty(swap) && numel(swap.switches) > 0
                state.key_mode = 1;    
                set(handles.id_hot_h,'Visible','on');
                set(handles.beh_hot_h,'Visible','off');
            end
        case '3' % set mode to behaviors
            if ~(isempty(actions.gt) && isempty(actions.pred))                
                state.key_mode = 2;
                set(handles.id_hot_h,'Visible','off');
                set(handles.beh_hot_h,'Visible','on');
            end
        case 'd' % delete bout
            if state.key_mode == 2
                currBout = get_curr_bout();
                if currBout > 0
                    deleteBout;
                end
            end
        case 'a' % add bout
            if state.key_mode == 2
                currBout = get_curr_bout();
                if currBout == 0
                    addBout(handles.bout_manip_h(1));
                end
            end
        case 's' % swap identities
            if state.key_mode == 1
                swapIds;
            end        
    end            
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Video navigation functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function playVid(hObj,~) 
    if strcmp(get(hObj,'string'),'play')
        bool.do_play = true;
        set(hObj,'string','pause')
        set(hObj,'backgroundcolor',[1 .5 .5])
        play();
    else
        bool.do_play = false;
        set(hObj,'string','play')
        set(hObj,'backgroundcolor',[.3 .7 .4])
    end
end

function play()
    set(handles.jump_button_h,'Visible','off');
    orig_time = clock; 
    orig_frame = state.curr_frame;
    while bool.do_play
        curr_time = clock;
        time_diff = etime(curr_time,orig_time);
        frame_diff = round(time_diff*state.framerate);
        state.curr_frame = orig_frame + frame_diff;
        if state.curr_frame > vinfo.n_frames || state.curr_frame < 1
            if state.curr_frame > vinfo.n_frames
                state.curr_frame = vinfo.n_frames;
            else
                state.curr_frame = 1;
            end
            bool.do_play = 0;            
            set(handles.video_play_h,'string','play')
            set(handles.video_play_h,'backgroundcolor',[.3 .7 .4])
        end  
        updateDisplay(state.curr_frame);
        state.prev_frame = state.curr_frame-1;
    end
end

function playBout(hObj,~,caller)
    if strcmp(caller,'beh')
        if state.active_bout(state.active_fly) < 1, return; end    
        bout = actions.curr_bouts(state.active_bout(state.active_fly),1):actions.curr_bouts(state.active_bout(state.active_fly),2);
    else
        if swap.id_switch < 1, return; end
        bout = swap.switches(swap.id_switch,1):swap.switches(swap.id_switch,2);        
    end
    pause_dur = abs(1/state.framerate);
    bool.do_play = 0;
    value = get(hObj,'string');
    if strcmp(value,'play clip')
        set(hObj,'string','stop')
        set(hObj,'backgroundcolor',[1 .5 .5])
        bool.stop_bout_play = 0;
        tic;
        for f = bout
            if bool.stop_bout_play
                break
            end
            state.curr_frame = f;
            updateDisplay(state.curr_frame);
            dt = toc;
            if dt < pause_dur
                pause(pause_dur-dt)
            end
            tic;
        end
        set(hObj,'string','play clip')
        set(hObj,'backgroundcolor',[.3 .7 .4])    
    else
        set(hObj,'string','play clip')
        set(hObj,'backgroundcolor',[.3 .7 .4])    
        bool.stop_bout_play = 1;
    end
    set(hObj,'enable','on')
end

function goBackToFrame(hObj,~) 
    aux_frame = state.curr_frame;
    state.curr_frame = state.prev_frame;
    state.prev_frame = aux_frame;
    set(hObj,'visible','off')
    updateDisplay(state.curr_frame)
end

function setFramerate(hObj,~)
    value = str2num(get(hObj,'string'));
    if isempty(value), return; end
    state.framerate = value;    
end

function goToFrame(hObj,~) 
    value = str2num(get(hObj,'string'));
    if isempty(value), return; end
    state.curr_frame = min(vinfo.n_frames,max(1,round(value)));
    if state.curr_frame ~= value
        set(hObj,'string',num2str(state.curr_frame));
    end
    updateDisplay(state.curr_frame)
end

function vidSlider(hObj,~) 
    state.prev_frame=str2double(get(handles.video_frame_h,'string'));
    if strcmp(get(handles.video_play_h,'string'),'pause')
        bool.do_play = false;
        set(handles.video_play_h,'string','play')
        set(handles.video_play_h,'backgroundcolor',[.3 .7 .4])
    end
    state.curr_frame = min(vinfo.n_frames,max(1,round(get(hObj,'value'))));
    updateDisplay(state.curr_frame)
    if (abs(state.curr_frame-state.prev_frame))>2
        set(handles.jump_button_h,'Visible','on');
    else
        set(handles.jump_button_h,'Visible','off');
    end
end

function zoomIn(~,~) 
    figure(handles.fig_h)
    subplot(handles.sub_h)
    tmp = get(zoom);
    if strcmp(tmp.Enable,'on') && strcmp(tmp.Direction,'in')
        zoom off
        % change in label to off
        set(handles.zoom_h(1),'cdata',fig.zoom_imgs{1}) 
    else
        set(zoom,'direction','in','enable','on')
        pan off
        % change in label to on
        set(handles.zoom_h(1),'cdata',fig.zoom_imgs{4}) 
        % change out label to off
        set(handles.zoom_h(2),'cdata',fig.zoom_imgs{2})
        % change pan label to off
        set(handles.zoom_h(3),'cdata',fig.zoom_imgs{3})
    end    
end

function zoomOut(~,~) 
    figure(handles.fig_h)
    subplot(handles.sub_h)
    tmp = get(zoom);
    if strcmp(tmp.Enable,'on') && strcmp(tmp.Direction,'out')
        zoom off
        % change out label to off
        set(handles.zoom_h(2),'cdata',fig.zoom_imgs{2})
    else
        set(zoom,'direction','out','enable','on')
        pan off
        % change out label to on
        set(handles.zoom_h(2),'cdata',fig.zoom_imgs{5})
        % change in label to off
        set(handles.zoom_h(1),'cdata',fig.zoom_imgs{1}) 
        % change pan label to off
        set(handles.zoom_h(3),'cdata',fig.zoom_imgs{3})
    end
end

function panFunc(~,~) 
    figure(handles.fig_h)
    subplot(handles.sub_h)
    tmp = get(pan);
    if strcmp(tmp.Enable,'on') 
        pan off
        % change pan label to off
        set(handles.zoom_h(3),'cdata',fig.zoom_imgs{3})
    else
        pan on
        zoom off
        % change pan label to on
        set(handles.zoom_h(3),'cdata',fig.zoom_imgs{6})
        % change in label to off
        set(handles.zoom_h(1),'cdata',fig.zoom_imgs{1}) 
        % change out label to off
        set(handles.zoom_h(2),'cdata',fig.zoom_imgs{2})
    end
end

% pre zoom/pan function 
function getZoom(~,event)
    if event.Axes ~= handles.sub_h
        subplot(event.Axes)
        fig.sub_ax = axis;
    end
end

% post zoom/pan function 
function setZoom(obj,event,is_pan)
    if event.Axes ~= handles.sub_h
        subplot(event.Axes)
        axis(fig.sub_ax);
    else
        if nargin > 2 && is_pan, return; end
        if strcmp(get(obj,'SelectionType'),'open')
            axis_lim = [0 vinfo.sy 0 vinfo.sx]+.5;
            subplot(handles.sub_h)
            axis(axis_lim)
            if ~bool.do_play
                bool.updating = 0; %force program to update display
            end
        end
        updateScreenpixSize;
        updateDisplay(state.curr_frame);
    end        
end

function updateScreenpixSize
    subplot(handles.sub_h)
    ax = axis; img_height = ax(4)-ax(3);
    sub_height = fig.sub_height;                
    state.screen_pix_sz = sub_height/img_height; 
    state.linewidth = sqrt(state.fly_length*state.screen_pix_sz/20);
end

function zoomOnFly(fly_id)
    if ~bool.auto_zoom, return; end    
    if numel(state.curr_flies) < size(trk.data,1)
        % we are already zoomed in on chamber
        return;
    end
    
    pos = trk.data(fly_id,state.curr_frame,1:2);
    if isnan(pos(1)), return; end
    subplot(handles.sub_h)
    majorax = trk.data(:,:,4);
    radius = nanmean(majorax(:))*10;
    radius = min([vinfo.sx/2 vinfo.sy/2 radius]);
    xlimit = pos(1)+[-1 1]*radius;
    if xlimit(1) < 1
        xlimit = [1 2*radius+1];
    elseif xlimit(2) > vinfo.sy
        xlimit = [vinfo.sy-2*radius vinfo.sy];
    end
    ylimit = pos(2)+[-1 1]*radius;
    if ylimit(1) < 1
        ylimit = [1 2*radius+1];
    elseif ylimit(2) > vinfo.sx
        ylimit = [vinfo.sx-2*radius vinfo.sx];
    end
    axis([xlimit ylimit]);
    updateScreenpixSize;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Chamber specific functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function findChamber()
    set(handles.active_fly_h,'String',num2str(state.active_fly));
    if isfield(trk,'flies_in_chamber')         
        for ii=1:numel(trk.flies_in_chamber);
            if ismember(state.active_fly,trk.flies_in_chamber{ii})
                state.curr_chamber = ii;
                updateChamberROI();
                break
            end
        end        
    else
        return;
    end
end

function updateChamber(chamber)
    % set current and active flies
    if chamber > numel(trk.flies_in_chamber)
        % set field of view to be entire video
        state.curr_flies = 1:size(trk.data,1);   
        axis_lim = [1 vinfo.sy 1 vinfo.sx];
        if isempty(state.roi)
            updateChamberROI()
        end
    else
        state.curr_chamber = chamber;
        state.curr_flies = trk.flies_in_chamber{state.curr_chamber};           
        state.active_fly = state.curr_flies(1);
        updateChamberROI();
        axis_lim = state.roi;
    end
    if ~isempty(actions.beh_labels)
        setBouts();
    end
    subplot(handles.sub_h)
    axis(axis_lim)
end

function updateChamberROI()
    curr_flies = trk.flies_in_chamber{state.curr_chamber};
    x_s = trk.data(curr_flies,:,1); 
    y_s = trk.data(curr_flies,:,2); 
    ax = trk.data(curr_flies,:,4);
    major_ax = median(ax(~isnan(ax)));
    axis_lim(1) = max(1,min(x_s(:))-major_ax);
    axis_lim(2) = min(vinfo.sy,max(x_s(:))+major_ax);
    axis_lim(3) = max(1,min(y_s(:))-major_ax);
    axis_lim(4) = min(vinfo.sx,max(y_s(:))+major_ax);      
    state.roi = axis_lim;
end

function chamberZoomIn(~,~) 
    flies = trk.flies_in_chamber{state.curr_chamber}; 
    state.curr_flies = flies;
    axis_lim = state.roi;
    axis_lim([1 3]) = axis_lim([1 3])+1;
    axis_lim([2 4]) = axis_lim([2 4])-1;
    subplot(handles.sub_h)
    axis(axis_lim)
    updateScreenpixSize;
    updateSwaps(0);
    set(handles.auto_zoom_h,'visible','off')
    updateDisplay(state.curr_frame)
end

function chamberZoomOut(~,~) 
    state.curr_flies = 1:size(trk.data,1);
    axis_lim = [1 vinfo.sy 1 vinfo.sx];
    subplot(handles.sub_h)
    axis(axis_lim)    
    updateScreenpixSize;      
    updateSwaps(0);    
    set(handles.auto_zoom_h,'visible','on')
    updateDisplay(state.curr_frame)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Feature navigation functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setFeat(hObj,~) 
    state.curr_feat = get(hObj,'value');
    getFeatvecCond();
    updateDisplay(state.curr_frame);
end

function needHelpRadiobutton(hObj,~) 
    value=get(hObj,'value');
    if value==1
        for ii=1:numel(handles.feat_nav_h)
            set(handles.feat_nav_h(ii),'Visible','on');
        end
    else
        state.featvec_conditioned = [];
        for ii=1:numel(handles.feat_nav_h)
            set(handles.feat_nav_h(ii),'Visible','off');
        end
        updateDisplay(state.curr_frame);
    end
    getFeatvecCond();
end

function setCondition(~,~) 
    getFeatvecCond(); 
end

function threshEdit(hObj,~) 
    value = str2double(get(hObj,'string'));
    if isempty(value), return; end   
    getFeatvecCond()
end

function getFeatvecCond()
    thresh = str2double(get(handles.feat_thresh_h,'String'));
    condition = get(handles.feat_cond_h,'value');
    featvec = feat.data(:,:,state.curr_feat);
    if condition == 1       % >
        feat_cond = featvec > thresh;
    elseif condition == 2   % < 
        feat_cond = featvec < thresh;
    end
    state.featvec_conditioned = feat_cond;
    updateDisplay(state.curr_frame);
end

function findNextButton(~,~) 
    if state.curr_frame == size(state.featvec_conditioned,2)
        return;
    end
    feat_cond = state.featvec_conditioned(:,state.curr_frame+1:end);
    curr_flies = state.curr_flies;
    
    closest_d = inf;
    closest_fly = 0;
    for f=1:numel(curr_flies)
        tmp_feat_cond = feat_cond(curr_flies(f),:);
        cc = bwconncomp(tmp_feat_cond);
        if cc.NumObjects < 1
            continue;
        end
        if cc.PixelIdxList{1}(1) == 1 
            if cc.NumObjects < 2
                continue;
            end
            d_frames = cc.PixelIdxList{2}(1);
        else
            d_frames = cc.PixelIdxList{1}(1);
        end
        if d_frames < closest_d 
            closest_d = d_frames;
            closest_fly = curr_flies(f);
        end
    end
    if closest_fly == 0
        return;
    end
    next_frame = state.curr_frame+closest_d;
    state.curr_frame = next_frame;
    state.active_fly = closest_fly;
    zoomOnFly(state.active_fly)
    updateSwaps(true)
    if ~isempty(actions.beh_labels)
        setBouts()
        set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    end
    updateDisplay(state.curr_frame)
end

function findPrevButton(~,~) 
    if state.curr_frame == 1
        return;
    end
    feat_cond = state.featvec_conditioned(:,1:state.curr_frame-1);
    curr_flies = state.curr_flies;
    if isfield(trk,'flies_in_chamber')
        curr_flies = trk.flies_in_chamber{state.curr_chamber};
    end
    
    closest_frame = -inf;
    closest_fly = 0;
    for f=1:numel(curr_flies)
        tmp_feat_cond = feat_cond(curr_flies(f),:);
        cc = bwconncomp(tmp_feat_cond);
        if cc.NumObjects < 1
            continue;
        end
        if cc.PixelIdxList{end}(end) == numel(tmp_feat_cond) 
            if cc.NumObjects < 2
                continue;
            end
            frame = cc.PixelIdxList{end-1}(1);
        else
            frame = cc.PixelIdxList{end}(1);
        end
        if frame > closest_frame 
            closest_frame = frame;
            closest_fly = curr_flies(f);
        end
    end
    if closest_fly == 0
        return;
    end
    state.curr_frame = closest_frame;
    state.active_fly = closest_fly;
    zoomOnFly(state.active_fly)
    updateSwaps(true)
    if ~isempty(actions.beh_labels)
        setBouts()
        set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    end
    updateDisplay(state.curr_frame)    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Display settings functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function showAll(hObj,~) 
    value = get(hObj,'value');
    bool.show_trk = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end
function showEllipse(hObj,~) 
    value = get(hObj,'value');
    bool.show_ellipse = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end
function showTrail(hObj,~) 
    value = get(hObj,'value');
    bool.show_trail = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end
function showWings(hObj,~) 
    value = get(hObj,'value');
    bool.show_wings = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end
function showLegs(hObj,~) 
    value = get(hObj,'value');
    bool.show_legs = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end

function showSeg(hObj,~) 
    value = get(hObj,'value');
    bool.show_seg = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end

function showImg(hObj,~) 
    value = get(hObj,'value');
    bool.show_img = value;
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end

function autoZoom(hObj,~)
    value = get(hObj,'value');
    bool.auto_zoom = value;    
    if ~bool.do_play, updateDisplay(state.curr_frame); end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Id swap functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function goToSwitchId(id)
    swap.id_switch = max(min(id,size(swap.switches,1)),0);
    set(handles.swap_id_h,'String',num2str(swap.id_switch))
    if swap.id_switch > 0
        state.curr_frame = swap.switches(swap.id_switch,1);
        switch_flies = swap.switches(swap.id_switch,3:4);
        if ~ismember(state.active_fly,switch_flies)
            state.active_fly = switch_flies(1);
            findChamber;
        end
        zoomOnFly(state.active_fly)
        updateDisplay(state.curr_frame);
    end    
end

function idSwitchUp(~,~) 
    swap.id_switch = min(swap.id_switch+1,size(swap.switches,1));
    goToSwitchId(swap.id_switch)
end

function idSwitchDown(~,~) 
    swap.id_switch = max(swap.id_switch-1,0);
    goToSwitchId(swap.id_switch)
end

function setIdSwitch(hObj,~) 
    swap.id_switch = str2num(get(hObj,'String'));
    goToSwitchId(swap.id_switch)
end

function swapId(frame,flies, do_update)
    if nargin < 3
        do_update = 1;
    end
    if nargin < 2 
        if isfield(trk,'flies_in_chamber') 
            flies = trk.flies_in_chamber{state.curr_chamber};
        else
            flies = state.curr_flies;
        end
        f1 = state.active_fly;
        if numel(flies) == 2
            f2 = setdiff(flies,f1);
        else
            % wait for user to pick the next fly
            img = get(handles.img_h,'cdata');
            set(handles.img_h,'cdata',img*.7); 
            str = get(handles.do_swap_h,'string');
            set(handles.do_swap_h,'string','<< select');            
            state.waitingformouse = 1;
            while state.waitingformouse == 1
                waitforbuttonpress;
            end
            f2 = state.active_fly;                
            set(handles.do_swap_h,'string',str);
            if f1 == f2
                updateDisplay(state.curr_frame);
                return; 
            end
        end
    else
        f1 = flies(1); f2 = flies(2);
        if f1 == f2, return; end 
    end
    % swap trk info
    temp = trk.data(f1,(frame):end,:);
    trk.data(f1,(frame):end,:) = trk.data(f2,(frame):end,:);
    trk.data(f2,(frame):end,:) = temp;
    % swap seg info
    temp = trk.obj_list(f1,(frame):end);
    trk.obj_list(f1,(frame):end) = trk.obj_list(f2,(frame):end);
    trk.obj_list(f2,(frame):end) = temp;
    % swap feat info (temporarily, recomputed on save)
    if ~isempty(feat)
        temp = feat.data(f1,(frame):end,:);
        feat.data(f1,(frame):end,:) = feat.data(f2,(frame):end,:);
        feat.data(f2,(frame):end,:) = temp;
    end
    % swap swap info
    inds11 = swap.switches(:,2)>=frame & swap.switches(:,3)==f1;
    inds12 = swap.switches(:,2)>=frame & swap.switches(:,4)==f1;
    inds21 = swap.switches(:,2)>=frame & swap.switches(:,3)==f2;
    inds22 = swap.switches(:,2)>=frame & swap.switches(:,4)==f2;
    swap.switches(inds11,3) = f2;
    swap.switches(inds12,4) = f2;
    swap.switches(inds21,3) = f1;
    swap.switches(inds22,4) = f1;
    % swap trk.flags
    inds11 = trk.flags(:,4)>=frame & trk.flags(:,1)==f1;
    inds12 = trk.flags(:,4)>=frame & trk.flags(:,2)==f1;
    inds21 = trk.flags(:,4)>=frame & trk.flags(:,1)==f2;
    inds22 = trk.flags(:,4)>=frame & trk.flags(:,2)==f2;
    trk.flags(inds11,1) = f2;
    trk.flags(inds12,2) = f2;
    trk.flags(inds21,1) = f1;
    trk.flags(inds22,2) = f1;         
    % update swap.swaps
    temp = swap.swaps(frame,f1);
    swap.swaps(frame,f1) = swap.swaps(frame,f2);
    swap.swaps(frame,f2) = temp;
    % change active fly back to the fly it was before
    if do_update
        state.active_fly = f1;
        findChamber;
        updateDisplay(state.curr_frame);
    end
end

function swapIds(~,~) 
    swapId(state.curr_frame);
    n_flies = size(trk.data,1);
    indic = (swap.swaps - repmat(1:n_flies,vinfo.n_frames,1))~=0;
    if sum(indic(:)) > 0
        set(handles.save_swaps_h,'enable','on');
        swaps = swap.swaps;
        save(fullfile(files.path,files.swap),'swaps');
    else
        set(handles.save_swaps_h,'enable','off');
        if exist(fullfile(files.path,files.swap),'file')
            delete(fullfile(files.path,files.swap));
        end
    end
end

function switchSortBy(hObj,~)
    value = get(hObj,'value');
    if value == 1 % sort swaps by frame
        [~,sortids] = sort(swap.switches(:,1),'ascend');
    else          % sort swaps by ambiguity
        [~,sortids] = sort(swap.switches(:,5),'ascend');
    end
    swap.switches = swap.switches(sortids,:);       
    if swap.id_switch > 0
        idx = find(sortids==swap.id_switch);
        goToSwitchId(idx)
    end    
end

function saved = saveTrk(~,~) 
    saved = 1;
    n_flies = size(trk.data,1);
    indic = (swap.swaps - repmat(1:n_flies,vinfo.n_frames,1))~=0;
    if sum(indic(:)) > 0
        if quest.ask_overwrite_trk
            [answer,stopasking] = ...
                customDialog('question','Are you sure you want to overwrite track file and derived files?',...
                            12*fig.fs,{'Overwrite', 'Cancel'},'Cancel');
            if stopasking && ~strcmp(answer,'Cancel')
                quest.ask_overwrite_trk = 0;
                quest.ans_overwrite_trk = answer;
            end
        else
            answer = quest.ans_overwrite_trk;
        end
        if ~strcmp(answer,'Overwrite')
            saved = 0;
            return
        end
        h = customDialog('wait','Recomputing derived files...',12*fig.fs);
        % save trk
        save(fullfile(files.path,files.trk),'trk')
        % update segmentation if it exists
        if ~isempty(seg)
            for i=1:numel(seg)
                seg{i} = seg{i}(trk.obj_list(:,i));
            end
            segfile = [files.trk(1:end-10) '-seg.mat'];
            save(fullfile(files.path,segfile),'seg')
        end
        % delete temp swap file
        delete(fullfile(files.path,files.swap));
        swap.swaps = zeros(size(swap.swaps));
        % write and save features, JAABA files and .xls
        f_vid = fullfile(vinfo.filename);
        f_res = fullfile(files.path,files.trk);
        f_calib = fullfile(files.video_dir,'calibration.mat');
        options.save_JAABA = 0;
        tmp = dir(fullfile(files.path,'*JAABA'));
        if numel(tmp) > 0
            options.save_JAABA = 1;
        end
        tmp = dir(fullfile(files.path,'*trackfeat*'));
        options.save_xls = numel(tmp) > 0;
        % recompute features and jaaba
        recompute = 1;
        tracker_job('track_features', f_vid, f_res, f_calib, options, recompute);        
        % load the new features
        D = load(fullfile(files.path,files.feat)); feat = D.feat;
        delete(h)
        set(handles.save_swaps_h,'enable','off')        
        updateDisplay(state.curr_frame);
    end
end

function value = checkSaveSwaps(allowDiscard)
    if nargin < 1
        allowDiscard = 1;
    end
    value = 1;
    onoff = get(handles.save_swaps_h,'enable');
    if strcmp(onoff,'on')
        if allowDiscard
          answer = customDialog('question','You have unsaved track changes.',...
                           12*fig.fs,{'Save', 'Discard', 'Cancel'},'Save');
        else
          answer = customDialog('question','You have unsaved track changes.',...
                           12*fig.fs,{'Save', 'Cancel'},'Save');
        end
        if strcmp(answer,'Cancel')
            value = 0;
        elseif strcmp(answer,'Save')
            value = saveTrk;
        elseif strcmp(answer,'Discard')
            % delete swapfile file
            swapfile = fullfile(files.path,files.swap);
            if exist(swapfile,'file')
                delete(swapfile);
            end
            set(handles.save_swaps_h,'enable','off');
            n_flies = size(trk.data,1);
            swap.swaps = zeros(vinfo.n_frames,n_flies);
        end
    end
end

function updateSwaps(find_chamb)
    % find chamber id corresponding to active fly
    if find_chamb
        prev_chamber = state.curr_chamber;
        findChamber;
        if prev_chamber == state.curr_chamber, return; end
    end
    if isfield(trk,'flags')
        flags = swap.all_switches;
        if handles.switch_sort_h == 2   % sort by ambiguity
            [~,sortids] = sort(flags(:,5),'ascend');
        else                            % sort by frame
            [~,sortids] = sort(flags(:,1),'ascend');         
        end
        flags = flags(sortids,:);
        flies = state.curr_flies;
        inds = ismember(flags(:,3),flies) | ismember(flags(:,4),flies);
        swap.switches = flags(inds,:);        
    else
        return
    end
    swap.id_switch = 0;
    set(handles.nswaps_h,'String',num2str(size(swap.switches,1)))
    set(handles.swap_id_h,'String',0);            
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Bout annotation functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function goToBout(id)
    state.active_bout(state.active_fly) = max(min(id,size(actions.curr_bouts,1)),0);
    set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    if state.active_bout(state.active_fly) > 0
        state.curr_frame = actions.curr_bouts(state.active_bout(state.active_fly),1);
        % if there is no certainty annotated for this bout:
        if actions.curr_bouts(state.active_bout(state.active_fly),3)==0
            setRadioCertaintyToValue(0);
            setCertColor('r')
        else
            cert = actions.curr_bouts(state.active_bout(state.active_fly),3);
            setRadioCertaintyToValue(cert);
            setCertColor('k')
        end
        zoomOnFly(state.active_fly)
        updateDisplay(state.curr_frame);
    end    
end

function boutUp(~,~) 
    state.active_bout(state.active_fly) = min(state.active_bout(state.active_fly)+1,size(actions.curr_bouts,1));
    goToBout(state.active_bout(state.active_fly))
end

function boutDown(~,~) 
    state.active_bout(state.active_fly) = max(state.active_bout(state.active_fly)-1,0);
    goToBout(state.active_bout(state.active_fly))
end

function setBout(hObj,~) 
    state.active_bout(state.active_fly) = str2num(get(hObj,'String'));
    goToBout(state.active_bout(state.active_fly))
end

function setBeh(hObj,~) 
    val = get(hObj,'value');    
    if val==state.curr_beh
        return
    end
    state.curr_beh = val;
    setBouts()
    updateDisplay(state.curr_frame);
end

function setBehType(hObj,~) 
    val = get(hObj,'value');
    if isempty(actions.gt) || isempty(actions.pred) || state.curr_beh_type == val
        return
    end
    state.curr_beh_type = val;
    if val > 1
        % disable certainty and ability to modify actions
        for ii=1:numel(handles.bout_manip_h)
            set(handles.bout_manip_h(ii),'enable','off')
        end
        % disable certainty 
        for ii=1:numel(handles.cert_h)
            set(handles.cert_h(ii),'enable','off')
        end
    end
    setBouts()
    updateDisplay(state.curr_frame);    
end

function setRadioCertaintyToValue(value)
    if value==0 
        set(handles.cert_def_h,'Value',0);
        set(handles.cert_prob_h,'Value',0);
        set(handles.cert_maybe_h,'Value',0);
    end
    if value==1 
        set(handles.cert_def_h,'Value',0);
        set(handles.cert_prob_h,'Value',0);
        set(handles.cert_maybe_h,'Value',1);
    end
    if value==2
        set(handles.cert_def_h,'Value',0);
        set(handles.cert_prob_h,'Value',1);
        set(handles.cert_maybe_h,'Value',0);
    end
    if value==3
        set(handles.cert_def_h,'Value',1);
        set(handles.cert_prob_h,'Value',0);
        set(handles.cert_maybe_h,'Value',0);
    end
end
function setCertColor(clr)
    set(handles.cert_maybe_h,'ForegroundColor',clr);
    set(handles.cert_prob_h,'ForegroundColor',clr);
    set(handles.cert_def_h,'ForegroundColor',clr);
end
function choiceChangeCertainty(value)
    if ~isempty(state.new_bout)
        return
    end  
    if quest.ask_change_cert
        [choice,stopasking] = ...
            customDialog('question','Do you want to change the certainty of this bout?',...
                        12*fig.fs,{'Yes','No'},'No');
        if stopasking && ~strcmp(choice,'No')
            quest.ask_change_cert = 0;
            quest.ans_change_cert = choice;
        end
    else
        choice = quest.ans_change_cert;
    end       
    switch choice
        case 'Yes'
            actions.curr_bouts(state.active_bout(state.active_fly),3)=value;
            actions.gt.bouts{state.active_fly,state.curr_beh} = actions.curr_bouts;
            set(handles.save_anno_h,'enable','on');
        case 'No'
            return;
    end
end
function radioDefinitely(~,~) 
    setRadioCertaintyToValue(3);
    if state.active_bout(state.active_fly) == 0
        return
    end
    if actions.curr_bouts(state.active_bout(state.active_fly),3) ~= 0
        choiceChangeCertainty(3)  
    else
        actions.curr_bouts(state.active_bout(state.active_fly),3) = 3;
        actions.gt.bouts{state.active_fly,state.curr_beh} = actions.curr_bouts;
        set(handles.save_anno_h,'enable','on');
    end
end
function radioProbably(~,~) 
    setRadioCertaintyToValue(2);
    if state.active_bout(state.active_fly) == 0
        return
    end
    if actions.curr_bouts(state.active_bout(state.active_fly),3) ~= 0
        choiceChangeCertainty(2);
    else
        actions.curr_bouts(state.active_bout(state.active_fly),3) = 2;
        actions.gt.bouts{state.active_fly,state.curr_beh} = actions.curr_bouts;
        set(handles.save_anno_h,'enable','on');
    end
end
function radioMaybe(~,~) 
    setRadioCertaintyToValue(1);
    if state.active_bout(state.active_fly) == 0
        return
    end
    if actions.curr_bouts(state.active_bout(state.active_fly),3) ~= 0
        choiceChangeCertainty(1)  
    else
        actions.curr_bouts(state.active_bout(state.active_fly),3) = 1;
        actions.gt.bouts{state.active_fly,state.curr_beh} = actions.curr_bouts;
        set(handles.save_anno_h,'enable','on');
    end
end
function cert = selectCertainty()
    cert = 0;
    m = get(handles.cert_maybe_h,'value');
    p = get(handles.cert_prob_h,'value');
    d = get(handles.cert_def_h,'value');
    if m, cert = 1; end
    if p, cert = 2; end
    if d, cert = 3; end
end

function currBout = get_curr_bout()
    if actions.curr_frames(state.curr_frame) == 0
        currBout = 0;
    else
        type_id = get(handles.bout_type_h,'value');
        if type_id == 1 && ~isempty(actions.gt)
            currBout = actions.gt.idxmap(state.active_fly,state.curr_beh,state.curr_frame);    
        else
            currBout = actions.pred.idxmap(state.active_fly,state.curr_beh,state.curr_frame);    
        end
    end
end

function success = insertBout(fly_id,bout)
    success = 1;
    frames = bout(1):bout(2);
    intersect = numel(find(actions.gt.idxmap(fly_id,state.curr_beh,frames)));
    if intersect > 0
        customDialog('warn','Cannot overwrite pre-existing bouts',12*fig.fs);
        success = 0;
        return        
    end
    
    bouts = actions.gt.bouts{fly_id,state.curr_beh};
    if isempty(bouts)
        bouts = zeros(0,3);
    end
    inds_below = find(bouts(:,1) < bout(1));
    if numel(inds_below) == 0
        ind = 1;
        bouts = [bout; bouts(ind:end,:)];
    else
        ind = max(inds_below)+1;
        bouts = [bouts(1:ind-1,:); bout; bouts(ind:end,:)];
    end
    actions.gt.bouts{fly_id,state.curr_beh} = bouts;
    actions.gt.idxmap(fly_id,state.curr_beh,frames) = ind;
    if frames(end) < vinfo.n_frames
        inds = find(actions.gt.idxmap(fly_id,state.curr_beh,(frames(end)+1):end)>0);
        inds = inds + frames(end);
        actions.gt.idxmap(fly_id,state.curr_beh,inds) = actions.gt.idxmap(fly_id,state.curr_beh,inds)+1;
    end
    state.active_bout(fly_id) = ind;
    
    if fly_id == state.active_fly
        actions.curr_bouts = bouts;
        actions.curr_frames = zeros(1,vinfo.n_frames);
        actions.curr_frames(actions.gt.idxmap(fly_id,state.curr_beh,:) > 0) = 1;
    end
end

function removeBout(bout_id)
    frames = actions.curr_bouts(bout_id,1):actions.curr_bouts(bout_id,2);
    actions.curr_frames(frames) = 0;
    actions.curr_bouts = actions.curr_bouts([1:(bout_id-1) (bout_id+1):end],:);
    actions.gt.bouts{state.active_fly,state.curr_beh} = actions.curr_bouts;
    actions.gt.idxmap(state.active_fly,state.curr_beh,frames) = 0;
    if frames(end) < vinfo.n_frames
        inds = find(actions.curr_frames((frames(end)+1):end));
        inds = inds + frames(end);
        actions.gt.idxmap(state.active_fly,state.curr_beh,inds) = actions.gt.idxmap(state.active_fly,state.curr_beh,inds)-1;
    end
    state.active_bout(state.active_fly) = max(state.active_bout(state.active_fly)-1,0); 
end

function addBout(hObj,~) 
    text = get(hObj,'string');
    if strcmp(text,'ADD NEW')
        set(hObj,'string','END')
        state.new_bout.start = state.curr_frame;
        setRadioCertaintyToValue(2);
        setCertColor('r')
        for ii=1:numel(handles.cert_h)
            set(handles.cert_h(ii),'enable','on')
        end
    else
        set(hObj,'string','ADD NEW');
        state.new_bout.certainty = selectCertainty();
        setCertColor('k')
        state.new_bout.end = state.curr_frame;
        bout = [min(state.new_bout.start,state.new_bout.end) max(state.new_bout.start,state.new_bout.end) state.new_bout.certainty];
        state.new_bout = [];
        % add bout to current fly
        insertBout(state.active_fly,bout);
    end
    finishBoutEdit
end

function deleteBout(~,~) 
    if quest.ask_delete_bout
        [choice, stopasking] = ...
            customDialog('question','Are you sure you want to delete this bout?',...
                        12*fig.fs,{'Yes','No'},'No');
        if stopasking && ~strcmp(choice,'No')
            quest.ask_delete_bout = 0;
            quest.ans_delete_bout = choice;
        end
    else
        choice = quest.ans_delete_bout;
    end
    switch choice
        case 'Yes'
            curr_bout = get_curr_bout;
            removeBout(curr_bout);
            finishBoutEdit
        case 'No'
            return;
    end
end

function moveBout(~,~) 
    %%% only enabled when 2 flies in current chamber
    curr_bout = get_curr_bout;   
    bout = actions.curr_bouts(curr_bout,:);    
    % add bout to other fly
    curr_flies = state.curr_flies;
    if isfield(trk,'flies_in_chamber')
        curr_flies = trk.flies_in_chamber{state.curr_chamber};
    end
    other_fly = setdiff(curr_flies,state.active_fly);     
    success = insertBout(other_fly,bout);
    if success
        % remove bout from current fly
        removeBout(curr_bout);        
    end
    finishBoutEdit   
end

function copyBout(~,~) 
    %%% only enabled when 2 flies in current chamber
    curr_bout = get_curr_bout;
    bout = actions.curr_bouts(curr_bout,:);
    curr_flies = state.curr_flies;
    if isfield(trk,'flies_in_chamber')
        curr_flies = trk.flies_in_chamber{state.curr_chamber};
    end
    other_fly = setdiff(curr_flies,state.active_fly); 
    % add bout to other fly
    insertBout(other_fly,bout);
    finishBoutEdit   
end

function finishBoutEdit()
    diffr = abs(actions.gt.idxmap-actions.gt.idxmap_orig);
    if sum(diffr(:)) > 0
        set(handles.save_anno_h,'enable','on');
        save(files.tmplabelfile,'actions');
    else
        set(handles.save_anno_h,'enable','off');
        if exist(files.tmplabelfile,'file')
            delete(files.tmplabelfile);
        end
    end
    if ~isempty(actions.pred)
        computeLabelDiff()
    end
    set(handles.bout_id_h,'String',num2str(state.active_bout(state.active_fly)))
    set(handles.nbouts_h,'string',num2str(size(actions.curr_bouts,1)));    
    updateDisplay(state.curr_frame);
end

function saveLabel(~,~) 
    bouts = actions.gt.bouts;
    behs = actions.beh_labels;
    save(files.labelfile,'bouts','behs');
    actions.gt.idxmap_orig = actions.gt.idxmap;
    finishBoutEdit   
end

function value = checkSaveLabel(allowDiscard)
    if nargin < 1
        allowDiscard = 1;
    end
    value = 1;
    onoff = get(handles.save_anno_h,'enable');
    if strcmp(onoff,'on')
        if allowDiscard
           answer = customDialog('question','You have unsaved label changes.',...
                           12*fig.fs,{'Save', 'Discard', 'Cancel'},'Save');
        else
           answer = customDialog('question','You have unsaved label changes.',...
                           12*fig.fs,{'Save', 'Cancel'},'Save'); 
        end
        if strcmp(answer,'Cancel')
            value = 0;
        elseif strcmp(answer,'Save')
            saveLabel
        elseif strcmp(answer,'Discard')
            % delete tmp file
            if exist(files.tmplabelfile,'file')
                delete(files.tmplabelfile);
            end
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Save to .xls functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function saveTrkXls(~,~)
    % save track if any changes have been made
    value = checkSaveSwaps(0);
    if value == 0, return; end % user canceled action
    f_res = fullfile(files.path,files.trk);
    xlsfile = [f_res(1:end-10) '-trackfeat'];    
    if exist(xlsfile,'dir') || exist([xlsfile '.xls'],'file')
        customDialog('warn','xls file already exists',12*fig.fs)
        return
    end
    h = customDialog('wait','Saving tracks and features to xls...',12*fig.fs);    
    names = [trk.names feat.names];
    data = nan(size(trk.data,1),size(trk.data,2),numel(names));
    data(:,:,1:size(trk.data,3)) = trk.data;
    data(:,:,size(trk.data,3)+(1:size(feat.data,3))) = feat.data;
    writeXls(xlsfile,data,names);
    delete(h);
end
function saveGTXls(~,~)    
    value = checkSaveLabel(0);
    if value == 0, return; end % user canceled action
    f_act = fullfile(files.path,files.gt);
    xlsfile = f_act(1:end-4);    
    if exist(xlsfile,'dir') || exist([xlsfile '.xls'],'file')
        customDialog('warn','xls file already exists',12*fig.fs)
        return
    end
    h = customDialog('wait','Saving ground truth annotations to xls...',12*fig.fs);    
    behs = actions.beh_labels;
    bouts = actions.gt.bouts;
    [names,data] = actionsToMatrix(behs,bouts);
    writeXls(xlsfile,data,names);
    delete(h)
end
function savePredXls(~,~)    
    f_act = fullfile(files.path,files.pred);
    xlsfile = f_act(1:end-4);    
    if exist(xlsfile,'dir') || exist([xlsfile '.xls'],'file')
        customDialog('warn','xls file already exists',12*fig.fs)
        return
    end
    h = customDialog('wait','Saving predicted annotations to xls...',12*fig.fs);
    behs = actions.beh_labels;
    bouts = actions.pred.bouts;
    [names,data] = actionsToMatrix(behs,bouts);
    writeXls(xlsfile,data,names);
    delete(h)
end
function [names,data] = actionsToMatrix(behs,bouts)
    names = cell(numel(behs)*3,1);
    for i=1:numel(behs)
        names{(i-1)*3+1} = [behs{i} ' start frame'];
        names{(i-1)*3+2} = [behs{i} ' end frame'];
        names{(i-1)*3+3} = [behs{i} ' confidence'];
    end
    n_behs = numel(behs);
    n_flies = size(bouts,1);
    max_bouts = 0;
    for i=1:numel(bouts)
        max_bouts = max(max_bouts,size(bouts{i},1));
    end
    data = nan(n_flies,max_bouts,n_behs*3);
    for f=1:n_flies
        for b=1:n_behs
            tmp_bouts = bouts{f,b};
            data(f,1:size(tmp_bouts,1),(b-1)*3+(1:3)) = tmp_bouts;
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Close interface function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function myClose(~,~) 
    % check whether swap.swaps need to be saved
    value = checkSaveSwaps;
    if value == 0, return; end
    % check whether annotation needs to be saved
    value = checkSaveLabel;
    if value == 0, return; end
    % close window
    delete(handles.fig_h)
    beep on
end

end
