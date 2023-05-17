
% Example command to pre-process eye tracking data
% Please note:
%     1. The raw .edf file must first be converted to .asc format 
%     2. You will need to update paths to suit your file system on following:
%         - readEDF.m
%         -preprocET.m

preprocET('sub-2629','ses-02',250)