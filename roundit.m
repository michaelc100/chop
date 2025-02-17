function [y,options] = roundit(x,options)
%ROUNDIT   Round a matrix to integer entries, with various options.
%   y = ROUNDIT(X,p,options) rounds the matrix X to have integer
%   entries, as specified by options.round:
%     1: round to nearest integer using round to even to break ties
%        (the default),
%     2: round towards plus infinity (round up),
%     3: round towards minus infinity (round down,
%     4: round towards zero,
%     5: stochastic rounding - round to the next larger or next smaller
%        integer with probability equal to 1 minus the distance to 
%        those integers,
%     6: stochastic rounding - round to the next larger or next smaller
%        integer with equal probahility.
%   For stochastic rounding, exact integers are not changed.
%   If options.flip = 1 (default 0) then each element of the rounded result 
%   has, with probability options.p (default 0.5), a randomly chosen bit
%   (in its binary representation) flipped. 
%   The integers are assumed to have moduli on the interval [0,2^options.t-1],
%   which defines the range of bits in their binary representation.
%   Modifications by MPC 08/07/19:
%   - Adding capability to SR so that can use any 
%     precision in the rounding/accumulation


if nargin < 2 || isempty(options) 
    options.round = 1; options.flip = 0; options.p = 0.5;
end    
if ~isfield(options,'round'), options.round = 1; end
if ~isfield(options,'flip'), options.flip = 0; end
if ~isfield(options,'p'), options.p = 0.5; end
if ~isfield(options, 'accum'), options.accum = 0; end
if ~isfield(options, 'aparams'), options.aparams = 0; end

mysign = @(x) sign(x) + (x==0); % mysign(0) = 1;

switch options.round
  
  case 1
    y = abs(x);
    % Built-in ROUND function rounds ties away from zero.
    % Round to nearest integer using round to even to break ties.
    u = round(y - (rem(y,2) == 0.5));
    u(find(u == -1)) = 0; % Special case, negative argument to ROUND.
    y = sign(x).*u; 

  case 2
    % Round towards plus infinity.
    y = ceil(x); 

  case 3
    % Round towards minus infinity.
    y = floor(x); 

  case 4
    % Round towards zero.
    if x >= 0, y = floor(x); else y = ceil(x); end

  case {5, 6}

    % Stochastic rounding.
    if options.accum
        %We have a target precision to accumulate to
        % Want to round frac to that, as well as all generated rands
        fp.format = options.accum;
        if options.aparams
            fp.params = options.aparams;
        end
        
        y = abs(x); 
        frac = chop(y - floor(y), fp);
        k = find(frac ~= 0);
        if isempty(k)
            y = x; 
        else   
            rnd = chop(rand(length(k),1), fp);
            vals = frac(k);  vals = vals(:);

            switch options.round
              case 5 % Round up or down with probability prop. to distance.
                j = (rnd <= vals);
              case 6 % Round up or down with equal probability.       
                j = (rnd <= 0.5);
            end      
            y(k(j)) = ceil(y(k(j)));
            y(k(~j)) = floor(y(k(~j)));
            y = mysign(x).*y; 
        end
        
    else
        %Accum to double (de facto inf) precision
        y = abs(x); 
        frac = y - floor(y);
        k = find(frac ~= 0);
        if isempty(k)
            y = x; 
        else   
            rnd = rand(length(k),1);
            vals = frac(k);  vals = vals(:);

            switch options.round
              case 5 % Round up or down with probability prop. to distance.
                j = (rnd <= vals);
              case 6 % Round up or down with equal probability.       
                j = (rnd <= 0.5);
            end      
            y(k(j)) = ceil(y(k(j)));
            y(k(~j)) = floor(y(k(~j)));
            y = mysign(x).*y; 
        end        
   end   
   
  otherwise
    error('Unsupported value of options.round.')  
               
end

if options.flip
    
   temp = rand(size(y));
   k = find(temp <= options.p); % Indices of elements to have a bit flipped.
   if ~isempty(k)
      u = abs(y(k));
      % Random bit flip in significand.
      % b defines which bit (1 to p-1) to flip in each element of y.
      b = randi(options.t-1,length(k),1);
      % Flip selected bits.
      u = bitxor(u,2.^(b-1));
      y(k) = mysign(y(k)).*u; 
   end

end