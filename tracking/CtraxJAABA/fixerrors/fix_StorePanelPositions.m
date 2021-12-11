function handles = fix_StorePanelPositions(handles)
% store the positions of the panels in the GUI
% splintered from fixerrorsgui 6/23/12 JAB

% store positions of right side panels
handles.rightpanel_tags = {'seqinfopanel','frameinfopanel','navigationpanel',...
  'seekpanel','editpanel',...
  'deletepanel','interpolatepanel','connectpanel','swappanel','extendpanel',...
  'autotrackpanel','flippanel','manytrackpanel', 'addnewtrackpanel',...
  'superposetrackspanel'};
figpos = get(handles.figure1,'Position');

ntags = numel(handles.rightpanel_tags);
handles.rightpanel_dright = nan(1,ntags);
for fni = 1:ntags,
  fn = handles.rightpanel_tags{fni};
  h = handles.(fn);
  pos = get(h,'Position');
  handles.rightpanel_dright(fni) = figpos(3)-pos(1);
end
  
% store positions of stuff below the axes
handles.bottom_tags = {'printbutton','debugbutton','playstopbutton',...
  'displaypanel','frameslider', 'flipimage_checkbox', 'showdead_checkbox'};
ntags = numel(handles.bottom_tags);
handles.bottom_width_norm = nan(1,ntags);
handles.bottom_dleft_norm = nan(1,ntags);
for fni = 1:ntags,
  fn = handles.bottom_tags{fni};
  h = handles.(fn);
  pos = get(h,'Position');
  handles.bottom_width_norm(fni) = pos(3)/figpos(3);
  handles.bottom_dleft_norm(fni) = pos(1)/figpos(3);
end

% store axes position stuff
pos = get(handles.mainaxes,'Position');
sliderpos = get(handles.frameslider,'Position');
rightpanelpos = get(handles.seqinfopanel,'Position');
handles.axes_dtop = figpos(4) - (pos(2)+pos(4));
handles.axes_dslider = pos(2) - (sliderpos(2)+sliderpos(4));
handles.axes_drightpanels = rightpanelpos(1)-(pos(1)+pos(3));
