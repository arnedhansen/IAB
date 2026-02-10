% Stop Eye Tracking recordings and save the data

% No EEG recording - only eye tracking
fprintf('Stop Recording Track\n');
Eyelink('StopRecording');
Eyelink('CloseFile');
fprintf('Downloading File\n');
EL_DownloadDataFile;
EL_Cleanup;

pathEdf2Asc = '/usr/bin/edf2asc';  
disp("CONVERTING EDF to ASCII...")
system([pathEdf2Asc ' "' fullfile(filePath, edfFile) '" -y']);