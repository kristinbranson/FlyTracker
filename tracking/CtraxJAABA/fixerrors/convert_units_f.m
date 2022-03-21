function [succeeded,savename,trx] = convert_units_f(varargin)

setuppath;

fps = 20;
pxpermm = 4;
% parse inputs
[matname,matpath,moviename,ISAUTOMATIC,trx,savename,dosave,readframe_fcn] = ...
  myparse(varargin,'matname',nan,'matpath',nan,'moviename',nan,'isautomatic',false,...
  'trx',[],'savename','','dosave',true,'readframe_fcn',[]);

if ~dosave,
  savename = -1;
end

succeeded = false;
ISTRX = ~isempty(trx);
ISMATNAME = ischar(matname);
ISMATPATH = ischar(matpath);
if ISMATNAME && ~ISMATPATH,
  matpath = '';
  ISMATNAME = true;
end
ISMOVIENAME = ischar(moviename);
if ~ISMATNAME,
  matname = '';
  matpath = '';
end
if ~ISMOVIENAME,
  moviename = '';
end

% load settings
pathtoconvertunits = which('convert_units_f');
savedsettingsfile = strrep(pathtoconvertunits,'convert_units_f.m','.convertunitsrc.mat');
if exist(savedsettingsfile,'file')
  if ISMATNAME,
    load(savedsettingsfile,'pxpermm','fps');
  else
    load(savedsettingsfile);
  end
end

% get the mat file

if ISTRX,
  if ~ISMATNAME,
    if isfield(trx,'matname'),
      [matpath,matname] = split_path_and_filename(trx(1).matname);
      if dosave && isempty(savename),
        savename = trx(1).matname;
      end
    else
      matname = '';
      matpath = '';
      if dosave && isempty(savename),
        savename = '';
      end
    end
  end
  matname0 = matname;
else
  if ~ISMATNAME,
  
    matname = [matpath,matname];
    helpmsg = 'Choose a mat file containing trajectories for which to set the pixel to mm and frame to second conversions';
    [matname,matpath] = uigetfilehelp('*.mat','Choose mat file for which to convert units',matname,'helpmsg',helpmsg);
    if isnumeric(matname) && matname == 0,
      return;
    end
    fprintf('Matfile: %s%s\n\n',matpath,matname);
    
    try
      if exist(savedsettingsfile,'file'),
        save('-append',savedsettingsfile,'matname','matpath');
      else
        save(savedsettingsfile,'matname','matpath');
      end
    catch ME,
      fprintf('Could not save to settings file %s, not a big deal\n',savedsettingsfile);
      getReport(ME)
    end
    
  end

  matname0 = matname;
  matname = [matpath,matname];
  if dosave && isempty(savename),
    savename = matname;
  end
end

%% read in the movie
inputmatname = matname;
if ~ISTRX,
  [trx,matname,loadsucceeded] = load_tracks(matname, moviename );
  if ~loadsucceeded,
    msgbox(sprintf('Could not load trx mat file %s',matname));
  end
end

% check to see if it has already been converted
alreadyconverted = isfield(trx,'pxpermm') && isfield(trx,'fps');
if alreadyconverted,
  pxpermm = trx(1).pxpermm;
  fps = trx(1).fps;
  fprintf('pxpermm = %f, fps = %f\n',pxpermm,fps);
end

%% convert from frames to seconds

if ~alreadyconverted,
  
  if isfield(trx,'timestamps'),
    
    [firstframe,firstfly] = min([trx.firstframe]);
    [lastframe,lastfly] = max([trx.endframe]);
    fps = (lastframe-firstframe) / (trx(lastfly).timestamps(end)-trx(firstfly).timestamps(1));
    prompts = {'Frames per second (calculated from timestamps):'};
    
  else

    prompts = {'Frames per second:'};
    
  end
  
  while true,
    b = {num2str(fps)};
    b = inputdlg(prompts,'Convert frames to seconds',1,b);
    if isempty(b), return; end
    fpstmp = str2double(b{1});
    if isnan(fpstmp) || fpstmp <= 0,
      fprintf('Illegal value for frames per second -- must be a positive number.\n');
      continue;
    end
    fps = fpstmp;
    break;
  end
  
  try
    if ~exist(savedsettingsfile,'file'),
      save(savedsettingsfile,'fps');
    else
      save('-append',savedsettingsfile,'fps');
    end
  catch ME,
    fprintf('Could not save to settings file %s, not a big deal\n',savedsettingsfile);
    getReport(ME)
  end
  
end

%% convert from px to mm

