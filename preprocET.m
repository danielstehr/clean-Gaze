function [data,raw] = preprocET(sub,ses,fs)
% [data,raw] = procET(sub,ses,fs)
% pre-process eye tracking data from Eyelink hardware
% 
% Steps:
%     1. Parse data into fixations/saccades/samples
%     2. Censor extra margin on either side of blinks
%     3. Interpolate missing data
%     4. Low-pass filter
%     5. Detrend 
%     6. Median center
%     7. Re-censor blinks
%     8. Downsample
% Inputs:
%     <sub>, the subject identifier (e.g. sub-xxxx)
%     <ses>, the session (e.g. ses-xx)
%     <fs>, the sampling rate in Hz
% Outputs:
%     <data>, the pre-processed eye gaze data
%     <raw>, the raw, downsampled data (useful for comparisons)

nyq = fs/2;         % Nyquist freq

wd = pwd();
outDir = fullfile('/data1/2021_R01/derivatives/custom',sub,'ET');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

% get list of files to work on
datadir = fullfile('/data1/2021_R01/rawdata',sub,ses,'func');
fid = dir(fullfile(datadir,'*.asc'));

for f = 1:length(fid)
    
    %% Read output of edf file and parse
    fprintf(1,'Reading %s\n',fid(f).name);
    readEDF(fullfile(fid(f).folder,fid(f).name),outDir);
    
    %% load data
    data = readtable(fullfile(outDir,strcat(strtok(fid(f).name,'.'),'_samples.csv')));
    data = data(find(data.block),:);
    raw = data;
    
    totalsamp = size(data,1);
    runlen = totalsamp/fs;
    assert((runlen < 600) && (300 < runlen),'Number of samples does not match the expected run lenght. Please check you specified the right sampling rate');
    
    %% Increase blink duration by same margin on either side
    ms2expand = 300;        % duration to expand blinks by (ms)
    samples2expand = 2*ceil((ms2expand/1000)*fs);
    k = ones(1,samples2expand);
    data.blink = conv(data.blink,k,'same') > 0;
    data.xPos(find(data.blink)) = NaN;
    data.yPos(find(data.blink)) = NaN;
    
    %% Interpolate/fill-in missing data
    data.xPos = inpaintn(data.xPos);
    data.yPos = inpaintn(data.yPos);
    
    %% Low-pass filter
    fc = 15;        % cut-off freq (Hz)
    wn = fc/nyq;    % normalized cut-off freq
    [b,a] = butter(2,wn,'low');
    
    data.xPos = filtfilt(b,a,data.xPos);
    data.yPos = filtfilt(b,a,data.yPos);
    
    %% Detrend
    polyreg = polymat(size(data,1),2);
    [b_x,~,data.xPos] = regress(data.xPos,polyreg);
    data.xPos = data.xPos + b_x(1);
    [b_y,~,data.yPos] = regress(data.yPos,polyreg);
    data.yPos = data.yPos + b_y(1);
    
    %% Median-center
    data.xPos = data.xPos - median(data.xPos) + (1920/2);
    data.yPos = data.yPos - median(data.yPos) + (1080/2);
    
    %% Re-censor blink periods
    data.xPos(find(data.blink)) = NaN;
    data.yPos(find(data.blink)) = NaN;
    
    % %% Censor rest period at end (temporary)
    % data.xPos((390*1000):end) = NaN;
    % data.yPos((390*1000):end) = NaN;
    % raw.xPos((390*1000):end) = NaN;
    % raw.yPos((390*1000):end) = NaN;
    
    %% Downsample
    raw = raw(1:4:end,:);
    data = data(1:4:end,:);
    
    %% Save data
    writetable(raw,fullfile(outDir,strcat(strtok(fid(f).name,'.'),'_raw.txt')),'Delimiter',',');
    writetable(data,fullfile(outDir,strcat(strtok(fid(f).name,'.'),'_proc.txt')),'Delimiter',',');
    
end

end

