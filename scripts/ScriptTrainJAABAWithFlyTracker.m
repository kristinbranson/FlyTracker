%% retrain JAABA classifier using FlyTracker tracks


%behavior = 'chase'; 
behavior = 'FeAgg';
fakectraxnames = false;
missingtrainingdata = true;

switch behavior,
  case 'chase',
    jaabaloc = '/groups/branson/home/bransonk/behavioranalysis/code/Jdetect/Jdetect/perframe';
    rootoutdir = ['/groups/branson/home/bransonk/behavioranalysis/data/JAABAFlyTracker/Data_',behavior];
    jabdir = '/groups/branson/home/robiea/Projects_data/JAABA/ProjectFiles_jab';
    outjabdir = '/groups/branson/home/bransonk/behavioranalysis/data/JAABAFlyTracker/ProjectFiles_jab';
    jabfile = fullfile(jabdir,'ChaseAR_new_v10p0.jab');
    outjabfile = fullfile(outjabdir,'ChaseAR_new_v10p0_FT.jab');
    codedir = fileparts(mfilename('fullpath'));
    fbadir = '/groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis';
    rootdatadir = '/nearline/branson/bowl_data';
    protocol = 'current';
    addpath(jaabaloc);
    SetUpJAABAPath;
    
    if ispc,
      jabfile = JaneliaLinux2WinPath(jabfile);
      rootoutdir = JaneliaLinux2WinPath(rootoutdir);
      fbadir = JaneliaLinux2WinPath(fbadir);
      rootdatadir = JaneliaLinux2WinPath(rootdatadir);
      outjabdir = JaneliaLinux2WinPath(outjabdir);
      outjabfile = JaneliaLinux2WinPath(outjabfile);
    end
    addpath(fbadir); 
    
    if ~exist(outjabdir,'dir'),
      mkdir(outjabdir);
    end
    doflytrack = true;

  case 'FeAgg'
    jaabaloc = 'JAABA';
    rootoutdir = '/groups/branson/bransonlab/ForFemaleAggClassifier/FilesForFeFeAgg7Classifier_FlyTracker';
    jabfile = '/groups/branson/bransonlab/ForFemaleAggClassifier/FilesForFeFeAgg7Classifier_Ctrax/FeAgg_v7.jab';
    modjabfile = '/groups/branson/bransonlab/ForFemaleAggClassifier/FilesForFeFeAgg7Classifier_Ctrax/FeAgg_v7_fixpaths.jab';
    outjabfile = '/groups/branson/bransonlab/ForFemaleAggClassifier/FeAgg_v7_FT.jab';
    gtjabfile = '/groups/branson/bransonlab/ForFemaleAggClassifier/FilesForFeFeAgg7Classifier_Ctrax/FvFagg4_grounded2.jab';
    gtrootdir = '/groups/branson/bransonlab/ForFemaleAggClassifier/AllGT_forFvFagg4_grounded2';
    codedir = fileparts(mfilename('fullpath'));
    fbadir = '/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis';
    rootdatadir = '/groups/branson/bransonlab/ForFemaleAggClassifier/FilesForFeFeAgg7Classifier_Ctrax';

    protocol = '20150717_flybubble_flybowlMing';
    addpath(fbadir);
    modpath;
    doflytrack = false;
    
    jd = load(jabfile,'-mat');
    jdmod = jd;
    for i = 1:numel(jd.x.expDirNames),
      expdir0 = jd.x.expDirNames{i};
      [~,expname] = fileparts(expdir0);
      expdir1 = fullfile(rootdatadir,expname);
      assert(exist(expdir1,'dir')>0);
      jdmod.x.expDirNames{i} = expdir1;
    end
    jdmod.x.gtExpDirNames = cell(1,0);
    jdmod.x.gtLabels(:) = [];
    save(modjabfile,'-struct','jdmod','-mat');
    
    jabfile = modjabfile;
  otherwise 
    
    error('Not implemented: behavior = %s',behavior);
    
end
  
dataloc_params = ReadParams(fullfile(fbadir,'settings',protocol,'dataloc_params.txt'));
dataloc_params.flytrackertrackstr = 'movie-track.mat';

if ~exist(rootoutdir,'dir'),
  mkdir(rootoutdir);
end

assert(exist(jabfile,'file') > 0);

