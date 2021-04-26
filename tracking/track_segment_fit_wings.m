function [wing_pxls,pts] = track_segment_fit_wings(fg_size,imsize,wing_cc,ws,rot_vec,center,bbox,pos,calib)

wing_pix = vertcat(wing_cc.PixelIdxList{ws});

% if only one wing, split it along the fly's major axis
if numel(ws) == 1
  wing_img = zeros(fg_size);
  wing_img(wing_pix) = 1;
  %center = detect.body_props(bods(b)).Centroid;
  center(1) = center(1) - bbox(3)+1;
  center(2) = center(2) - bbox(1)+1;
  rad = calib.PPM*10;
  x1 = center(1)-rot_vec(1)*rad; y1 = center(2)-rot_vec(2)*rad;
  x2 = center(1)+rot_vec(1)*rad; y2 = center(2)+rot_vec(2)*rad;
  [y,x] = ind2sub(fg_size,wing_pix);
  dx = x2-x1; dy = y2-y1;
  dists = abs(dx*(y1-y) - dy*(x1-x)) / sqrt(dx^2+dy^2);
  wing_img(wing_pix(dists<.75)) = 0;
  new_wing_cc = bwconncomp(wing_img);
  sz = zeros(1,new_wing_cc.NumObjects);
  for nw=1:new_wing_cc.NumObjects
    sz(nw) = numel(new_wing_cc.PixelIdxList{nw});
  end
  [~,inds] = sort(sz,'descend');
  if numel(inds)>2, inds = inds(1:2); end
  ws = wing_cc.NumObjects+(1:numel(inds));
  wing_cc.PixelIdxList(ws) = new_wing_cc.PixelIdxList(inds);
  wing_cc.NumObjects = wing_cc.NumObjects + numel(inds);
  wing_pix = wing_pix(dists>.75);
end
[I,J] = ind2sub(fg_size,wing_pix);
wing_pxls = sub2ind_faster(imsize,I+bbox(1)-1,J+bbox(3)-1);
%b_wing_pixels{bods(b)} = wing_pxls;

% find extremal points of wings
pts = cell([numel(ws) 1]);
for wn = 1:numel(ws)
  w = ws(wn);
  pix = wing_cc.PixelIdxList{w};
  [I,J] = ind2sub(fg_size,pix);
  dists = (I-pos(2)).^2 + (J-pos(1)).^2;
  [~, ind] = max(dists);
  [x, y] = ind2sub(fg_size, pix(ind));
  x = x+bbox(1)-1;
  y = y+bbox(3)-1;
  pts{wn} = [y x];
end
%b_wing_pts{bods(b)} = pts;