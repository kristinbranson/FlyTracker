function labelidx = FlyTrackerBouts2LabelIdx(bouts,nframes)

nflies = numel(bouts);
labelidx = zeros(nflies,nframes);
for fly = 1:nflies,
  if isempty(bouts{fly}),
    continue;
  end
  labelidx(fly,:) = 2;
  for i = 1:size(bouts{fly},1),
    t0 = bouts{fly}(i,1);
    t1 = bouts{fly}(i,2);
    labelidx(fly,t0:t1) = 1;
  end
end