jd = loadAnonymous(jabfile);
expdirs_train = jd.expDirNames;
if ispc,
  expdirs_train = JaneliaLinux2WinPath(expdirs_train);
end

assert(all(cellfun(@exist,expdirs_train)>0));

%% track all experiments in the jab file using FlyTracker

if doflytrack,
  
  ncores = 16;
  
  for moviei = 1:numel(expdirs_train),
    
    expdir = expdirs_train{moviei};
    [~,expname] = fileparts(expdir);
    outexpdir = fullfile(rootoutdir,expname);
    outmoviefile = fullfile(outexpdir,dataloc_params.moviefilestr);
    moviefile = fullfile(expdir,dataloc_params.moviefilestr);
    [~,vidname] = fileparts(dataloc_params.moviefilestr);
    trkfile = fullfile(outexpdir,[vidname '-track.mat']);
    
    if ~exist(outexpdir,'dir'),
      mkdir(outexpdir);
    end
    if ~exist(outmoviefile,'file'),
      unix(sprintf('ln -s %s %s',moviefile,outmoviefile));
    end
    
    options.num_cores   = maxNumCompThreads;
    options.num_chunks = options.num_cores*2;
    options.save_JAABA  = true;
    options.save_xls    = false;
    options.save_seg    = false;
    options.f_parent_calib = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/calibration20190712.mat';
    options.force_calib = true;
    options.expdir_naming = true;
    options.fr_sample = 200;
    
    if exist(trkfile,'file'),
      fprintf('Tracking done for %s, skipping.\n',expname);
    else
      jobid = sprintf('FT%s%02d',behavior,moviei);
      logfile = fullfile(outexpdir,'FlyTracker.log');
      shfile = fullfile(outexpdir,'FlyTracker.sh');
      fid = fopen(shfile,'w');
      fprintf(fid,'cd %s; matlab -nodisplay -r "FlyTrackerWrapper(''%s'',%d)"',codedir,outmoviefile,ncores);
      fclose(fid);
      unix(sprintf('chmod u+x %s',shfile));
      cmd2 = sprintf('bsub -n %d -R"affinity[core(1)]" -o %s -J %s "%s"',ncores,logfile,jobid,shfile);
      cmd3 = sprintf('ssh login1 ''source /etc/profile; %s''',cmd2);
      unix(cmd3);
    end
    
  end

end
  
% check that things are done
isdone = false(1,numel(expdirs_train));
for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outmoviefile = fullfile(outexpdir,dataloc_params.moviefilestr);
  moviefile = fullfile(expdir,dataloc_params.moviefilestr);
  [~,vidname] = fileparts(dataloc_params.moviefilestr);
  trkfile = fullfile(outexpdir,[vidname '-track.mat']);

  if exist(trkfile,'file'),
    fprintf('Tracking done for %s.\n',expname);
    isdone(moviei) = true;
  else
    isdone(moviei) = false;
  end
end
fprintf('%d / %d done.\n',nnz(isdone),numel(isdone));

%% set timestamps to correspond to movie frame timestamps

if doflytrack,
  
  for moviei = 1:numel(expdirs_train),
    
    expdir = expdirs_train{moviei};
    [~,expname] = fileparts(expdir);
    outexpdir = fullfile(rootoutdir,expname);
    intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
    assert(exist(intrxfile,'file')>0);
    outtrxfile = fullfile(outexpdir,dataloc_params.ctraxfilestr);
    td = load(intrxfile);
    [~,~,fid,headerinfo] = get_readframe_fcn(fullfile(outexpdir,dataloc_params.moviefilestr));
    td.timestamps = headerinfo.timestamps'-headerinfo.timestamps(1);
    for i = 1:numel(td.trx),
      td.trx(i).timestamps = td.timestamps(td.trx(i).firstframe:td.trx(i).endframe)';
      td.trx(i).dt = diff(td.trx(i).timestamps);
    end
    fclose(fid);
    save(outtrxfile,'-struct','td');
    
  end
  
end

%% run FBRegisterTrx on FlyTracker outputs

