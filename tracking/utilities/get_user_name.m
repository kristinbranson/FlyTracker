function name = get_user_name()
    % GETCOMPUTERNAME returns the name of the computer (hostname)
    % name = getComputerName()
    %
    % WARN: output string is converted to lower case
    %
    %
    % See also SYSTEM, GETENV, ISPC, ISUNIX
    %
    % m j m a r i n j (AT) y a h o o (DOT) e s
    % (c) MJMJ/2007
    % MOD: MJMJ/2013

    if ispc()
        name = getenv('username') ;  % works on windows, may need to mod to work on Linux, MacOS
    else
        name = getenv('USER') ;  % works on windows, may need to mod to work on Linux, MacOS
    end        
end
