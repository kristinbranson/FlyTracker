function [savename,success] = fixerrors_f(varargin)

success = false;

[moviename,matname,annname,convertname,savename,suspiciousseqsname] = ...
  myparse(varargin,'moviename','','matname','','annname','',...
  'convertname','','savename','','suspiciousseqsname','');

%% set all defaults

setuppath;

%% read last settings
pathtofixerrors = which('fixerrors');
savedsettingsfile = strrep(pathtofixerrors,'fixerrors.m','.fixerrorsrc.mat');
if exist(savedsettingsfile,'file')
  rc = load(savedsettingsfile); 
  fns = fieldnames(rc);
  for i = 1:length(fns),
    fn = fns{i};
    if ~exist(fn,'var') || eval(sprintf('isempty(%s)',fn)),
      eval(sprintf('%s = rc.%s',fn,fn));
    end
  end
end

%% choose movie, etc if not input

if isempty(moviename),
  fprintf('Choose a movie to fix errors in\n');
  movieexts = {'*.fmf','*.sbfmf','*.ufmf','*.avi'}';
  helpmsg = 'Choose movie file for which to fix tracking errors';
  [moviename,moviepath] = uigetfilehelp(movieexts,'Choose movie file',moviename,'helpmsg',helpmsg);
  if isnumeric(moviename) && moviename == 0,
    return;
  end
  [movietag,movieext] = splitext(moviename);
else
  [moviepath,movietag,movieext] = fileparts(moviename);
  moviename = [movietag,movieext];
end

if isempty(matname),
  helpmsg = sprintf('Choose the mat file containing the trajectories corresponding to movie %s.',[moviepath,moviename]);
  matname = [moviepath,strrep(moviename,movieext,'.mat')];
  [matname,matpath] = uigetfilehelp({'*.mat'},'Choose mat file',matname,'helpmsg',helpmsg);
  if isnumeric(matname) && matname == 0,
    return;
  end
else
  [matpath,mattag,matext] = fileparts(matname);
  matname = [mattag,matext];
end

if isempty(annname),
  annname = [matpath,moviename,'.ann'];
  helpmsg = {};
  helpmsg{1} = 'Choose the Ctrax annotation file corresponding to:';
  helpmsg{2} = sprintf('Movie: %s',[moviepath,moviename]);
  helpmsg{3} = sprintf('Trajectory mat file: %s',[matpath,matname]);
  [annname,annpath] = uigetfilehelp({'*.ann'},'Choose ann file',annname,'helpmsg',helpmsg);
  if isnumeric(annname) && annname == 0,
    return;
  end
else
  [annpath,anntag,annext] = fileparts(annname);
  annname = [anntag,annext];
end
  
moviename = fullfile(moviepath,moviename);
matname = fullfile(matpath,matname);
annname = fullfile(annpath,annname);
  
[readframe,nframes,fid] = get_readframe_fcn(moviename);

try
  if exist('savedsettingsfile','file'),
    save('-append',savedsettingsfile,'moviename','moviepath');
  else
    save(savedsettingsfile,'moviename','moviepath');
  end
catch ME
  fprintf('Could not save to settings file %s -- not a big deal\n',savedsettingsfile);
  getReport(ME)
end

%% convert to px, seconds

if isempty(convertname),
  [convertsucceeded,convertmatname,trx] = ...
    convert_units_f('matname',matname,'moviename',moviename,'dosave',true);
else
  if exist(convertname,'file'),
    fprintf('Loading converted data from existing file %s\n',convertname);
    convertsucceeded = true;
    convertmatname = convertname;
  else
    [convertsucceeded,convertmatname,trx] = ...
      convert_units_f('matname',matname,'moviename',moviename,...
      'savename',convertname,'dosave',true);
  end
end
if ~convertsucceeded,
  return;
end
%matname = convertmatname;
[trx,matname,succeeded] = load_tracks(convertmatname,moviename);

%% see if we should restart

tag = movietag;
loadname = sprintf('tmpfixed_%s.mat',tag);
DORESTART = false;
  
