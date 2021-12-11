% script that prompts user for mat, annotation, and movie files, parameters
% for computing suspicious frames, then computes suspicious frames, then
% brings up the labelerrors gui

%% set all defaults

moviename = '';
moviepath = '';
setuppath;

%% read last settings
pathtolabelerrors = which('labelerrors');
savedsettingsfile = strrep(pathtolabelerrors,'labelerrors.m','.labelerrorsrc.mat');
if exist(savedsettingsfile,'file')
  load(savedsettingsfile);
end

%% choose movie

fprintf('Choose a movie to fix errors in\n');
movieexts = {'*.fmf','*.sbfmf','*.avi'}';
helpmsg = 'Choose movie file for which to fix tracking errors';
[moviename,moviepath] = uigetfilehelp(movieexts,'Choose movie file',moviename,'helpmsg',helpmsg);
if isnumeric(moviename) && moviename == 0, 
  return;
end
[movietag,movieext] = splitext(moviename);

helpmsg = sprintf('Choose the mat file containing the trajectories corresponding to movie %s.',[moviepath,moviename]);
matname = [moviepath,strrep(moviename,movieext,'.mat')];
[matname,matpath] = uigetfilehelp({'*.mat'},'Choose mat file',matname,'helpmsg',helpmsg);
if isnumeric(matname) && matname == 0, 
  return;
end

annname = [matpath,moviename,'.ann'];
helpmsg = {};
helpmsg{1} = 'Choose the Ctrax annotation file corresponding to:';
helpmsg{2} = sprintf('Movie: %s',[moviepath,moviename]);
helpmsg{3} = sprintf('Trajectory mat file: %s',[matpath,matname]);
[annname,annpath] = uigetfilehelp({'*.ann'},'Choose ann file',annname,'helpmsg',helpmsg);
if isnumeric(annname) && annname == 0,
  return;
end

moviename = [moviepath,moviename];
matname = [matpath,matname];
annname = [annpath,annname];

[readframe,nframes,fid] = get_readframe_fcn(moviename);

if exist('savedsettingsfile','file'),
  save('-append',savedsettingsfile,'moviename','moviepath');
else
  save(savedsettingsfile,'moviename','moviepath');
end

%% convert to px, seconds

[matpathtmp,matnametmp] = split_path_and_filename(matname);
%[convertsucceeded,convertmatname] = convert_units_f('matname',matnametmp,'matpath',matpathtmp,'moviename',moviename);
%if ~convertsucceeded,
%  return;
%end
convertmatname = matname;
convertsucceeded = true;
[trx,matname,succeeded] = load_tracks(convertmatname);

%% see if we should restart

tag = movietag;
loadname = sprintf('tmplabel_%s.mat',tag);
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
  prompt{1} = sprintf('A restart file saved by labelerrors was found with tag %s ',tag);
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
save('-append',savedsettingsfile,'px2mm');

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

save('-append',savedsettingsfile,...
  'minerrjump','minorientchange','largemajor','minanglediff',...
  'minwalkvel','matcherrclose');

end

%% convert to the units expected by suspicious_sequences

if ~DORESTART,

minerrjumpfrac = minerrjump / max_jump;
minorientchange = minorientchange*pi/180;
maxmajorfrac = (largemajor - meanmajor)/(maxmajor - meanmajor);
minwalkvel = minwalkvel*px2mm;
matcherrclose = matcherrclose*px2mm^2;
minanglediff = minanglediff*pi/180;
[seqs,trx0,params] = suspicious_sequences(matname,annname,...
  'minerrjumpfrac',minerrjumpfrac,'minorientchange',minorientchange,...
  'maxmajorfrac',maxmajorfrac,'minwalkvel',minwalkvel,...
  'matcherrclose',matcherrclose,'minanglediff',minanglediff);

end

%% call the labelerrors gui

fprintf('Movie: %s\n',moviename);
fprintf('Mat: %s\n',matname);
fprintf('Annname: %s\n',annname);
fprintf('Temporary file created at: %s\n',loadname);

if ~DORESTART,
  [terror0,terror1,flyerror] = labelerrorsgui(seqs,moviename,trx0,annname,params,matname,loadname);
else
  realmatname = matname;
  load(loadname);
  matname = realmatname;
  if isfield(trx,'f2i'),
    trx = rmfield(trx,'f2i');
  end
  if ~isfield(trx,'off'),
    for i = 1:length(trx),
      trx(i).off = -trx(i).firstframe + 1;
    end
  end
  trx0 = trx;
  clear trx;
  trx = labelerrorsgui(seqs,moviename,trx0,annname,params,matname,loadname);
end

%% save

while true,
  helpmsg = {};
  helpmsg{1} = 'Choose the mat file to which to save the fixed trajectories corresponding to:';
  helpmsg{2} = sprintf('Movie: %s',moviename);
  helpmsg{3} = sprintf('Trajectory mat file: %s',matname);
  helpmsg{4} = sprintf('Ctrax annotation file: %s',annname);

  [tmpmatpath,tmpmatname] = split_path_and_filename(matname);
  savename = [tmpmatpath,'fixed_',tmpmatname];
  [savename, savepath] = uiputfilehelp('*.mat', 'Save results?', savename,'helpmsg',helpmsg);
  if isnumeric(savename) && savename == 0,
    fprintf('missed\n');
  else
    break;
  end
end
savename = [savepath,savename];
rmfns = intersect({'xpred','ypred','thetapred','dx','dy','v','f2i'},fieldnames(trx));
trx = rmfield(trx,rmfns);
if ~isempty(savename),
  save(savename,'trx');
else
  tmpsavename = sprintf('backupfixed_movie%s.mat',tag);
  save(tmpsavename,'trx');
  msgbox(sprintf('saving trx to file %s\n',tmpsavename));
end
