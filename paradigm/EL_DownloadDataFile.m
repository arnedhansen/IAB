%% Download Datafile from Eyelink Tracker
% The filename needs to be present in the variable edfFile
% filePath and edfFile should be defined in the calling function's workspace
% This function uses evalin('caller') to access variables from the calling workspace

% Get filePath and edfFile from calling workspace
try
    filePath = evalin('caller', 'filePath');
    edfFile = evalin('caller', 'edfFile');
catch
    error('filePath and edfFile must be defined in the calling function');
end

% Ensure filePath directory exists
if ~exist(filePath, 'dir')
    mkdir(filePath);
end

% Set destination path for EDF file
destinationPath = fullfile(filePath, edfFile);

try
    fprintf('Receiving data file ''%s''\n', edfFile );
    
    % Try to receive file directly to destination path
    % Note: Eyelink('ReceiveFile', edfFile, destinationPath) may not be supported
    % on all systems, so we'll try and fall back to moving the file if needed
    try
        status = Eyelink('ReceiveFile', edfFile, destinationPath);
    catch
        % If three-argument form doesn't work, use two-argument form
        status = Eyelink('ReceiveFile', edfFile);
    end
    
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
        
        % Check if file was downloaded to current directory instead of destination
        if exist(edfFile, 'file') && ~exist(destinationPath, 'file')
            % File was downloaded to current directory, move it to destination
            movefile(edfFile, destinationPath);
            fprintf('EDF file moved from current directory to: %s\n', filePath);
        elseif exist(destinationPath, 'file')
            fprintf('EDF file saved to: %s\n', filePath);
        else
            warning('EDF file download completed but file not found at expected location');
        end
    elseif status < 0
        fprintf('Error receiving data file ''%s''\n', edfFile);
    else
        fprintf('No data file received (file may not exist on tracker)\n');
    end
catch rdf
    fprintf('Problem receiving data file ''%s''\n', edfFile );
    rdf;
end