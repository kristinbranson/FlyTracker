function fix_PlotFrame(handles)
% plot a single video frame
% splintered from fixerrorsgui 6/21/12 JAB

% plot image
im = handles.readframe(handles.f);
if( handles.flipud )
   for channel = 1:size( im, 3 )
      im(:,:,channel) = flipud( im(:,:,channel) );
   end
end
set(handles.him,'cdata',im);

% plot flies
for fly = 1:handles.nflies,
  fix_FixUpdateFly(handles,fly);

  if ~isdummytrk(handles.trx(fly))
    if length(handles.trx(fly).x) ~= handles.trx(fly).nframes || ...
        1 + handles.trx(fly).endframe - handles.trx(fly).firstframe ~= handles.trx(fly).nframes,
      keyboard;
    end
  end
end
