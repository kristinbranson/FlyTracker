function [parent, name] = fileparts2(path) 
    [parent, base, ext] = fileparts(path) ;
    name = horzcat(base, ext) ;
end
