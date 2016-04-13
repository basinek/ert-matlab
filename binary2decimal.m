%% Unsigned binary to decimal converter
%  July 23 2015 by Kirsten Basinet
%  Paramters:    -bin_vector: Row vector containing binary number, where
%                 bin_vector(1) is the MSB
%  Returns:      -dec_result: Decimal representation of binary number,
%                 or NaN if an errror occurred
%  Notes:        -This function was created as an alternative to the
%                 vanilla MATLAB function bin2dec, which only accepts char
%                 strings 52 bits or less
%--------------------------------------------------------------------------
function dec_result = binary2decimal(bin_vector)
    dec_result = 0;
    for count = 0:1:length(bin_vector)-1
        if bin_vector(length(bin_vector)-count) == 1
            dec_result = dec_result+2^count;
        elseif bin_vector(length(bin_vector)-count) == 0
                %do nothing
        else
            dec_result = NaN; %error if bin_vector is not binary
        end %end: if bin_vector(length(bin_vector)-count) == 1
    end %end: for count = 0:1:length(bin_vector)-1
end %end: function binary2decimal