if exist(loadname,'file'),
  tmp = dir(loadname);
  tmp2 = load(loadname,'matname','moviename');
  if isfield(tmp2,'moviename'),
    oldmoviename = tmp2.moviename;
  else
    oldmoviename = 'unknown movie';
  end
  if isfield(tmp2,'matname'),
    oldmatname = tmp2.matname;
  else
    oldmatname = 'unknown trx file';
  end
  prompt = {};
  prompt{1} = sprintf('A restart file saved by fixerrors was found with tag %s ',tag);
  prompt{2} = sprintf('Original movie: %s, selected movie %s. ',oldmoviename,moviename);
  prompt{3} = sprintf('Original trx file: %s, selected trx file %s. ',oldmatname,matname);
  prompt{4} = 'It is only recommended that you load these partial results if you are certain the trx files match. ';
  prompt{5} = 'Would you like to load the saved results and restart? ';

  button = questdlg(cell2mat(prompt),'Restart?');
  if strcmpi(button,'yes'),
    DORESTART = true;
  elseif strcmpi(button,'cancel'),
    return
  end
  
end

%% set parameters for detecting suspicious frames

if ~DORESTART,

[max_jump,maxmajor,meanmajor,arena_radius] = ...
  read_ann(annname,'max_jump','maxmajor','meanmajor','arena_radius');
meanmajor = meanmajor * 4;
maxmajor = maxmajor * 4;

px2mm = trx(1).pxpermm;
try
  save('-append',savedsettingsfile,'px2mm');
catch ME
  fprintf('Could not save to settings file %s -- not a big deal\n',savedsettingsfile);
  getReport(ME)
end

max_jump = max_jump / px2mm;
maxmajor = maxmajor / px2mm;
meanmajor = meanmajor / px2mm;

% set default values
if ~exist('minerrjump','var')
  minerrjump = .2*max_jump;
end
if ~exist('minorientchange','var'),
  minorientchange = 45;
end
if ~exist('largemajor','var'),
  largemajor = meanmajor + 2/3*(maxmajor-meanmajor);
end
if ~exist('minanglediff','var'),
  minanglediff = 90;
end
if ~exist('minwalkvel','var'),
  minwalkvel = 1 / 4;
end
if ~exist('matcherrclose','var'),
  matcherrclose = 10/4^2;
end
tmp = [minerrjump,minorientchange,largemajor,minanglediff,minwalkvel,matcherrclose];
defaultv = cell(size(tmp));
for i = 1:length(tmp),
  defaultv{i} = num2str(tmp(i));
end

shortdescr = cell(1,6);
descr = cell(1,6);
relev = cell(1,6);
shortdescr{1} = 'Minimum suspicious prediction-detection error (mm)';
descr{1} = ['All sequences in which the error between the constant velocity ',...
  'prediction and measured position is greater than the given value ',...
  'will be flagged. '];
relev{1} = sprintf('Max jump error: %.1f (mm)',max_jump);
shortdescr{2} = 'Minimum suspicious orientation change (deg)';
descr{2} = ['All sequences in which the change in orientation is greater ',...
  'than the given value will be flagged.'];
relev{2} = '';
shortdescr{3} = 'Minimum suspiciously large major axis (mm)';
descr{3} = ['All sequences in which the major axis length is greater than ',...
  'the given value will be flagged.'];
relev{3} = sprintf('Mean major axis length: %.2f mm, max major axis length: %.2f mm',meanmajor,maxmajor);
shortdescr{4} = 'Minimum suspicious orientation-velocity direction mismatch (deg): ';
descr{4} = '';
relev{4} = '';
shortdescr{5} = 'Minimum walking speed (mm/frame)';
descr{5} = ['All sequences in which the fly is walking (has speed greater than ',...
  'the given value) and the orientation and velocity differ by the given ',...
  'value will be flagged.'];
relev{5} = '';
shortdescr{6} = 'Maximum ambiguous error (mm^2)';
descr{6} = ['All sequences in which the increase in error for swapping ',...
  'a pair of identities is less than the given value will be flagged.'];
relev{6} = '';
prompts = cell(size(shortdescr));
for i = 1:length(shortdescr),
  prompts{i} = sprintf('**%s**: %s. ',shortdescr{i},descr{i});
  if ~isempty(relev{i}),
    prompts{i} = [prompts{i},sprintf('. [Relevant quantities: %s]',relev{i})];
  end
end
title1 = 'Suspiciousness Parameters';
tmp = inputdlg(prompts,title1,1,defaultv,'on');

if isempty(tmp),
  return;
end

