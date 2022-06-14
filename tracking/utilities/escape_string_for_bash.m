function result = escape_string_for_bash(str)
    sq = '''' ;  % a single quote
    sq_bs_sq_sq = '''\''''' ; % single quote, backslash, single quote, single quote
    str_escaped = strrep(str, sq, sq_bs_sq_sq) ;  % replace ' with '\''
    result = horzcat(sq, str_escaped, sq) ;  % Surround with single quotes to handle all special chars besides single quote
end
