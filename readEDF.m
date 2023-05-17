function readEDF(fname,outDir)
% readEDF(fname,outDir)
% parse data from Eyelink
% 
% Outputs:
%     Separate files containing fixations, saccades, samples


wd = pwd;

%Open Eyelink data
fid = fopen(fname, 'r');
% fname = strtok(fname,'.');      %Remove file extension from fname
[~,fname] = fileparts(fname);   % remove path and file extension

%Open file for raw samples output
outputFname = sprintf('%s_samples.csv',fname);   %add .csv extension to output fname
outputRawSamp = fopen(fullfile(outDir,outputFname),'w');

%Open file for fixation data
outputFix = sprintf('%s_fixations.csv',fname);
outputFix = fopen(fullfile(outDir,outputFix),'w');

%Open file for saccade data
outputSacc = sprintf('%s_saccades.csv',fname);
outputSacc = fopen(fullfile(outDir,outputSacc),'w');


%%
%Define the cleanup routine
cleanupObj = onCleanup(@()cleanup(wd));
    function cleanup(wd)
        cd(wd);                 %Reset working directory
        result = fclose('all');
        if result == 0
            disp('All files closed!')
        else
            disp('Some files were not closed!')
        end
    end
%%

if fid == -1
    disp('File open not successful!')
elseif outputRawSamp == -1
    disp('Output Raw file not opened successfully!')
elseif outputFix == -1
    disp('Output Fix file not opened successfully!')
elseif outputSacc == -1
    disp('Output Sacc file not opened successfully!');
else
    
    %Write header for raw sample file
    headerRaw = {'trial','block','img','timeStamp','trialTime','xPos','yPos','pupilSz','blink'};
    fprintf(outputRawSamp, '%s,',headerRaw{1,1:end-1});
    fprintf(outputRawSamp, '%s\n',headerRaw{1,end});
    
    %Write header for output fix file
    headerFix = {'trial','block','img','stime','etime','dur','axPos','ayPos','apupilSz'};
    fprintf(outputFix,'%s,',headerFix{1,1:end-1});
    fprintf(outputFix,'%s\n',headerFix{1,end});
    
    %Write header for output saccade file
    headerSacc = {'trial','block','img','stime','etime','dur','sxPos','syPos',...
        'exPos','eyPos','ampl','pv'};
    fprintf(outputSacc,'%s,',headerSacc{1,1:end-1});
    fprintf(outputSacc,'%s\n',headerSacc{1,end});
    
    %Skip the header and calibration info
    skipToLine(fid,'START');token = 'START';
    trialNum = 0;
    startTime = 0;
    img = 'NA';
    blink = 0;
    block = 0;
    
    %Start reading the edf data one line at a time
    while ~feof(fid)
        if strcmp(token,'START')
            fgets(fid);          %gobble line
            token = fscanf(fid, '%s', 1);
        elseif strcmp(token,'MSG')
            t = fscanf(fid,'%d',1);     %time stamp
            msg = fscanf(fid,'%s',1);   %Eyelink message
            if strcmp(msg,'STRIAL')
                trialNum = fscanf(fid,'%i',1);
                %Print message to command prompt
                fprintf('Processing trial %i ...\n',trialNum);
                img = fscanf(fid,'%s',1);
                startTime = t;
                fgets(fid);         %gobble
                token = fscanf(fid, '%s', 1);
            elseif strcmp(msg,'ETRIAL')
                startTime = [];
                fgets(fid);         %gobble
                skipToLine(fid,'MSG');       %Skip to next trial
                token = 'MSG';
            elseif strcmp(msg,'BLOCK')
                block = fscanf(fid,'%i',1);
                fgets(fid);         %gobble
                token = fscanf(fid, '%s', 1);
            elseif strcmp(msg,'Trigger')
                block = 1;
                fgets(fid);         %gobble
                token = fscanf(fid,'%i',1);
            elseif strcmp(msg,'ExperimentEnd')
                block = 0;
                fgets(fid);         %gobble
                token = fscanf(fid,'%i',1);
            else
                fgets(fid);          %gobble
                token = fscanf(fid, '%s', 1);
            end
            
        elseif strcmp(token,'EFIX')
            fscanf(fid,'%s',1);
            eFix = fscanf(fid,'%g',6);
            
            %Record fixation data
            fprintf(outputFix,'%i,',trialNum);              %current trial number
            fprintf(outputFix,'%i,',block);                 %current block number
            fprintf(outputFix,'%s,',img);                   %image name
            fprintf(outputFix,'%f,',eFix(1:end-1));         %Fixation data
            fprintf(outputFix,'%f\n',eFix(end));
            
            fgets(fid);          %gobble rest of the line
            token = fscanf(fid, '%s', 1);

        elseif strcmp(token,'ESACC')
            fscanf(fid,'%s',1);
            eSacc = fscanf(fid,'%g',9);
            
            %Record saccade data
            fprintf(outputSacc,'%i,',trialNum);              %current trial number
            fprintf(outputSacc,'%i,',block);                 %current block
            fprintf(outputSacc,'%s,',img);                   %image name
            fprintf(outputSacc,'%f,',eSacc(1:end-1));         %Saccade data
            fprintf(outputSacc,'%f\n',eSacc(end));
            
            %fgets(fid);                         %gobble
            token = fscanf(fid, '%s', 1);
        elseif strcmp(token, 'SBLINK')
            blink = 1;
            fgets(fid);         %gobble
            token = fscanf(fid, '%s', 1);
        elseif strcmp(token, 'EBLINK')
            blink = 0;
            fgets(fid);             %gobble
            token = fscanf(fid, '%s', 1);
        elseif any(token(1) == '0123456789')
            sampleData = fscanf(fid,'%g',3);
            sampleTime = str2double(token) - startTime;
            
            %Record data for current sample
            fprintf(outputRawSamp,'%i,',trialNum);              %current trial number
            fprintf(outputRawSamp,'%i,',block);                 %current block
            fprintf(outputRawSamp,'%s,',img);                   %image name
            fprintf(outputRawSamp,'%f,',str2num(token));        %time stamp
            fprintf(outputRawSamp,'%d,',sampleTime);            %time since trial onset
            if ~isempty(sampleData)
                fprintf(outputRawSamp,'%f,',sampleData(1:end));         %xPos,yPos,pupilSz
            else
                fprintf(outputRawSamp,'NA,');
                fprintf(outputRawSamp,'NA,');
                fprintf(outputRawSamp,'NA,');
            end
            fprintf(outputRawSamp,'%i\n',blink);                %blink detected? 0 = No, 1 = Yes
            
            fgets(fid);          %gobble rest of the line
            token = fscanf(fid, '%s', 1);
        else
            fgets(fid);          %gobble rest of line
            token = fscanf(fid, '%s', 1);
        end
        
    end
end
cd(wd)
end

%%
function token = skipToLine(fid, str)
%fid is the fileId returned by fopen()
%str is the beginning of the line you would like to skip to
token = '';
pass=1;
while ~feof(fid) && pass
    token=fscanf(fid, '%s',1);
    if strcmp(token,str) pass=0; break;
    else fgets(fid);  %gobble
    end
end
end



