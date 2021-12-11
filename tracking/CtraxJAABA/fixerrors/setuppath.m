% set up the paths

isdone = ~isempty(which('ctrax_matlab_misc_check')) &&  ~isempty(which('ctrax_matlab_filehandling_check'));
if isdone, return; end

dirnamestry = {'.','../matlab','..','matlab','../Ctrax/matlab'};

% try last saved location
rcfile = which('setuppath');
rcfile = strrep(rcfile,'setuppath.m','.setuppathrc.mat');
if exist(rcfile,'file')
  load(rcfile);
  dirnamestry{1} = dirname;
end

for i = 1:length(dirnamestry),
  dirname = dirnamestry{i};
  if exist(dirname,'dir') && exist([dirname,'/filehandling'],'dir') && ...
        exist([dirname,'/misc'],'dir') && ...
        exist([dirname,'/filehandling/get_readframe_fcn.m'],'file'),
    p = genpath(dirname);
    % remove svn
    delimiter = pathsep;
    tmp = textscan(p,'%s','delimiter',delimiter);
    tmp = tmp{1};
    matches = strfind(tmp,'.svn');
    keep = cellfun(@isempty,matches);
    tmp(~keep) = [];
    p1 = sprintf(['%s',delimiter],tmp{:});
    addpath(p1);
  end
  isdone = ~isempty(which('ctrax_matlab_misc_check')) &&  ~isempty(which('ctrax_matlab_filehandling_check'));
  if isdone, 
    fprintf('Found Ctrax/matlab at %s\n',dirname);
    save(rcfile,'dirname');
    break
  end
end

global CTRAXFIXERRORSSETUPPATHHASBEENCALLED;
if isempty(CTRAXFIXERRORSSETUPPATHHASBEENCALLED) || ~CTRAXFIXERRORSSETUPPATHHASBEENCALLED,
  fprintf('\n\n\n\n********************************************************\n');
  fprintf('         The Ctrax FixErrors Matlab Toolbox\n\n');
  fprintf('     (c) The Caltech Ethomics Project 2009-2012\n');
  fprintf('            http://ctrax.sourceforge.net\n');
  fprintf('             bransonk@janelia.hhmi.org\n\n');
  fprintf('Documentation and up-to-date versions of the software\n');
  fprintf('are available on our project homepage:\n\n');
  fprintf('              http://ctrax.sourceforge.net\n\n');
  if ~isempty( which( 'version_ctrax' ) )
     fprintf('       Your version of this toolbox is %s.\n', version_ctrax() );
  end
  fprintf('*********************************************************\n\n\n\n');
  CTRAXFIXERRORSSETUPPATHHASBEENCALLED = true;
end

if isdone, return; end

dirname = dirnamestry{1};

% ask for help
fprintf('Where is the "matlab" directory of your Ctrax code?\n');
dirname = uigetdir(dirname,'Select Ctrax/matlab');
if isnumeric(dirname) && dirname == 0,
  error('Error setting up path.');
  return;
end
p = genpath(dirname);
% remove svn
tmp = textscan(p,'%s','delimiter',':');
tmp = tmp{1};
matches = strfind(tmp,'.svn');
keep = cellfun(@isempty,matches);
tmp(~keep) = [];
p1 = sprintf('%s:',tmp{:});
addpath(p1);
if isempty(which('get_readframe_fcn'))
  error('Error setting up path.\n');
end