if doflytrack,
  
  for moviei = 1:numel(expdirs_train),
    
    expdir = expdirs_train{moviei};
    [~,expname] = fileparts(expdir);
    outexpdir = fullfile(rootoutdir,expname);
    outannfile = fullfile(outexpdir,dataloc_params.annfilestr);
    outmetadatafile = fullfile(outexpdir,dataloc_params.metadatafilestr);
    
    if ~exist(outannfile,'file'),
      inannfile = fullfile(rootdatadir,expname,dataloc_params.annfilestr);
      assert(exist(inannfile,'file')>0);
      cmd = sprintf('ln -s %s %s',inannfile,outannfile);
      unix(cmd);
    end
    if ~exist(outmetadatafile,'file'),
      inmetadatafile = fullfile(rootdatadir,expname,dataloc_params.metadatafilestr);
      assert(exist(inmetadatafile,'file')>0);
      cmd = sprintf('cp %s %s/.',inmetadatafile,outexpdir);
      unix(cmd);
    end
    if isempty(dir(fullfile(outexpdir,dataloc_params.configfilepattern))),
      inprotocol = fullfile(rootdatadir,expname,dataloc_params.configfilepattern);
      assert(~isempty(dir(inprotocol)));
      cmd = sprintf('cp %s %s/.',inprotocol,outexpdir);
      unix(cmd);
    end
    %   intrxfile = fullfile(outexpdir,'movie_JAABA','trx.mat');
    %   outtrxfile = fullfile(outexpdir,'ctrax_results.mat');
    %   if ~exist(outtrxfile,'file'),
    %     assert(exist(intrxfile,'file')>0);
    %     cmd = sprintf('ln -s %s %s',intrxfile,outtrxfile);
    %     unix(cmd);
    %   end
    
    FlyBowlRegisterTrx(outexpdir);
    
  end

end

% check that first frames and end frames match
for moviei = 1:numel(expdirs_train),

  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  ftrxfile = fullfile(outexpdir,dataloc_params.trxfilestr);
  ftrx = load(ftrxfile);
  ctrxfile = fullfile(expdir,dataloc_params.trxfilestr);
  ctrx = load(ctrxfile);
  ffirstframe = min([ftrx.trx.firstframe]);
  fendframe = max([ftrx.trx.endframe]);
  cfirstframe = min([ctrx.trx.firstframe]);
  cendframe = max([ctrx.trx.endframe]);
  assert(ffirstframe == cfirstframe && fendframe == cendframe);
  
end

%% compute some wing-related features from FlyTracker outputs
% wing-related features:
% wing_anglel <- -'wing l ang'
% wing_angler <- -'wing r ang'
% wing_areal <- 'wing l len'
% wing_arear <- 'wing r len'
% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2

if doflytrack,
  
  for moviei = 1:numel(expdirs_train),
    
    expdir = expdirs_train{moviei};
    [~,expname] = fileparts(expdir);
    outexpdir = fullfile(rootoutdir,expname);
    FlyTracker2WingTracking(outexpdir,'dataloc_params',dataloc_params);
    
  end
  
end

%% run FBComputePerFrameFeatures on outputs

if doflytrack,

  for moviei = 1:numel(expdirs_train),
    
    expdir = expdirs_train{moviei};
    [~,expname] = fileparts(expdir);
    outexpdir = fullfile(rootoutdir,expname);
    FlyBowlComputePerFrameFeatures(outexpdir);%,'forcecompute',false);
    
  end
  
end

%% fix lost training data

