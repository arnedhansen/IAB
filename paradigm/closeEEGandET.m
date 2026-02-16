% Stop Eye Tracking recordings and save the data

% No EEG recording - only eye tracking
fprintf('Stop Recording Track\n');
Eyelink('StopRecording');
Eyelink('CloseFile');
fprintf('Downloading File\n');

% Ensure filePath and edfFile are available (they should be from calibrateET or IAB_task)
if ~exist('filePath', 'var')
    % Try to get from caller workspace
    try
        filePath = evalin('caller', 'filePath');
    catch
        error('filePath not found. Make sure calibrateET was called.');
    end
end
if ~exist('edfFile', 'var')
    % Try to get from caller workspace
    try
        edfFile = evalin('caller', 'edfFile');
    catch
        error('edfFile not found. Make sure calibrateET was called.');
    end
end

EL_DownloadDataFile;
EL_Cleanup;

% Convert EDF to ASC in the subject folder
pathEdf2Asc = '/usr/bin/edf2asc';
edfFilePath = fullfile(filePath, edfFile);

% Check if EDF file exists before converting
if exist(edfFilePath, 'file')
    disp("CONVERTING EDF to ASCII...")
    % Change to filePath directory to ensure ASC is saved there
    currentDir = pwd;
    try
        cd(filePath);
        % Run edf2asc conversion (output will be in current directory, i.e., filePath)
        [status, result] = system([pathEdf2Asc ' "' edfFile '" -y']);
        if status == 0
            ascFile = strrep(edfFile, '.edf', '.asc');
            fprintf('EDF file converted to ASC: %s\n', fullfile(filePath, ascFile));
        else
            warning('EDF to ASC conversion may have failed: %s', result);
        end
        cd(currentDir); % Return to original directory
    catch ME
        cd(currentDir); % Make sure we return to original directory even on error
        rethrow(ME);
    end
else
    warning('EDF file not found at: %s', edfFilePath);
end