
% Augment features to be better suited for learning problems.
%
% To augment features, use:
%
%    feat = feat_augment(feat)
%
% where:
%
%    feat   - feature structure, obtained from feat_compute 
%              (stored as *-feat.mat)
%
% Takes log of features that are lognormally distributed
% Normalizes features that are fly-variant (such as size)
% Adds 1st and 2nd derivatives of each feature to the data matrix
%
function aug_feat = feat_augment(feat)
    aug_data = feat_augment_data(feat.data, feat.names) ;
    aug_names = feat_augment_names(feat.names) ;
    aug_feat = struct('names', {aug_names}, 'units', {feat.units}, 'data', {aug_data}) ;
end
