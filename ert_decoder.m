%% Decoder for ERT standard v1.0
%  A.G. Klein and N. Conroy and K. Basinet
%  Description:  -Decodes ERT gas meter data from .bin file and displays
%                 meter ID, meter type, physical tamper flag, encoder tamper flag,
%                 consumption value, and the elapsed time since the last loop.
%  Dependencies: -Requires custom functions binary2decimal and
%                 polynomialDivision
%  ------------------------------------------------------------------------
%% Revision history:
%  22-feb-2015 v0.1 -initial version
%  22-feb-2015 v0.2 -updated to run on Nick's sample code
%  03-mar-2015 mod2 -added ert_out for message decoding -NC
%  13-mar-2015 mod3 -first attempt at cumsum detector -NC
%  21-mar-2015 mod4 -second attempt at cumsum detector -NC
%  22-mar-2015 mod5 -succesful cumsum detector, integrated ert_out func. -NC
%  23-mar-2015 mod6 -detector optimization test -NC
%  23-mar-2015 mod7 -more detector optimization tests -NC
%  24-mar-2015 mod8 -conversion to fully vector operations
%                   -optimized checksum operation           -NC
%  24-mar-2015 mod9 -first attempt at real time decoding with RTL-SDR -NC
%  10-jul-2015 v1.0 -new version that reads ERT data from .bin file -KB
%  15-jul-2015 mod1 -some packets being dropped, some invalid packets detected
%                   -BCH processing disabled -KB
%  29-jul-2015 mod2 -new function successfully checks BCH -KB
%                   -fixed error in preamble check, all detected packets
%                    are valid -KB
%  03-aug-2015 mod3 -still attempting to detect packets that are split between
%                    data blocks -KB
%  04-aug-2015 mod4 -all packets get decoded successfully, but some multiple
%                    times -KB
%  29-nov-2015 mod5 -revised comments and added ability to switch between
%                    data from .bin file and RTL-SDR Note: All RTL-SDR
%                    functionality was written by NC -KB
%--------------------------------------------------------------------------
clear;
%% Parameters and constants
JMP=30;                            % Number of samples to jump over each iteration 
DataRate=16384;                    % Data rate for determining symbol period
SMPRT=2392064;                     % RTL-SDR Sample Rate
BLOCKSIZE=18688;                   % RTL-SDR Samples per frame
SP=int16(SMPRT/DataRate);          % Nominal symbol period (in # of samples)
BCH_POLY=[1,0,1,1,0,1,1,1,1,0,1,1,0,0,0,1,1]; % BCH generator polynomial coefficients from ERT standard
PREAMBLE=[1;1;1;1;1;0;0;1;0;1;0;1;0;0;1;1;0;0;0;0;0];  %Preamble from ERT standard, includes sync bit.
FILEMODE = 1; %0 to use data from RTL-SDR, 1 to use data from .bin file
fname='rtlamr_log_2-20-2015.bin';  % Raw data file name

if FILEMODE == 0
	%RTL-SDR setup
	hSDR = comm.SDRRTLReceiver('0', 'CenterFrequency', 920299072, ...
	       'SampleRate', SMPRT, 'SamplesPerFrame', BLOCKSIZE,'EnableTunerAGC', true);
	%Setup Checksum parameters
	  n = 255;
	  k = 239;
	  [gp,t] = bchgenpoly(n,k);

	 hDec = comm.BCHDecoder('CodewordLength', n, 'MessageLength', k, ...
	  'GeneratorPolynomialSource', 'Property', 'GeneratorPolynomial', gp);
else
	% Load .bin file
	fid=fopen(fname);
	dat=fread(fid,'uint8=>double'); %Read UINT8 data into double precision vector
	dat=dat-127;
	s=dat(1:2:end)+1j*dat(2:2:end);
	fclose(fid);
end %end: if FILMEODE == 0

%% Preallocate buffer space
zbuff = zeros(BLOCKSIZE,1);
softbits = zeros(96,1);
bits = zeros(96,1);
cnt = 0; %Decoded message counter
block_index = 1;
while block_index < numel(s)-BLOCKSIZE+JMP
    tic %Start timing of one loop
    i = 1; %Counter for sample feeding
    if FILEMODE == 0
    	[zbuff, ~, lost] = step(hSDR);  % Grab block of samples from dongle, store them in buffer
        if lost > 0
           fprintf('\nSamples lost: %d', lost); %Print error if samples were lost
           fprintf('\n');
        else
           zbuff=s(block_index:block_index+(BLOCKSIZE-1)); % Grab block of samples from file, store them in buffer
        end
    else    
    buff = int32((real(zbuff)).^2+((imag(zbuff)).^2)); %Cheap absolute value of buffer
    while i < BLOCKSIZE-(96*SP) %Loop feeds samples through decoder
       cu = cumsum(buff(i:i+96*SP)); %Perform cumulative summation
       softbits = (2*cu((SP/2)+1:SP:(95*SP)+(SP/2)+1))- cu(1:SP:(95*SP)+1) - cu(SP+1:SP:(95*SP)+SP+1);
       bits = (softbits>0); %Column vector with '1' where corresponding index in softbits is positive

       %% Check if preamble is correct and parse data
       if sum(bits(1:21)==PREAMBLE) == 21
       %bin_dec = [zeros(180,1);bin2dec(num2str(bits(22:96)))]; %Pad length to 255
       bin_dec = binary2decimal(bits(22:96)');
            %% BCH processing
            dc = [zeros(180,1);bits(22:96)];%bin2dec(num2str(bits(22:96)))];
            if polynomialDivision(BCH_POLY,bits(22:96)') == 0
                %%BCH passed
                i = i+(96*SP)-JMP; %Jump past current message on next iteration
                cnt = cnt+1;       %Record successful message detection
                %% Separate BCH Decoded blocks
                dc_id = [dc(181:182);dc(216:239)];
                SCM_ID = [bits(22:23)',bits(56:79)'];
                dc_phy_tmp = dc(184:185);
                dc_ert_type = dc(186:189);
                dc_enc_tmp = dc(190:191);
                dc_consump = dc(192:215);
                %% Convert to decimal
                dc_id = binary2decimal(dc_id);
                dc_phy_tmp = binary2decimal(dc_phy_tmp);
                dc_ert_type = binary2decimal(dc_ert_type);
                dc_enc_tmp = binary2decimal(dc_enc_tmp);
                dc_consump = binary2decimal(dc_consump);%bin2dec(num2str(dc_consump)');
                %% Print Decoded Output
                fprintf('\nDecoded Meter ID: %d', dc_id);
                fprintf('\nDecoded Meter Type: %d', dc_ert_type);
                fprintf('\nDecoded Physical Tamper: %d', dc_phy_tmp);
                fprintf('\nDecoded Encoder Tamper: %d', dc_enc_tmp);
                fprintf('\nDecoded Consumption: %d', dc_consump);
                fprintf('\n');
            else
                %BCH failed
            end %end: if polynomialDivision(BCH_POLY,bits(22:96)') == 0
%           end %if (nerrs == 0)
       else
           %Preamble not found
       end %end: if sum(bits(1:21)==PREAMBLE) == 21
       i = i+JMP;  %Skip ahead
    end %end: i < BLOCKSIZE-(96*SP)
    block_index=block_index+(JMP*96); %Feed new data through the loop
    toc %Display end time for one loop
end %end: while block_index < numel(s)-BLOCKSIZE+JMP
