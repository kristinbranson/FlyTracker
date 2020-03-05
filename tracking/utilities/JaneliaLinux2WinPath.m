function outpath = JaneliaLinux2WinPath(inpath,varargin)

if ~ispc,
  warning('Converting to windows path on a non-PC...');
end

if iscell(inpath),
  outpath = cell(size(inpath));
  for i = 1:numel(inpath),
    outpath{i} = JaneliaLinux2WinPath(inpath{i},varargin{:});
  end
  return;
end
outpath = inpath;
outpath = regexprep(outpath,'^[\\/]groups[\\/]([^\\/]*)[\\/](??$1)lab','\\\\dm11\\$1');
outpath = regexprep(outpath,'^[\\/]groups[\\/]([^\\/]*)[\\/]home','\\\\dm11\\$1\$');
outpath = regexprep(outpath,'^[\\/]nearline[\\/]([^\\/]*)','\\\\nearline4.hhmi.org\\$1\$');
outpath = strrep(outpath,'/','\');
