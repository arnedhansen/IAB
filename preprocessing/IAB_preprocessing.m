%% IAB Eye-Tracking Preprocessing
% Parses .asc files, segments into trials, cleans gaze data, aligns with
% behavioral .mat data, and saves a preprocessed etData struct per subject.
%
% Input:
%   Raw data from /Volumes/g_psyplafor_methlab_data$/OCC/IAB/[subjectID]/
%     - [subjectID]_IAB.asc  (Eyelink ASCII)
%     - [subjectID]_IAB.mat  (behavioral data from paradigm)
%
% Output:
%   Preprocessed data to /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/[subjectID]/
%     - etData_IAB.mat
%
% Pipeline:
%   1. Parse .asc file (gaze samples + MSG events)
%   2. Load behavioral .mat (trial info, distractor positions, responses)
%   3. Segment gaze into trials using STIMULUS_START trigger (21)
%   4. Clean gaze: screen bounds, Y-inversion, blink removal
%   5. Align distractor positions from .mat with ET timeline
%   6. Save etData struct

%% Setup
clear; clc; close all;

% Paths
RAW_PATH  = '/Volumes/g_psyplafor_methlab_data$/OCC/IAB/';
OUT_PATH  = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';
FUNC_PATH = '/Users/Arne/Documents/GitHub/functions/';
addpath(FUNC_PATH);

% Screen parameters
screenW = 800;
screenH = 600;
centreX = 400;
centreY = 300;
sRate   = 500; % Hz

% Preprocessing parameters
blink_window = 50; % samples (100 ms at 500 Hz)
stim_duration = 7.0; % seconds
stim_samples  = stim_duration * sRate; % 3500 samples

% Subject IDs (201-220)
subjects = 201:220;

