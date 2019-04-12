
function varargout = customDialog(type,varargin)
    if strcmp(type,'warn')
        warnDialog(varargin{:});
        varargout = {};
    elseif strcmp(type,'wait')
        h = waitDialog(varargin{:});
        varargout = {h};
    elseif strcmp(type,'question')
        if nargout == 2
            [answer,ticked] = questionDialog(varargin{:});
            varargout = {answer,ticked};
        else
            answer = questionDialog(varargin{:});
            varargout = {answer};    
        end
    else
        disp(['Error: ' type ' is not a valid dialog type.']);
    end
end

function warnDialog(text,fontsize)
    drawnow
    bgclr = .94*[1 1 1];
    % position box
    width = max(round(numel(text)*fontsize*.7)+20,200);
    scrsz = get(0,'ScreenSize');
    position = [scrsz(3)/2-width/2 scrsz(4)/2-40+110 width 80];    
    % load dialog
    h = dialog('position',position,'name','Warning','color',bgclr);
    % set text
    uicontrol('Parent',h,'Style','text','Position',[10 35 width-20 30],...
           'String',text,'fontsize',fontsize,'backgroundcolor',bgclr);
    % set button
    hb = uicontrol('Parent',h,'Style','pushbutton','Position',[width/2-20 10 40 30],...
           'String','OK','fontsize',fontsize,'backgroundcolor',bgclr,...
           'callback',@closeFunc);
    movegui(h)
    drawnow
    uicontrol(hb); 
    function closeFunc(hObj,~)
        parent_h = get(hObj,'parent');
        delete(parent_h);
        drawnow
    end    
end

function h = waitDialog(text,fontsize)
    drawnow
    bgclr = .94*[1 1 1];
    % position box
    width = max(round(numel(text)*fontsize*.7)+20,200);
    scrsz = get(0,'ScreenSize');
    position = [scrsz(3)/2-width/2 scrsz(4)/2-30+110 width 60];    
    % load dialog
    h = dialog('position',position,'name','Please wait','color',bgclr);
    % set text
    uicontrol('Parent',h,'Style','text','Position',[10 10 width-20 30],...
           'String',text,'fontsize',fontsize,'backgroundcolor',bgclr);   
    movegui(h) 
end

function [answer,ticked] = questionDialog(text,fontsize,answers,default_answer)
    drawnow    
    bgclr = .94*[1 1 1];
    do_tick = nargout>1;   
    % initialize outputs
    answer = default_answer;
    if do_tick, ticked = 0; end
    % position box
    textwidth = round(numel(text)*fontsize*.7)+20;
    buttonwidth = 70;
    tickwidth = 120;
    bottomwidth = (buttonwidth+5)*numel(answers)+do_tick*tickwidth+20;
    width = max(max(textwidth,bottomwidth),200);
    scrsz = get(0,'ScreenSize');
    position = [scrsz(3)/2-width/2 scrsz(4)/2-45+110 width 90];    
    % load dialog
    h = dialog('position',position,'name','Question','color',bgclr);
    % set text
    uicontrol('Parent',h,'Style','text','Position',[10 40 width-20 30],...
           'String',text,'fontsize',fontsize,'backgroundcolor',bgclr);    
    % set button
    button_span = numel(answers)*buttonwidth + (numel(answers)-1)*5 + do_tick*(tickwidth+5);
    button_start = width/2-button_span/2;
    hs = zeros(1,numel(answers));
    for a=1:numel(answers)
        hs(a) = uicontrol('Parent',h,'Style','pushbutton',...
           'Position',[button_start+(a-1)*(buttonwidth+5) 10 buttonwidth 30],...
           'String',answers{a},'fontsize',fontsize,'backgroundcolor',bgclr,...
           'callback',@answerFunc);
    end   
    % set tick if specified
    if do_tick
        tick_h = uicontrol('Parent',h,'Style','checkbox',...
            'Position',[width-10-tickwidth 10 tickwidth 30],...
            'String','don''t ask again','fontsize',fontsize,...
            'horizontalAlignment','right','backgroundcolor',bgclr);
    end    
    % set active button to be the default answer
    movegui(h)
    drawnow
    uicontrol(hs(strcmp(default_answer,answers)));
    % wait until dialog closes
    waitfor(h);
    function answerFunc(hObj,~)
        answer = get(hObj,'String');
        if do_tick
            ticked = get(tick_h,'Value');
        end
        parent_h = get(hObj,'parent');
        delete(parent_h);
        drawnow
    end
end
