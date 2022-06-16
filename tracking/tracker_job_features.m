function tracker_job_features(f_vid, f_res, f_calib, options, recompute)
  % Compute features from tracking data
  if nargin < 5 || isempty(recompute)
      recompute = 0;
  end
  calib = load(f_calib); calib = calib.calib;            

  % write feat file  
  featfile = [f_res(1:end-10) '-feat.mat'];
  if ~exist(featfile,'file') || recompute
    trk = load(f_res); trk = trk.trk;    
    feat = feat_compute(trk,calib);
    save(featfile,'feat');
  end

  % save xls files
  if options.save_xls
      xlsfile = [f_res(1:end-10) '-trackfeat'];
      if ~exist(xlsfile,'dir') || ~exist([xlsfile '.xls'],'file') || recompute
         if ~exist('trk','var')
            trk = load(f_res); trk = trk.trk;
         end
         if ~exist('feat','var')
            feat = load(featfile); feat = feat.feat;
         end
         names = [trk.names feat.names];
         data = nan(size(trk.data,1),size(trk.data,2),numel(names));
         data(:,:,1:size(trk.data,3)) = trk.data;
         data(:,:,size(trk.data,3)+(1:size(feat.data,3))) = feat.data;
         writeXls(xlsfile,data,names);
      end
  end  
  
  % write JAABA folders
  if options.save_JAABA
      JAABA_dir = [f_res(1:end-10) '-JAABA'];
      if (~exist(JAABA_dir,'dir') || recompute)      
         if ~exist('trk','var')
             trk = load(f_res); trk = trk.trk;
         end
         if ~exist('feat','var')
             feat = load(featfile); feat = feat.feat;
         end
         % augment features (with log, norms, and derivatives)
         feat = feat_augment(feat);      
         writeJAABA(f_res,f_vid,trk,feat,calib);
      end     
  end
 
end
