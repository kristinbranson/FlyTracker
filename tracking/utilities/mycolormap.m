
% Generate colormap that interpolates between
%  [0 0 1]   blue
%  [0 1 1]   cyan
%  [0 1 0]   green
%  [1 1 0]   yellow
%  [1 0 0]   red
%  [1 0 1]   magenta
%  [.5 0 1]  purple
function clrs = mycolormap(n)
    % initialize colors
    clrs = zeros(n,3);
    % color increment
    dc = min(6/(n-1),1);
    % dimensions to increment and factors to increment by
    dims = [2 3 1 2 3 1];
    fact = [1 -1 1 -1 1 -.5];
    % current color
    clr = [0 0 1];
    % current dimension
    idx = 1;
    % loop through n colors
    for i=1:n
        clrs(i,:) = clr;
        if i==n, break; end
        new_clr = clr;
        new_clr(dims(idx)) = new_clr(dims(idx))+fact(idx)*dc;
        if new_clr(dims(idx)) < 0 || new_clr(dims(idx)) > 1
            if new_clr(dims(idx)) < 0 
                tmp_dc = -new_clr(dims(idx));
                clr(dims(idx)) = 0;
            else
                tmp_dc = new_clr(dims(idx))-1;
                clr(dims(idx)) = 1;
            end
            idx = idx+1;
            clr(dims(idx)) = clr(dims(idx))+fact(idx)*tmp_dc;
        else
            clr = new_clr;
        end
    end
end