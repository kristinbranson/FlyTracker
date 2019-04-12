function ndx = sub2ind_faster(siz,varargin)
%SUB2IND Linear index from multiple subscripts.
%   SUB2IND is used to determine the equivalent single index
%   corresponding to a given set of subscript values.
%
%   IND = SUB2IND(SIZ,I,J) returns the linear index equivalent to the
%   row and column subscripts in the arrays I and J for a matrix of
%   size SIZ. 
%
%   IND = SUB2IND(SIZ,I1,I2,...,IN) returns the linear index
%   equivalent to the N subscripts in the arrays I1,I2,...,IN for an
%   array of size SIZ.
%
%   I1,I2,...,IN must have the same size, and IND will have the same size
%   as I1,I2,...,IN. For an array A, if IND = SUB2IND(SIZE(A),I1,...,IN)),
%   then A(IND(k))=A(I1(k),...,IN(k)) for all k.
%
%   Class support for inputs I,J: 
%      float: double, single
%      integer: uint8, int8, uint16, int16, uint32, int32, uint64, int64
%
%   See also IND2SUB.

%   Copyright 1984-2013 The MathWorks, Inc.

siz = double(siz);
lensiz = length(siz);
if lensiz < 2
    error(message('MATLAB:sub2ind:InvalidSize'));
end

numOfIndInput = nargin-1;
if lensiz < numOfIndInput
    %Adjust for trailing singleton dimensions
    siz = [siz, ones(1,numOfIndInput-lensiz)];
elseif lensiz > numOfIndInput
    %Adjust for linear indexing on last element
    siz = [siz(1:numOfIndInput-1), prod(siz(numOfIndInput:end))];
end

if numOfIndInput == 2
    
    v1 = varargin{1};
    v2 = varargin{2};
% This takes up 75% of the runtime
%     if ~isequal(size(v1),size(v2))
%         %Verify sizes of subscripts
%         error(message('MATLAB:sub2ind:SubscriptVectorSize'));
%     end
%     if any(v1(:) < 1) || any(v1(:) > siz(1)) || ...
%        any(v2(:) < 1) || any(v2(:) > siz(2))
%         %Verify subscripts are within range
%         error(message('MATLAB:sub2ind:IndexOutOfRange'));
%     end
    %Compute linear indices
    ndx = double(v1) + (double(v2) - 1).*siz(1);
    
else
    
    %Compute linear indices
    k = [1 cumprod(siz(1:end-1))];
    ndx = 1;
    s = size(varargin{1}); %For size comparison
    for i = 1:numOfIndInput
        v = varargin{i};
        %%Input checking
        if ~isequal(s,size(v))
            %Verify sizes of subscripts
            error(message('MATLAB:sub2ind:SubscriptVectorSize'));
        end
        if (any(v(:) < 1)) || (any(v(:) > siz(i)))
            %Verify subscripts are within range
            error(message('MATLAB:sub2ind:IndexOutOfRange'));
        end
        ndx = ndx + (double(v)-1)*k(i);
    end
    
end
