function writeJAABA(trkname,moviefilename,trk,feat,calib,outdir, ...
                    save_JAABA_trk_mat_file, save_JAABA_perframe_features, save_JAABA_movie_link_or_copy)
    if nargin < 3
        D = load(trkname); trk = D.trk;
    end
    if nargin < 4
        featname = [trkname(1:end-10) '-feat.mat'];
        D = load(featname); feat = D.feat;
    end
    if nargin < 5
        parent_dir = fileparts(fileparths(trkname));
        f_calib = fullfile(parent_dir,'calibration.mat');
        D = load(f_calib); calib = D.calib;
    end
    if nargin < 6
        outdir = [trkname(1:end-10) '_JAABA'];
    end
    if ~exist('save_JAABA_trk_mat_file', 'var') || isempty(save_JAABA_trk_mat_file) ,
        save_JAABA_trk_mat_file = true ;  % for backward compatibility
    end
    if ~exist('save_JAABA_perframe_features', 'var') || isempty(save_JAABA_perframe_features) ,
        save_JAABA_perframe_features = true ;  % for backward compatibility
    end
    if ~exist('save_JAABA_movie_link_or_copy', 'var') || isempty(save_JAABA_movie_link_or_copy) ,
        save_JAABA_movie_link_or_copy = true ;  % for backward compatibility
    end

    try
        writeJAABA_core(moviefilename,trk,feat,calib,outdir, ...
                        save_JAABA_trk_mat_file, save_JAABA_perframe_features, save_JAABA_movie_link_or_copy)        
    catch
        disp('WARNING: Could not write JAABA folders');
    end
end
