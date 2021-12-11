function fix_EnablePanel(h,v)
% set the enabled state for a handle and all its children
% splintered from fixerrorsgui 6/23/12 JAB

children = get(h,'children');
for hchild = children,
  try
    set(hchild,'enable',v);
  catch
  end
end
