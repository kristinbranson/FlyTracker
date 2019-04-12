
% Return the absolute path given an absolute or relative path.
function filename = absolute_path(filename)
   % break filename into parts
   [pathstr, name, ext] = fileparts(filename);
   % turn path into an absolute path
   if (~ismember(':',pathstr))
      indsep = find(pathstr == filesep, 1);
      if (isempty(indsep) || (indsep > 1))
         wd = cd;
         pathstr = fullfile(wd, pathstr);
      end
   end
   % reassemble path
   filename = fullfile(pathstr,[name ext]);
end