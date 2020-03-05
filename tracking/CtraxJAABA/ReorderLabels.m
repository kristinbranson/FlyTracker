function [outlabels] = ReorderLabels(ctrx,ftrx,f2c,expi,jd,varargin)

mindswap = myparse(varargin,'mindswap',10);

VALS = 1;
IMP = 2;
TIMESTAMP = 3;

cnflies = numel(ctrx);
fnflies = numel(ftrx);
nframes = max([ctrx.endframe]);
clabels = zeros([cnflies,nframes,3]);
for i = 1:size(jd.labels(expi).flies,1),
  fly = jd.labels(expi).flies(i,1);
  labelsshort = Labels.labelsShortInit(Labels.labelsShort(),jd.labels(expi),fly);
  labelidx = Labels.labelIdx(jd.behaviors.names,ctrx(fly).firstframe,ctrx(fly).endframe);
  labelidx = Labels.labelIdxInit(labelidx,labelsshort);
  clabels(fly,labelidx.T0:labelidx.T1,VALS) = labelidx.vals;
  clabels(fly,labelidx.T0:labelidx.T1,IMP) = labelidx.imp;
  clabels(fly,labelidx.T0:labelidx.T1,TIMESTAMP) = labelidx.timestamp;
end

flabels = zeros([fnflies,max([ftrx.endframe]),3]);
for ffly = 1:fnflies,
  for t = ftrx(ffly).firstframe:ftrx(ffly).endframe,
    if f2c(ffly,t) > 0,
      flabels(ffly,t,:) = clabels(f2c(ffly,t),t,:);
    end
  end
end

dswap = zeros([fnflies,max([ftrx.endframe])]);
for ffly = 1:fnflies,
  isswap = [f2c(ffly,1:end-1)~=f2c(ffly,2:end),false];
  dswap(ffly,:) = bwdist(isswap);
end

flabelsclean = flabels;
for i = 1:3,
  tmp = flabels(:,:,i);
  tmp(dswap<=mindswap) = 0;
  flabelsclean(:,:,i) = tmp;
end
fprintf('Exp %d: %d / %d positive and %d / %d negative labels remain\n',...
  expi,...
  nnz(flabelsclean(:,:,VALS)==1),nnz(flabels(:,:,VALS)==1),...
  nnz(flabelsclean(:,:,VALS)==2),nnz(flabels(:,:,VALS)==2));

outlabels = Labels.labels(1);
for fly = 1:fnflies,
  labelidx = Labels.labelIdx(jd.behaviors.names,ftrx(fly).firstframe,ftrx(fly).endframe);
  labelidx.vals = flabels(fly,labelidx.T0:labelidx.T1,VALS);
  labelidx.imp = flabels(fly,labelidx.T0:labelidx.T1,IMP);
  labelidx.timestamp = flabels(fly,labelidx.T0:labelidx.T1,TIMESTAMP);
  labelsShort = Labels.labelsShortFromLabelIdx(labelidx);
  outlabels = Labels.assignFlyLabelsRaw(outlabels,labelsShort,fly);
end