minerrjump = str2double(tmp{1});
minorientchange = str2double(tmp{2});
largemajor = str2double(tmp{3});
minanglediff = str2double(tmp{4});
minwalkvel = str2double(tmp{5});
matcherrclose = str2double(tmp{6});

try
  save('-append',savedsettingsfile,...
    'minerrjump','minorientchange','largemajor','minanglediff',...
    'minwalkvel','matcherrclose');
catch ME
  fprintf('Could not save to settings file %s -- not a big deal\n',savedsettingsfile);
  getReport(ME)
end

end

%% convert to the units expected by suspicious_sequences

if ~DORESTART,

if isempty(suspiciousseqsname),
  suspiciousseqsname = fullfile(matpath,sprintf('suspiciousseqs_%s.mat',mattag));
end

minerrjumpfrac = minerrjump / max_jump;
minorientchange = minorientchange*pi/180;
maxmajorfrac = (largemajor - meanmajor)/(maxmajor - meanmajor);
minwalkvel = minwalkvel*px2mm;
matcherrclose = matcherrclose*px2mm^2;
minanglediff = minanglediff*pi/180;

ismatch = false;
fns = {'minerrjumpfrac','minorientchange',...
  'maxmajorfrac','minwalkvel',...
  'matcherrclose','minanglediff',...
  'matname','annname','moviename'};
if exist(suspiciousseqsname,'file'),
  tmp = load(suspiciousseqsname);
  ismatch = true;
  for i = 1:length(fns),
    fn = fns{i};
    if ~isfield(tmp,fn) || ...
        (ischar(tmp.(fn)) && ~eval(sprintf('strcmp(%s,tmp.%s)',fn,fn))) || ...
        (~ischar(tmp.(fn)) && eval(sprintf('%s ~= tmp.%s',fn,fn))),
      ismatch = false;
      break;
    end
  end
end
if ismatch,
  load(suspiciousseqsname,'seqs','trx0','params');
else
  [seqs,trx0,params] = suspicious_sequences(matname,annname,...
    'minerrjumpfrac',minerrjumpfrac,'minorientchange',minorientchange,...
    'maxmajorfrac',maxmajorfrac,'minwalkvel',minwalkvel,...
    'matcherrclose',matcherrclose,'minanglediff',minanglediff);
  save(suspiciousseqsname,'seqs','trx0','params',fns{:});
end

end

%% call the fixerrors gui

fprintf('Movie: %s\n',moviename);
fprintf('Mat: %s\n',matname);
fprintf('Annname: %s\n',annname);
fprintf('Temporary file created at: %s\n',loadname);

if ~DORESTART,
  trx = fixerrorsgui(seqs,moviename,trx0,annname,params,matname,loadname);
else
  realmatname = matname;
  load(loadname);
  if isfield(trx,'f2i'),
    trx = rmfield(trx,'f2i');
  end
  if ~isfield(trx,'off'),
    for i = 1:length(trx),
      trx(i).off = -trx(i).firstframe + 1;
    end
  end
  matname = realmatname;
  trx0 = trx;
  clear trx;
  trx = fixerrorsgui(seqs,moviename,trx0,annname,params,matname,loadname);
end

%% save

if isempty(savename),
  helpmsg = {};
  helpmsg{1} = 'Choose the mat file to which to save the fixed trajectories corresponding to:';
  helpmsg{2} = sprintf('Movie: %s',moviename);
  helpmsg{3} = sprintf('Trajectory mat file: %s',matname);
  helpmsg{4} = sprintf('Ctrax annotation file: %s',annname);
  
  [tmpmatpath,tmpmatname] = split_path_and_filename(matname);
  savename = [tmpmatpath,'fixed_',tmpmatname];
  [savename, savepath] = uiputfilehelp('*.mat', 'Save results?', savename,'helpmsg',helpmsg);
  if ischar(savename),
    savename = [savepath,savename];
  end
end
rmfns = intersect({'xpred','ypred','thetapred','dx','dy','v','f2i'},fieldnames(trx));
trx = rmfield(trx,rmfns);
isdeleted = isnan([trx.firstframe]);
trx(isdeleted) = [];
if ischar(savename),
  save(savename,'trx');
else
  tmpsavename = sprintf('backupfixed_movie%s.mat',tag);
  save(tmpsavename,'trx');
  msgbox(sprintf('saving trx to file %s\n',tmpsavename));
end

fclose(fid);
success = true;