%% Main loop
for s = 1:length(subjects)
    subjID = num2str(subjects(s));
    fprintf('\n=== Processing Subject %s (%d/%d) ===\n', subjID, s, length(subjects));

    % Check if raw data exists
    ascFile = fullfile(RAW_PATH, subjID, [subjID '_IAB.asc']);
    matFile = fullfile(RAW_PATH, subjID, [subjID '_IAB.mat']);

    if ~exist(ascFile, 'file')
        fprintf('  ASC file not found: %s — skipping.\n', ascFile);
        continue;
    end
    if ~exist(matFile, 'file')
        fprintf('  MAT file not found: %s — skipping.\n', matFile);
        continue;
    end

    %% 1. Parse .asc file
    fprintf('  Parsing ASC file...\n');
    [gazeRaw, messages, fixations, saccades, blinks] = parse_asc(ascFile);

    %% 2. Load behavioral .mat file
    fprintf('  Loading behavioral data...\n');
    behav = load(matFile);
    data    = behav.saves.data;
    subject = behav.saves.subject;
    timing  = behav.saves.timing;
    nTrials = length(data.correctSum);

    %% 3. Extract trigger timestamps from messages
    % Find STIMULUS_START triggers (code 21)
    stimStartTimes = [];
    for m = 1:length(messages)
        if messages(m).code == 21
            stimStartTimes = [stimStartTimes; messages(m).time];
        end
    end

    fprintf('  Found %d STIMULUS_START triggers (expected %d trials).\n', ...
        length(stimStartTimes), nTrials);

    if length(stimStartTimes) < nTrials
        warning('Fewer triggers than trials. Using available triggers.');
        nTrials = length(stimStartTimes);
    end

    %% 4. Segment and clean gaze data per trial
    fprintf('  Segmenting and cleaning gaze...\n');

    etData = struct();
    etData.sampleRate = sRate;
    etData.screenW    = screenW;
    etData.screenH    = screenH;
    etData.centreX    = centreX;
    etData.centreY    = centreY;
    etData.subjectID  = subjID;
    etData.group      = subject.group;
    etData.groupName  = subject.groupName;

    % Preallocate cell arrays
    etData.gazeX  = cell(1, nTrials);
    etData.gazeY  = cell(1, nTrials);
    etData.pupil  = cell(1, nTrials);
    etData.time   = cell(1, nTrials);

    % Trial info
    etData.trialinfo = zeros(nTrials, 3); % [trialNum, crossPresent, groupCode]
    groupCode = strcmp(subject.group, 'B'); % 0=A, 1=B

    % Distractor positions (from .mat)
    etData.distractorPos  = cell(1, nTrials);
    etData.distractorTime = cell(1, nTrials);

    % Behavioral data
    etData.correctSum        = data.correctSum(1:nTrials);
    etData.participantSum    = data.participantSum(1:nTrials);
    etData.continuousAccuracy = data.continuousAccuracy(1:nTrials);
    etData.reactionTime      = data.reactionTime(1:nTrials);
    etData.crossPresent      = data.crossPresent(1:nTrials);
    etData.digits            = data.digits(1:nTrials);
    etData.digitColors       = data.digitColors(1:nTrials);

    % Perception data (if available)
    if isfield(behav.saves, 'perceptionData')
        etData.perceptionData = behav.saves.perceptionData;
    end

    for trl = 1:nTrials
        % Find gaze samples within stimulus window
        tStart = stimStartTimes(trl);
        tEnd   = tStart + stim_duration * 1000; % convert to ms (Eyelink timestamps in ms)

        % Extract samples in this window
        idx = gazeRaw(:,1) >= tStart & gazeRaw(:,1) < tEnd;
        trialGaze = gazeRaw(idx, :);

        if isempty(trialGaze)
            etData.gazeX{trl}  = NaN(1, stim_samples);
            etData.gazeY{trl}  = NaN(1, stim_samples);
            etData.pupil{trl}  = NaN(1, stim_samples);
            etData.time{trl}   = linspace(0, stim_duration, stim_samples);
            continue;
        end

        % Extract left eye data (columns: time, L_X, L_Y, L_AREA, R_X, R_Y, R_AREA)
        gx = trialGaze(:, 2)'; % L_GAZE_X
        gy = trialGaze(:, 3)'; % L_GAZE_Y
        gp = trialGaze(:, 4)'; % L_AREA (pupil)

        % Create time vector relative to stimulus onset (in seconds)
        tVec = (trialGaze(:, 1)' - tStart) / 1000;

        % Resample to exactly stim_samples if needed (should be close to 3500)
        timeOut = linspace(0, stim_duration, stim_samples);
        if length(gx) ~= stim_samples
            gx = interp1(tVec, gx, timeOut, 'nearest', NaN);
            gy = interp1(tVec, gy, timeOut, 'nearest', NaN);
            gp = interp1(tVec, gp, timeOut, 'nearest', NaN);
            tVec = timeOut;
        end

        %% Clean gaze data
        % Filter out-of-bounds samples
        outOfBounds = gx < 0 | gx > screenW | gy < 0 | gy > screenH;
        gx(outOfBounds) = NaN;
        gy(outOfBounds) = NaN;
        gp(outOfBounds) = NaN;

        % Invert Y-axis (screen coords to Cartesian: 0,0 at bottom-left)
        gy = screenH - gy;

        % Remove blinks (using remove_blinks function)
        gazeMatrix = [gx; gy; gp];
        gazeMatrix = remove_blinks(gazeMatrix, blink_window);

        gx = gazeMatrix(1, :);
        gy = gazeMatrix(2, :);
        gp = gazeMatrix(3, :);

        % Store cleaned data
        etData.gazeX{trl}  = gx;
        etData.gazeY{trl}  = gy;
        etData.pupil{trl}  = gp;
        etData.time{trl}   = tVec;

        % Store trial info
        etData.trialinfo(trl, :) = [trl, data.crossPresent(trl), groupCode];

        % Store distractor positions (from .mat, already in pixel coords)
        if data.crossPresent(trl) == 1 && iscell(data.crossPosition) && ~isempty(data.crossPosition{trl})
            dPos = data.crossPosition{trl}; % N×2 matrix [x, y]
            dTime = data.crossPositionTime{trl}; % N×1 timestamps

            % Invert Y to match gaze (Cartesian coords)
            dPos(:, 2) = screenH - dPos(:, 2);

            etData.distractorPos{trl}  = dPos;
            etData.distractorTime{trl} = dTime;
        else
            etData.distractorPos{trl}  = [];
            etData.distractorTime{trl} = [];
        end
    end

    %% 5. Extract fixation/saccade events per trial
    etData.fixations = cell(1, nTrials);
    etData.saccades  = cell(1, nTrials);

    for trl = 1:nTrials
        tStart = stimStartTimes(trl);
        tEnd   = tStart + stim_duration * 1000;

        % Fixations in this trial
        trlFix = [];
        for f = 1:length(fixations)
            if fixations(f).eye == 'L' && ...
               fixations(f).startTime >= tStart && fixations(f).endTime <= tEnd
                fix = fixations(f);
                fix.startTime = (fix.startTime - tStart) / 1000; % relative, in seconds
                fix.endTime   = (fix.endTime - tStart) / 1000;
                fix.avgY      = screenH - fix.avgY; % invert Y
                trlFix = [trlFix; fix];
            end
        end
        etData.fixations{trl} = trlFix;

        % Saccades in this trial
        trlSacc = [];
        for sc = 1:length(saccades)
            if saccades(sc).eye == 'L' && ...
               saccades(sc).startTime >= tStart && saccades(sc).endTime <= tEnd
                sacc = saccades(sc);
                sacc.startTime = (sacc.startTime - tStart) / 1000;
                sacc.endTime   = (sacc.endTime - tStart) / 1000;
                sacc.startY    = screenH - sacc.startY; % invert Y
                sacc.endY      = screenH - sacc.endY;
                trlSacc = [trlSacc; sacc];
            end
        end
        etData.saccades{trl} = trlSacc;
    end

    %% 6. Save preprocessed data
    outDir = fullfile(OUT_PATH, subjID);
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    save(fullfile(outDir, 'etData_IAB.mat'), 'etData', '-v7.3');
    fprintf('  Saved: %s\n', fullfile(outDir, 'etData_IAB.mat'));
end

fprintf('\n=== Preprocessing complete ===\n');

%% ========================================================================
%  LOCAL FUNCTION: Parse .asc file
%  ========================================================================
function [gazeRaw, messages, fixations, saccades, blinks] = parse_asc(ascFile)
% PARSE_ASC  Parse an Eyelink .asc file into gaze samples and events.
%
%   gazeRaw   — N×7 matrix: [time, L_X, L_Y, L_AREA, R_X, R_Y, R_AREA]
%   messages  — struct array with fields: time, code, text
%   fixations — struct array with fields: eye, startTime, endTime, duration, avgX, avgY, avgPupil
%   saccades  — struct array with fields: eye, startTime, endTime, duration, startX, startY, endX, endY, amplitude, peakVel
%   blinks    — struct array with fields: eye, startTime, endTime, duration

    fid = fopen(ascFile, 'r');
    if fid == -1; error('Cannot open file: %s', ascFile); end

    % Preallocate
    gazeData = [];
    messages  = struct('time', {}, 'code', {}, 'text', {});
    fixations = struct('eye', {}, 'startTime', {}, 'endTime', {}, 'duration', {}, ...
                       'avgX', {}, 'avgY', {}, 'avgPupil', {});
    saccades  = struct('eye', {}, 'startTime', {}, 'endTime', {}, 'duration', {}, ...
                       'startX', {}, 'startY', {}, 'endX', {}, 'endY', {}, ...
                       'amplitude', {}, 'peakVel', {});
    blinks    = struct('eye', {}, 'startTime', {}, 'endTime', {}, 'duration', {});

    gazeBuffer = zeros(500000, 7); % preallocate buffer
    gazeCount = 0;

    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line); continue; end
        line = strtrim(line);
        if isempty(line); continue; end

        % Gaze sample lines start with a digit
        if line(1) >= '0' && line(1) <= '9'
            % Replace '.' markers (missing data) with NaN
            line = regexprep(line, '\s+\.\.+', ' NaN');
            vals = sscanf(line, '%f');
            if length(vals) >= 7
                gazeCount = gazeCount + 1;
                if gazeCount > size(gazeBuffer, 1)
                    gazeBuffer = [gazeBuffer; zeros(500000, 7)];
                end
                gazeBuffer(gazeCount, :) = vals(1:7)';
            end

        % MSG lines
        elseif startsWith(line, 'MSG')
            tokens = regexp(line, '^MSG\s+(\d+)\s+(.+)', 'tokens');
            if ~isempty(tokens)
                timeStamp = str2double(tokens{1}{1});
                msgText   = strtrim(tokens{1}{2});
                % Try to parse as numeric trigger code
                trigCode = str2double(msgText);
                if ~isnan(trigCode)
                    messages(end+1) = struct('time', timeStamp, 'code', trigCode, 'text', msgText);
                end
            end

        % EFIX (end fixation)
        elseif startsWith(line, 'EFIX')
            tokens = regexp(line, '^EFIX\s+(\w)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)', 'tokens');
            if ~isempty(tokens)
                t = tokens{1};
                fixations(end+1) = struct('eye', t{1}, ...
                    'startTime', str2double(t{2}), 'endTime', str2double(t{3}), ...
                    'duration', str2double(t{4}), ...
                    'avgX', str2double(t{5}), 'avgY', str2double(t{6}), ...
                    'avgPupil', str2double(t{7}));
            end

        % ESACC (end saccade)
        elseif startsWith(line, 'ESACC')
            tokens = regexp(line, '^ESACC\s+(\w)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)', 'tokens');
            if ~isempty(tokens)
                t = tokens{1};
                saccades(end+1) = struct('eye', t{1}, ...
                    'startTime', str2double(t{2}), 'endTime', str2double(t{3}), ...
                    'duration', str2double(t{4}), ...
                    'startX', str2double(t{5}), 'startY', str2double(t{6}), ...
                    'endX', str2double(t{7}), 'endY', str2double(t{8}), ...
                    'amplitude', str2double(t{9}), 'peakVel', str2double(t{10}));
            end

        % EBLINK (end blink)
        elseif startsWith(line, 'EBLINK')
            tokens = regexp(line, '^EBLINK\s+(\w)\s+(\d+)\s+(\d+)\s+(\d+)', 'tokens');
            if ~isempty(tokens)
                t = tokens{1};
                blinks(end+1) = struct('eye', t{1}, ...
                    'startTime', str2double(t{2}), 'endTime', str2double(t{3}), ...
                    'duration', str2double(t{4}));
            end
        end
    end

    fclose(fid);
    gazeRaw = gazeBuffer(1:gazeCount, :);

    fprintf('    Parsed: %d gaze samples, %d messages, %d fixations, %d saccades, %d blinks\n', ...
        gazeCount, length(messages), length(fixations), length(saccades), length(blinks));
end
