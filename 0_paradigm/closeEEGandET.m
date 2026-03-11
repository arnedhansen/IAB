% Stop Eye Tracking recordings and save the data
% Variables filePath and edfFile must exist in the workspace
% (set by calibrateET.m, available because all scripts share the same workspace)

% No EEG recording - only eye tracking
fprintf('Stop Recording Track\n');
Eyelink('StopRecording');
Eyelink('CloseFile');

%% Download EDF file to subject folder
fprintf('Downloading EDF file...\n');
EL_DownloadDataFile;
EL_Cleanup;

%% Convert EDF to ASC in the subject folder
pathEdf2Asc = '/usr/bin/edf2asc';
edfFullPath = fullfile(filePath, edfFile);

if exist(edfFullPath, 'file')
    fprintf('CONVERTING EDF to ASCII...\n');
    [status, result] = system([pathEdf2Asc ' "' edfFullPath '" -y']);
    if status == 0
        ascFile = strrep(edfFile, '.edf', '.asc');
        fprintf('ASC file saved: %s\n', fullfile(filePath, ascFile));
    else
        warning('EDF to ASC conversion failed: %s', result);
    end
else
    warning('EDF file not found at: %s — skipping ASC conversion', edfFullPath);
end
