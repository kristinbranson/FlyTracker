function handles = SetFlyColors(handles)
% set the order we will assign colors to flies
% splintered from fixerrorsgui 6/23/12 JAB

D = squareform(pdist((1:handles.nflies)'));
isassigned = false(1,handles.nflies);
D(:,handles.nflies) = nan;
handles.colororder = zeros(1,handles.nflies);
handles.colororder(1) = handles.nflies;
isassigned(handles.nflies) = true;
for i = 2:handles.nflies,
  mind = min(D(isassigned,:),[],1);
  maxd = max(mind);
  j = find(mind==maxd);
  [tmp,k] = max(D(handles.colororder(i-1),j));
  j = j(k);
  handles.colororder(i) = j;
  D(:,j) = nan;
  isassigned(j) = true;
end
handles.colors0 = jet(handles.nflies);
handles.colors = handles.colors0(handles.colororder,:);
