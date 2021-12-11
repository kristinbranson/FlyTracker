function v = isdummytrk(trk)

v = (any(isnan(trk.x)) || length( trk.x ) == 0);
% if v, fprintf( 1, '%d of %d are NaN\n', length(find(isnan(trk.x))), length(trk.x) ); end %%%%%%%%
