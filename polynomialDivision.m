%% Unsigned polynomial division function
%  July 27 2015 by Kirsten Basinet
%  Parameters:   -divisor: Row vector containing descending polynomial
%                 coefficients
%                -dividend: Row vector containing descending codeword
%                 coefficients
%  Returns:      -quotient: Row vector containing descending quotient
%                 coefficients, or NaN if an error occurred
%                -remainder: Row vector contianing remainder
%  Dependencies: -Requires the custom function binary2decimal. MATLAB
%                 native functions bin2dec and num2str can be used if 
%                 dividing small polynomials. bi2de can be used if the
%                 user has the communications systems toolbox.
%  Notes:        -The function may need more debugging for cases where
%                 divisor>dividend, negative numbers are included, and
%                 other possible inputs. Works for CRC applications.
%--------------------------------------------------------------------------
function [remainder,quotient] = polynomialDivision(divisor,dividend)
    %Initialize variables
    clear place_count;
    clear remainder;
    quotient=[];

    %Remove leading zeros
    dividend = dividend(find(dividend,1,'first'):numel(dividend));
    divisor = divisor(find(divisor,1,'first'):numel(divisor));
    place_count = numel(divisor);
    temp_dividend = dividend(1:place_count);
    dividing = true;

    %Perform polynomial division
    while dividing
        if temp_dividend(1) == 1 %Use XOR method of polynomial division
            quotient = [quotient,1];
            temp_dividend = bitxor(temp_dividend,divisor);
        elseif temp_dividend(1) == 0
            quotient = [quotient,0];
        else
            %Non-binary number or NaN
            remainder = NaN; %Error
            quotient = NaN; %Error
            dividing = false; %Done  
        end %end: if temp_dividend(1) == 1;
        place_count = place_count+1;
   
        if place_count > numel(dividend)
            %Remove leading zeros and set remainder
            remainder = temp_dividend(find(temp_dividend,1,'first'):numel(temp_dividend));
            if isempty(remainder)
                remainder = 0;
            else
                %Do nothing
            end %end: if isempty(remainder)
            dividing = false; %Done
        else
            temp_dividend = [temp_dividend(2:numel(temp_dividend)),dividend(place_count)];
        end %end: if place_count > numel(dividend)
    end %end: while dividing
end %end: function polynomialDivision