if ~alreadyconverted,

  b = questdlg('Enter pixels per mm manually, or compute from landmarks','Pixels to mm','Manual','Compute','Manual');
  if strcmpi(b,'manual'),
    
    % compute the mean major axis length
    meanmaj = mean([trx.a])*4;
    b = {num2str(pxpermm)};
    prompts = {sprintf('Pixels per mm [mean fly length = %.1f px]',meanmaj)};
    
    while true,
      tmp = inputdlg(prompts,'Pixels per mm',1,b);
      if isempty(tmp),
        return;
      end
      ppmtmp = str2double(tmp{1});
      if isnan(ppmtmp) || ppmtmp <= 0,
        fprintf('Illegal value for pixels per mm -- must be a positive number.\n');
      continue;
      end
      pxpermm = ppmtmp;
      break;
    end
    
  else
    
    % get moviename
    
    if ~ISMOVIENAME,
      
      moviename = '';
      if isfield(trx,'moviename'),
        moviename = trx(1).moviename;
      end
      if isempty(moviename) || ~exist(moviename,'file'),
        moviename = strrep(inputmatname,'.mat','.fmf');
        if ~exist(moviename,'file'),
          moviename = strrep(inputmatname,'.mat','.sbfmf');
          if ~exist(moviename,'file'),
            moviename = strrep(inputmatname,'.mat','.avi');
            if ~exist(moviename,'file'),
              moviename = matpath;
            end
          end
        end
      end
      helpmsg = sprintf('Choose the movie corresponding to the mat file %s. We will use a frame from this movie to set landmark locations.',inputmatname);
      [moviename,moviepath] = uigetfilehelp({'*.fmf','*.sbfmf','*.avi'}',...
        sprintf('Choose movie corresponding to %s',matname0),moviename,'helpmsg',helpmsg);
      moviename = [moviepath,moviename];
      
    end
    
    % plot one image
    if isempty( readframe_fcn )
       [readframe,nframes,fid] = get_readframe_fcn(moviename);
    else
       readframe = readframe_fcn.readframe;
       nframes = readframe_fcn.nframes;
       fid = readframe_fcn.fid;
    end
    im = readframe(round(nframes/2));
    figure(1); clf; imagesc(im); axis image; colormap gray; hax = gca; hold on;
    
    % make a draggable line
    title('Click to set endpoints of line.');
    fprintf('Draw a line on Figure 1\n');
    % allow users who don't have imline (image processing toolbox)
    if exist('imline','file'),
      try
        hline = imline(hax);
      catch
        % seems that in some releases imline does not accept just one input
        [position,hline] = get2ptline(hax);
        delete(hline);
        hline = imline(hax,position(:,1),position(:,2));
      end
      title({'Drag around line to set landmark distance in pixels.','Double-click on line when done.'});
      position = wait(hline);
    else
      title('Click on two landmarks which you know the distance between');
      [position,hline] = get2ptline(hax);
    end
    
    d = sqrt(sum(diff(position).^2));
    delete(hline);
    plot(position(:,1),position(:,2),'r.-');
    b = {''};
    prompts = {sprintf('Length of this line in mm [ = %.1f px]',d)};
    
    while true,
      tmp = inputdlg(prompts,'Line length',1,b);
      if isempty(tmp),
         close( 1 )
        return;
      end
      mmtmp = str2double(tmp{1});
      if isnan(mmtmp) || mmtmp <= 0,
        fprintf('Illegal value for line length -- must be a positive number.\n');
        continue;
      end
      mm = mmtmp;
      break;
    end
    
    pxpermm = d / mm;
    fprintf('Pixels per mm set to %f\n',pxpermm);
    
    if ishandle(1), delete(1); end
  end
  
  try
    save('-append',savedsettingsfile,'pxpermm');
  catch ME,
    fprintf('Could not save to settings file %s, not a big deal\n',savedsettingsfile);
    getReport(ME)
  end
  
end

%% actually do the conversion now

[trx, didsomething] = apply_convert_units(trx,pxpermm,fps, alreadyconverted );

%% save to file

if dosave && (~alreadyconverted || didsomething),
  
  if isempty(savename),
    nmissed = 0;
    while true,
      helpmsg = sprintf('Choose the file to which to save the trx from %s augmented with the pixel to mm and frame to second conversions',inputmatname);
      [savename, savepath] = uiputfilehelp('*.mat', sprintf('Save results for input %s to',matname0), savename,'helpmsg',helpmsg);
      if ~isnumeric(savename),
        break;
      end
      fprintf('missed\n');
      nmissed = nmissed + 1;
      if nmissed > 1,
        return;
      end
      savename = inputmatname;
    end
    savename = [savepath,savename];
  end
  
  for i = 1:length(trx),
    trx(i).matname = savename;
  end
  
  if strcmpi(inputmatname,savename),
    tmpname = tempname;
    fprintf('Overwriting %s with converted data...\n',savename);
    movefile(inputmatname,tmpname);
    didsave = save_tracks(trx,savename,'doappend',true);
    if ~didsave,
      fprintf('Aborting overwriting\n');
      movefile(tmpname,matname);
      return;
    end
    delete(tmpname);
  else
    fprintf('Saving converted data to file %s.\nUse this mat file instead of %s in the future\n',savename,inputmatname);
    try
       copyfile(inputmatname,savename);
    catch le
       if strcmp( le.identifier, 'MATLAB:COPYFILE:OSError' )
          % this can happen if there's a symlink somewhere in the path, so don't puke
          warning( le.message )
       else
          disp( le.identifier )
          rethrow( le )          
       end
    end
    didsave = save_tracks(trx,savename,'doappend',true);
    if ~didsave,
      return;
    end
  end
end
succeeded = true;
