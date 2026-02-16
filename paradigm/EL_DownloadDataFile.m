%% Download Datafile from Eyelink Tracker
% Variables filePath and edfFile must exist in the workspace
% (set by calibrateET.m, available because all scripts share the same workspace)

% Verify required variables exist
if ~exist('filePath', 'var') || ~exist('edfFile', 'var')
    error('filePath and edfFile must be defined. Make sure calibrateET was called.');
end

% Ensure subject folder exists
if ~exist(filePath, 'dir')
    mkdir(filePath);
end

% Save current directory and change to subject folder
% Eyelink('ReceiveFile') always downloads to the current working directory
originalDir = pwd;

try
    cd(filePath);
    fprintf('Downloading EDF file ''%s'' to ''%s''\n', edfFile, filePath);
    
    status = Eyelink('ReceiveFile');
    
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
    
    % Verify the file arrived
    if exist(fullfile(filePath, edfFile), 'file')
        fprintf('EDF file saved: %s\n', fullfile(filePath, edfFile));
    else
        warning('EDF file not found at expected location: %s', fullfile(filePath, edfFile));
    end
    
    cd(originalDir);
catch ME
    cd(originalDir);
    fprintf('Problem receiving data file ''%s'': %s\n', edfFile, ME.message);
end
