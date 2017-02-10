function dvb = encode_maher(needed_coderate, num_frames, subsystemType_code, save_encbits, use_bch , use_interleaver)
%{
Picks nearest standard code to puncture.

Input:  needed_coderate, number of frames,
		save_encbits = save encbits to .mat file
		use_bch = to concatenate bch or not

Output: Hmatrix_rate<needed_coderate>.mat
		Encodedbits_rate<needed_coderate>.mat (if save_encbits == true)
%}
if(nargin  == 2)
    subsystemType_code='QPSK'; %QPSK 16QM 64QM 256Q
    save_encbits = true
    use_bch = false
    use_interleaver = true
elseif(nargin  == 3)
    save_encbits = true
    use_bch = false
    use_interleaver = true
elseif(nargin  == 4)
    use_bch = false
    use_interleaver = true
elseif(nargin == 5)
    use_interleaver = true
end


%% Pick the rate closest to the standard rate 
% We pick the rate just below, since we can puncture the code.
rates=[1/4, 1/3, 2/5, 1/2, 3/5, 2/3, 3/4, 4/5, 5/6, 8/9, 9/10 ];    % Constellation and LDPC code rate
rates_string={'1/4';'1/3';'2/5';'1/2';'3/5';'2/3';'3/4';'4/5';'5/6';'8/9';'9/10'};
newrates=rates-needed_coderate;
newrates(newrates>0)=-inf; %to choose the closest rate just below needed rate
[~,i]=max(newrates);
subsystemType=char(strcat(subsystemType_code,{' '},rates_string(i)));

EsNodB=10;

%% Simulation Parameters
% Set simulation parameter and constants
% Set up system parameters and display the parameter structure
maxNumLDPCIterations = 50;
dvb = getParamsDVBS2Demo_modified(subsystemType, EsNodB, maxNumLDPCIterations);

%% Modification to enable other rates
if(needed_coderate>=.25)%0.5 && needed_coderate<.6)
    [dvb.LDPCParityCheckMatrix,ncr]=pseudorand_puncturing_anyrate_no_H_modification(needed_coderate,dvb.BitsPerSymbol);
    new_n=size(dvb.LDPCParityCheckMatrix,2);
    new_m=size(dvb.LDPCParityCheckMatrix,1);
    dvb.rate=ncr;
    
    dvb.LDPCCodewordLength=new_n;
    dvb.InterleaveOrder = (1:dvb.LDPCCodewordLength).';
    if use_interleaver
        Ncol = dvb.BitsPerSymbol;
        iTemp = reshape(dvb.InterleaveOrder, ...
            dvb.LDPCCodewordLength/Ncol, Ncol).';
        if ncr == 3/5
            % Special Case - Figure 8
            iTemp = flipud(iTemp);
        end
        dvb.InterleaveOrder = iTemp(:);
    end
end
dvb.NumSymsPerCodeword = dvb.LDPCCodewordLength/dvb.BitsPerSymbol;

hBCHEnc = comm.BCHEncoder('CodewordLength', dvb.BCHCodewordLength, ...
    'MessageLength', dvb.BCHMessageLength, ...
    'PrimitivePolynomialSource', 'Property', ...
    'PrimitivePolynomial', dvb.BCHPrimitivePoly, ...
    'GeneratorPolynomialSource', 'Property', ...
    'GeneratorPolynomial', dvb.BCHGeneratorPoly, ...
    'CheckGeneratorPolynomial', false);

hIntrlv   = comm.BlockInterleaver(dvb.InterleaveOrder);


%% Make the LDPC encoder object
hLDPCEnc = comm.LDPCEncoder(dvb.LDPCParityCheckMatrix);

%% Make

b4Enc_bitSET=zeros(num_frames,dvb.BCHMessageLength);
Enc_bitSET=zeros(num_frames,dvb.LDPCCodewordLength);
bbFrameTx  = false(hBCHEnc.CodewordLength,1);
for frameCnt=1:num_frames
    % Transmitter
    bbFrameTx(1:dvb.BCHCodewordLength) = b4Enc_bitSET(frameCnt,1:dvb.BCHCodewordLength)';
    ldpcEncOut           = step(hLDPCEnc,  bbFrameTx);
    intrlvrOut           = step(hIntrlv,   ldpcEncOut);
    Enc_bitSET(frameCnt,:)=intrlvrOut;
end
end