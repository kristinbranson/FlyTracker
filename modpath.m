function modpath()
    this_file_path = mfilename('fullpath') ;
    this_folder_path = fileparts(this_file_path) ;
    addpath(degit(genpath(this_folder_path))) ;
end


function path_no_git=degit(path_raw)
    % eliminate .git directories from a path string
    path_raw_as_array=split_path(path_raw);
    path_no_git_as_array=cell(0,1);
    for i=1:length(path_raw_as_array)
        k=strfind(path_raw_as_array{i},'.git');
        if isempty(k)
            path_no_git_as_array{end+1}=path_raw_as_array{i};  %#ok
        end
    end
    path_no_git=combine_path(path_no_git_as_array);
end


function path_as_array=split_path(path)
    % split a path on pathsep into a cell array of single dir names
    i_pathsep=strfind(path,pathsep);
    n=length(i_pathsep)+1;
    path_as_array=cell(n,1);
    if n>0
        if n==1
            path_as_array{1}=path;
        else
            % if here, n>=2
            path_as_array{1}=path(1:i_pathsep(1)-1);
            for i=2:(n-1)
                path_as_array{i}=path(i_pathsep(i-1):i_pathsep(i)-1);
            end
            path_as_array{n}=path(i_pathsep(n-1)+1:end);
        end
    end
end


function path=combine_path(path_as_array)
    % combine a cell array of dir names into a single path string
    n=length(path_as_array);
    if n>0
        path=path_as_array{1};
        for i=2:n
            path=[path pathsep path_as_array{i}];  %#ok
        end
    end
end
