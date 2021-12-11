function trk1 = fix_CatTracks(trk1,trk2,trajfns)
% concatenates trk2 onto trk1
% does not copy all fields -- convert_units must be re-run on the output track
% splintered from fixerrorsgui 6/21/12 JAB


if nargin < 3,
  trajfns = {'x','y','a','b','theta'};
end

n = trk2.nframes;
for j = 1:numel(trajfns),
  fn = trajfns{j};
  trk1.(fn)(:,end+1:end+n,:) = trk2.(fn);
end
% trk1.x(end+1:end+n) = trk2.x;
% trk1.y(end+1:end+n) = trk2.y;
% trk1.a(end+1:end+n) = trk2.a;
% trk1.b(end+1:end+n) = trk2.b;
% trk1.theta(end+1:end+n) = trk2.theta;
trk1.nframes = trk1.nframes + n;
trk1.endframe = trk1.endframe+n;
if isfield( trk1, 'timestamps' ) && isfield( trk2, 'timestamps' )
   trk1.timestamps(end+1:end+n) = trk2.timestamps;
end