if missingtrainingdata,
    
  labeltimestamp = now;
  scorethresh = .1;
  
  for expi = 1:numel(expdirs_train),
    ctrax_expdir = expdirs_train{expi};
    JAABADetect(ctrax_expdir,'jabfiles',{jabfile},'forcecompute',true);
  end
  
  jdfix = jd;
  nfliesperexp = nan(1,numel(expdirs_train));
  nflyframesperexp = nan(1,numel(expdirs_train));
  nposperexp = nan(1,numel(expdirs_train));
  nnegperexp = nan(1,numel(expdirs_train));
  allclass = cell(1,numel(expdirs_train));
  allscores = cell(1,numel(expdirs_train));
  nframesperfly = cell(1,numel(expdirs_train));
  
  for expi = 1:numel(expdirs_train),
    ctrax_expdir = expdirs_train{expi};
    sd = load(fullfile(ctrax_expdir,jd.file.scorefilename{1}));
    nframesperfly{expi} = cellfun(@numel,sd.allScores.scores);
    scorescurr = [sd.allScores.scores{:}]/sd.allScores.scoreNorm;
    ispos = cell(1,numel(sd.allScores.t0s));
    for fly = 1:numel(sd.allScores.t0s),
      ispos{fly} = false(size(sd.allScores.scores{fly}));
      for i = 1:numel(sd.allScores.t0s{fly}),
        ispos{fly}(sd.allScores.t0s{fly}(i):sd.allScores.t1s{fly}(i)-1) = true;
      end
    end
    ispos = [ispos{:}];
    nfliesperexp(expi) = numel(sd.allScores.scores);
    nflyframesperexp(expi) = numel(scorescurr);
    allscores{expi} = scorescurr;
    isthresh = (ispos & scorescurr > scorethresh) | ...
      (~ispos & scorescurr < scorethresh);
    ispos = double(ispos);
    ispos(~isthresh) = -1;
    allclass{expi} = ispos;
    nposperexp(expi) = nnz(ispos==1);
    nnegperexp(expi) = nnz(ispos==0);
  end

  allscoresv = [allscores{:}];
  allclassv = [allclass{:}];
  npostotal = nnz(allclassv==1);
  nnegtotal = 2*npostotal;
  nnegpervid = ceil(nnegtotal / numel(expdirs_train));
  
  jdfix.behaviors.names{1} = [jdfix.behaviors.names{1},'p2l'];
  [~,n,ext] = fileparts(jd.file.scorefilename{1});
  jdfix.file.scorefilename{1} = [n,'p2l',ext];
  
  
  nbins = 20;
  edges = linspace(scorethresh,1,nbins+1);
  centers = (edges(1:end-1)+edges(2:end))/2;
  edges(end) = inf;
  edges(1) = -inf;
  [countspos] = histc(allscoresv(allclassv==1),edges);
  [countsneg] = histc(-allscoresv(allclassv==0),edges);
  fracpos = countspos(1:end-1) / sum(countspos);
  fracneg = countsneg(1:end-1) / sum(countsneg);
  assert(all(fracpos>0));
  figure(2);
  clf;
  bar(centers,[fracneg;fracpos]');
  xlabel('|Prediction|');
  ylabel('Fraction');
  legend({'Negative','Positive'});

  for expi = 1:numel(expdirs_train),
    
    ctrax_expdir = expdirs_train{expi};
    scorescurr = allscores{expi};
    nframestotal = numel(scorescurr);
%     sd = load(fullfile(ctrax_expdir,jd.file.scorefilename{1}));
%     nframesperfly = cellfun(@numel,sd.allScores.scores);
%     nframestotal = sum(nframesperfly);
%     scorescurr = [sd.allScores.scores{:}];
    dosample = false(1,nframestotal);
    dosample(allclass{expi}==1) = true;
    idxneg = find(allclass{expi}==0);
    [~,bin] = histc(-scorescurr(idxneg),edges);
    weight = fracpos(bin)./fracneg(bin);
    idxsample = datasample(idxneg,nnegpervid,'Replace',false,'Weights',weight/sum(weight));
    dosample(idxsample) = true;
    %idxsample = randsample(numel(idxneg),nnegpervid,false);
    %dosample(idxneg(idxsample)) = true;
    td = load(fullfile(ctrax_expdir,jd.file.trxfilename));
    jdfix.labels(expi).off = [td.trx.off];
    for fly = 1:numel(nframesperfly{expi}),
      i0 = sum(nframesperfly{expi}(1:fly-1))+1;
      i1 = sum(nframesperfly{expi}(1:fly));
      dosamplecurr = dosample(i0:i1);
      classcurr = allclass{expi}(i0:i1);
      [t0spos,t1spos] = get_interval_ends(dosamplecurr & classcurr==1);
      [t0sneg,t1sneg] = get_interval_ends(dosamplecurr & classcurr==0);
      [impt0s,impt1s] = get_interval_ends(dosamplecurr);
      names = [repmat(jdfix.behaviors.names(1),[1,numel(t0spos)]),...
        repmat(jdfix.behaviors.names(2),[1,numel(t0sneg)])];
      t0s = [t0spos,t0sneg];
      t1s = [t1spos,t1sneg];
      [~,order] = sort(t0s);
      names = names(order);
      t0s = t0s(order);
      t1s = t1s(order);
      jdfix.labels(expi).t0s{fly} = t0s;
      jdfix.labels(expi).t1s{fly} = t1s;
      jdfix.labels(expi).names{fly} = names;
      jdfix.labels(expi).flies(fly) = fly;
      jdfix.labels(expi).timestamp{fly} = repmat(labeltimestamp,[1,numel(t0s)]);
      jdfix.labels(expi).timelinetimestamp{fly} = struct(jdfix.behaviors.names{1},labeltimestamp);
      jdfix.labels(expi).imp_t0s{fly} = impt0s;
      jdfix.labels(expi).imp_t1s{fly} = impt1s;
    end
    
  end
  
  [p,n,ext] = fileparts(jabfile);
  fixjabfile = fullfile(p,[n,'_pred2labels',ext]);
  saveAnonymous(fixjabfile,jdfix);
  
  [p,n,ext] = fileparts(fixjabfile);
  trainedfixedjabfile = fullfile(p,[n,'_trained',ext]);
  input(sprintf('Open %s in JAABA and train classifier. resave as %s: ',fixjabfile,trainedfixedjabfile));

  assert(exist(trainedfixedjabfile,'file')>0);
  for expi = 1:numel(expdirs_train),
    ctrax_expdir = expdirs_train{expi};
    JAABADetect(ctrax_expdir,'jabfiles',{trainedfixedjabfile},'forcecompute',true);
  end
  
  allscoresnew = [];
  allclassnew = [];
  for expi = 1:numel(expdirs_train),
    ctrax_expdir = expdirs_train{expi};
    
    sfn = fullfile(ctrax_expdir,jdfix.file.scorefilename{1});
    sdnew = load(sfn);
    allscoresnew = [allscoresnew,[sdnew.allScores.scores{:}]/sdnew.allScores.scoreNorm];
    
    ispos1 = [];
    for fly = 1:numel(sdnew.allScores.scores),
      ispos = false(size(sdnew.allScores.scores{fly}));
      for i = 1:numel(sdnew.allScores.t0s{fly}),
        ispos(sdnew.allScores.t0s{fly}(i):sdnew.allScores.t1s{fly}(i)-1) = true;
      end
      assert(numel(ispos) == numel(sdnew.allScores.scores{fly}));
      allclassnew = [allclassnew,ispos];
    end
    
  end
  
  clf;
  scatter(allscoresv,allscoresnew,[],double(allclassnew),'.');
  axis equal;
  hold on;
  plot([-1.5,1.5],[-1.5,1.5],'k-');
  plot([-1.5,1.5],[0,0],'k-');
  plot([0,0],[-1.5,1.5],'k-');
  axis([-1.5,1.5,-1.5,1.5]);
  xlabel('Old predictions');
  ylabel('New predictions');
  cm = [     0    0.4470    0.7410
    0.8500    0.3250    0.0980];
  colormap(cm)
  
  if exist(gtjabfile,'file'),
    
    gtjd = loadAnonymous(gtjabfile);
    
    gtexpdirs = cell(1,numel(gtjd.gtExpDirNames));
    nfalseposnew = zeros(1,numel(gtjd.gtExpDirNames));
    nfalseposold = zeros(1,numel(gtjd.gtExpDirNames));
    nfalsenegnew = zeros(1,numel(gtjd.gtExpDirNames));
    nfalsenegold = zeros(1,numel(gtjd.gtExpDirNames));
    nposperexp = zeros(1,numel(gtjd.gtExpDirNames));
    nnegperexp = zeros(1,numel(gtjd.gtExpDirNames));
    %off = 0;
    for expi = 1:numel(gtjd.gtExpDirNames),
      [~,expname] = fileparts(gtjd.gtExpDirNames{expi});
      expdir = fullfile(gtrootdir,expname);
      gtexpdirs{expi} = expdir;
      %JAABADetect(expdir,'jabfiles',{trainedfixedjabfile,jabfile},'forcecompute',false);
      sdnew = load(fullfile(expdir,jdfix.file.scorefilename{1}));
      sdold = load(fullfile(expdir,jd.file.scorefilename{1}));
      
      for flyi = 1:size(gtjd.gtLabels(expi).flies,1),
        fly = gtjd.gtLabels(expi).flies(flyi,:);
        ncurr = numel(sdnew.allScores.scores{fly});
        isposlabel = nan(1,ncurr);
        labelidx = strcmp(gtjd.gtLabels(expi).names{flyi},gtjd.behaviors.names{1});
        for i = 1:numel(gtjd.gtLabels(expi).t0s{flyi}),
          isposlabel(gtjd.gtLabels(expi).t0s{flyi}(i):gtjd.gtLabels(expi).t1s{flyi}(i)-1) = labelidx(i);
        end
        isposprednew = set_interval_ends(sdnew.allScores.t0s{fly},sdnew.allScores.t1s{fly},ncurr);
        ispospredold = set_interval_ends(sdold.allScores.t0s{fly},sdold.allScores.t1s{fly},ncurr);
        nfalseposnew(expi) = nfalseposnew(expi) + nnz(~isnan(isposlabel) & isposprednew & isposlabel==0);
        nfalseposold(expi) = nfalseposold(expi) + nnz(~isnan(isposlabel) & ispospredold & isposlabel==0);
        nfalsenegnew(expi) = nfalsenegnew(expi) + nnz(~isnan(isposlabel) & ~isposprednew & isposlabel==1);
        nfalsenegold(expi) = nfalsenegold(expi) + nnz(~isnan(isposlabel) & ~ispospredold & isposlabel==1);
        nposperexp(expi) = nposperexp(expi) + nnz(isposlabel==1);
        nnegperexp(expi) = nnegperexp(expi) + nnz(isposlabel==0);
        ncurr1 = nnz(~isnan(isposlabel));
%         plot(off+1:off+ncurr1,isposlabel(~isnan(isposlabel)),'k.');
%         plot(off+1:off+ncurr1,double(ispospredold(~isnan(isposlabel)))+.01,'m.');
%         plot(off+1:off+ncurr1,double(isposprednew(~isnan(isposlabel)))+.02,'c.');
%         off = off + ncurr1;
      end
      
    end
    
    fprintf('False positive rate: Old: %d / %d = %f, New: %d / %d = %f.\n',...
      sum(nfalseposold),sum(nnegperexp),sum(nfalseposold)/sum(nnegperexp),...
      sum(nfalseposnew),sum(nnegperexp),sum(nfalseposnew)/sum(nnegperexp));
    fprintf('False negative rate: Old: %d / %d = %f, New: %d / %d = %f.\n',...
      sum(nfalsenegold),sum(nposperexp),sum(nfalseposold)/sum(nposperexp),...
      sum(nfalsenegnew),sum(nposperexp),sum(nfalseposnew)/sum(nposperexp));

%     False positive rate: Old: 506 / 12014 = 0.042118, New: 487 / 12014 = 0.040536.
%     False negative rate: Old: 499 / 5123 = 0.098770, New: 471 / 5123 = 0.095061.
    
    set(gca,'YLim',[-.1,1.3]);
    
  end
  
  
  jabfile = trainedfixedjabfile;
  jd = loadAnonymous(jabfile);
  
end

%% create a new feature type compatible with output of disco pipeline

oldfileinfo = jd.file;

if ~fakectraxnames,
  
%   [featureLexicon,animalType] = featureLexiconFromFeatureLexiconName('flies_disco','JAABA');
%   moviei = 1;
%   expdir = expdirs_train{moviei};
%   [~,expname] = fileparts(expdir);
%   outexpdir = fullfile(rootoutdir,expname);
%   pff = dir(fullfile(outexpdir,dataloc_params.perframedir,'*.mat'));
%   pff = cellfun(@(x) x(1:end-4), {pff.name}, 'UniformOutput',false);
%   lex = fieldnames(featureLexicon.perframe);
%   fprintf('Per-frame features required by flies_disco type that do not exist:\n');
%   disp(setdiff(lex,pff))
%   fprintf('Per-frame features that exist not required by fly_disco type:\n');
%   disp(setdiff(pff,lex)')
%   % biggest -> longest
%   % smallest -> shortest
%   % area_inmost -> length_inmost
%   % area_outmost -> length_outmost
%   % wing_area -> wing_length
%   assert(isempty(setdiff(lex,pff)));
  
  jddisco = loadAnonymous('/groups/branson/home/bransonk/behavioranalysis/code/FlyDiscoAnalysis/FlyTracker/scripts/demo.jab');
  
  jd.featureLexiconName = jddisco.featureLexiconName;
  jd.file = jddisco.file;
  jd.sublexiconPFNames = jddisco.sublexiconPFNames;
  jd.windowFeaturesParams = jddisco.windowFeaturesParams;
  jd.classifierStuff = jddisco.classifierStuff;
end

%% create a new jab file with the FlyTracker outputs and the reordered labels

newlabels = Labels.labels(numel(expdirs_train));
mindswap = 10;
outexpdirs = cell(size(jd.expDirNames));
behavior = jd.behaviors.names{1};
for moviei = 1:numel(expdirs_train),
  expdir = expdirs_train{moviei};
  [~,expname] = fileparts(expdir);
  outexpdir = fullfile(rootoutdir,expname);
  outexpdirs{moviei} = outexpdir;
  
  ftrx = load(fullfile(outexpdir,jd.file.trxfilename));
  ftrx = ftrx.trx;
  ctrx = load(fullfile(expdir,oldfileinfo.trxfilename));
  ctrx = ctrx.trx;
  [f2c,c2f,cost] = match_ctrax_to_flytracker(ctrx,ftrx);
  clf;
  imagesc(f2c);
  hcb = colorbar;
  xlabel('Time (fr)');
  ylabel('FlyTracker id');
  hcb.Label.String = 'Ctrax id';
  box off;
  title(sprintf('%s-%d: %s',behavior,moviei,expname),'interpreter','none');
  set(gcf,'renderer','painters');
  colormap([0,0,0;hsv(numel(ctrx))]);
  saveas(gcf,fullfile(outexpdir,'FlyTracker2Ctrax.svg'),'svg')
  
  newlabels(moviei) = ReorderLabels(ctrx,ftrx,f2c,moviei,jd,'mindswap',mindswap);

end

jd.expDirNames = outexpdirs;
jd.labels = newlabels;
saveAnonymous(outjabfile,jd);

%% train

% did this in JAABA GUI! 

%% classify 71G01 data
roottestdir = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl';
testline = 'GMR_71G01_AE_01';
testdirs = mydir(fullfile(roottestdir,[testline,'*']),'isdir',true);

PrepareFlyTracker4JAABA(testdirs,...
  'rootdatadir',rootdatadir,...
  'dataloc_params',dataloc_params);

% added this to PrepareFlyTracker4JAABA
% fracmale = .5;
% for moviei = 1:numel(testdirs),
%   outtrxfile = fullfile(testdirs{moviei},dataloc_params.trxfilestr);
%   FlyTrackerClassifySex(outtrxfile,'fracmale',fracmale);
%   outtrxfile = fullfile(testdirs{moviei},dataloc_params.wingtrxfilestr);
%   td = FlyTrackerClassifySex(outtrxfile,'fracmale',fracmale);
% end

for moviei = 1:numel(testdirs),
  JAABADetect(testdirs{moviei},'jabfiles',{outjabfile});
end

%% compare frac time for each of these

for moviei = 1:numel(testdirs),
  
  fscorefile = fullfile(testdirs{moviei},jd.file.scorefilename);
  fsd = load(fscorefile);
  [~,expname] = fileparts(testdirs{moviei});
  expdir0 = fullfile(rootdatadir,expname);
  csd = load(fullfile(expdir0,dataloc_params.statsperframematfilestr));
  sd = fsd;
  n = 0;
  d = 0;
  for i = 1:numel(sd.allScores.postprocessed),
    n = n + nnz(sd.allScores.postprocessed{i}==1);
    d = d + nnz(~isnan(sd.allScores.postprocessed{i}));
  end
  fractime = n / d;
  ffractime(moviei) = fractime;
  
  fn = sprintf('fractime_flyany_frame%s',lower(jd.behaviors.names{1}));
  cfractime(moviei) = csd.statsperexp.(fn).meanmean;
  
  fprintf('%d (%s): fractime %s ctrax: %f, flytracker: %f\n',moviei,expname,...
    jd.behaviors.names{1},cfractime(moviei),ffractime(moviei));
  
end

figure(345);
clf
plot(cfractime,ffractime,'ko','MarkerFaceColor','k');
xlabel('Frac. time Ctrax');
ylabel('Frac. time FlyTracker');
axisalmosttight;
xlim = get(gca,'XLim');
ylim = get(gca,'YLim');
lim = [min(xlim(1),ylim(1)),max(xlim(2),ylim(2))];
axis equal;
axis([lim,lim]);
hold on;
plot(lim,lim,'c-');
box off;

%% run chase classifier on some simulated data

rootoutdir = '/groups/branson/home/bransonk/behavioranalysis/data/JAABASim';
rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/fly_behaviour_sim/71g01/trx';
%rootsimtestdir = '/groups/branson/home/imd/Documents/janelia/research/FlyTrajPred_v4/pytorch/trx';
trxfilestrs = {
  'rnn50_trx_0t0_30320t1_epoch50000_SMSF_full_100hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_1000t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo0.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo1.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo2.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo3.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo4.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo5.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo6.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo7.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo8.mat'
%   'rnn50_trx_0t0_30320t1_epoch100000_SMSF_videotypev2_102hid_lr0.010000_testvideo9.mat'
  };
trxfiles = cellfun(@(x) fullfile(rootsimtestdir,x),trxfilestrs,'Uni',0);
% one real experiment that the simulator was trained on. ideally, it would
% be the one used for seeding the simulation
expdir0 = '/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_Rig1Plate15BowlA_20120316T144027';

simexpdirs = PrepareSimTrx4JAABA(trxfiles,expdir0,...
  'rootoutdir',rootoutdir,...
  'dataloc_params',dataloc_params);

% sanity check

pd = load(fullfile(simexpdirs{moviei},dataloc_params.perframedir,'velmag_ctr.mat'));
sim_mean_velmag_ctr = nanmean([pd.data{:}]);
pd = load(fullfile(testdirs{moviei},dataloc_params.perframedir,'velmag_ctr.mat'));
mean_velmag_ctr = nanmean([pd.data{:}]);


for moviei = 1:numel(simexpdirs),
  JAABADetect(simexpdirs{moviei},'jabfiles',{outjabfile});
end

simfractime = nan(1,numel(simexpdirs));
for moviei = 1:numel(simexpdirs),
  
  fscorefile = fullfile(simexpdirs{moviei},jd.file.scorefilename);
  sd = load(fscorefile);
  [~,expname] = fileparts(simexpdirs{moviei});
  n = 0;
  d = 0;
  for i = 1:numel(sd.allScores.postprocessed),
    n = n + nnz(sd.allScores.postprocessed{i}==1);
    d = d + nnz(~isnan(sd.allScores.postprocessed{i}));
  end
  fractime = n / d;
  simfractime(moviei) = fractime;
  
  fprintf('%d (%s): fractime %s: %f\n',moviei,expname,...
    jd.behaviors.names{1},simfractime(moviei));
  
end

figure(346);
clf
boxplot([ffractime,simfractime],[ones(size(ffractime)),ones(size(simfractime))+1],...
  'labels',{'Real','Simulated'});
% plot(cfractime,ffractime,'ko','MarkerFaceColor','k');
% xlabel('Frac. time Ctrax');
% ylabel('Frac. time FlyTracker');
% axisalmosttight;
% xlim = get(gca,'XLim');
% ylim = get(gca,'YLim');
% lim = [min(xlim(1),ylim(1)),max(xlim(2),ylim(2))];
% axis equal;
% axis([lim,lim]);
% hold on;
% plot(lim,lim,'c-');
box off;

%% compute per-frame stats

statsperframefeaturesfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/stats_perframefeatures.txt';
histperframefeaturesfile = '/groups/branson/home/bransonk/tracking/code/FlyTracker-1.0.5/hist_perframefeatures.txt';
for i = 1:numel(testdirs),
  FlyBowlComputePerFrameStats2(testdirs{i},'statsperframefeaturesfile',statsperframefeaturesfile,'histperframefeaturesfile',histperframefeaturesfile)
end
for i = 1:numel(simexpdirs),
  FlyBowlComputePerFrameStats2(simexpdirs{i},'statsperframefeaturesfile',statsperframefeaturesfile,'histperframefeaturesfile',histperframefeaturesfile)
end

%% plot per-frame stats

figure(123);
clf;
hold on;
plottype = 'linear';
for i = 1:1,%numel(testdirs),
  hd = load(fullfile(testdirs{i},dataloc_params.histperframematfilestr));
  plot(hd.bins.velmag_ctr.(['centers_',plottype]),hd.histperexp.velmag_ctr_flyany_frameany.(['meanfrac_',plottype]),'k-');
end
for i = 1:1,%numel(simexpdirs),
  hd = load(fullfile(simexpdirs{i},dataloc_params.histperframematfilestr));
  plot(hd.bins.velmag_ctr.(['centers_',plottype]),hd.histperexp.velmag_ctr_flyany_frameany.(['meanfrac_',plottype]),'r-');
end
xlabel('velmag_ctr','interpreter','none');
ylabel('Frac. frames');
%% compute groundtruth accuracy
