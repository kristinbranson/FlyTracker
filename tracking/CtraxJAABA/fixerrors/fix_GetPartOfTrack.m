function trk = fix_GetPartOfTrack(trk,f0,f1,trajfns)
% returns a subset of the input trx structure, from frame f0 to f1
% does not copy all fields -- convert_units must be re-run on the output track
% splintered from fixerrorsgui 6/21/12 JAB

if nargin < 4,
  trajfns = {'x','y','a','b','theta'};
end

i0 = trk.off+(f0);
i1 = trk.off+(f1);
i0 = max(1,i0);
i1 = min(i1,trk.nframes);
for j = 1:numel(trajfns),
  fn = trajfns{j};
  trk.(fn) = trk.(fn)(:,i0:min(i1,size(trk.(fn),2)),:);
end
% trk.x = trk.x(i0:i1);
% trk.y = trk.y(i0:i1);
% trk.a = trk.a(i0:i1);
% trk.b = trk.b(i0:i1);
% trk.theta = trk.theta(i0:i1);
trk.nframes = max(0,i1-i0+1);
trk.firstframe = max(f0,trk.firstframe);
trk.endframe = min(trk.endframe,f1);
trk.off = -trk.firstframe + 1;
if isfield( trk, 'timestamps' )
   if i1 < i0
      trk.timestamps = [];
   elseif length( trk.timestamps ) >= i1
      trk.timestamps = trk.timestamps(i0:i1);
   else
      warning( 'track timestamps are no longer accurate' )
      fprintf( 1, 'something strange is going on here --\n   subsampling track from %d to %d but only %d timestamps present\n', i0, i1, length( trk.timestamps ) );
   end
end
%trk.f2i = @(f) f - trk.firstframe + 1;
