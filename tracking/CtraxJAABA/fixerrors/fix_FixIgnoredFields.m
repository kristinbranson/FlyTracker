function trx = fix_FixIgnoredFields(handles)
% Some trx fields are ignored during tracking/editing, because they can be
% re-derived from existing data. This function does that.
%
% splintered from fixerrorsgui 6/23/12 JAB

trx = handles.trx;

% fix timestamps
if isfield(handles,'timestamps'),
  for i = 1:numel(handles.trx),
    if isdummytrk(handles.trx(i)),
      continue;
    end
    t0 = handles.trx(i).firstframe;
    t1 = handles.trx(i).endframe;
    trx(i).timestamps = handles.timestamps(t0:t1);
  end
end

% all the converted fields may be wrong; reconvert from 
if ~isempty( trx )
   trx = apply_convert_units(trx);
end
