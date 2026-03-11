%% IAB Simulated Eye-Tracking Data Generator
% Creates synthetic etData_IAB.mat files with realistic trial-level structure
% and subtle but clear Group A vs Group B differences.
%
% Output structure matches preprocessing output, so downstream scripts can run:
%   - IAB_feature_extraction.m
%   - IAB_analyze_et.m
%
% Usage:
%   1) Set OUT_PATH below (default: local repo folder "simulated_data")
%   2) Run this script
%   3) Point DATA_PATH in analysis scripts to the generated OUT_PATH

%% Setup
clear; clc; close all;

rng(42, 'twister'); % reproducible simulated dataset

% Output root
OUT_PATH = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'simulated_data');

% Subject IDs and groups
subjects = 201:220;
nSubjects = numel(subjects);
nTrialsPerSubject = 80;

% Screen / timing parameters
screenW = 800;
screenH = 600;
centreX = 400;
centreY = 300;
sRate   = 500;
stimDuration = 7.0;
nSamples = stimDuration * sRate; % 3500
tVec = linspace(0, stimDuration, nSamples);

if ~exist(OUT_PATH, 'dir')
    mkdir(OUT_PATH);
end

fprintf('Generating simulated etData in: %s\n', OUT_PATH);
fprintf('Subjects: %d | Trials per subject: %d\n', nSubjects, nTrialsPerSubject);

%% Generate per-subject files
for s = 1:nSubjects
    subjID = subjects(s);
    subjIDstr = num2str(subjID);

    % Balanced groups: first half A (Focused), second half B (Expanded)
    isGroupB = s > nSubjects/2;
    if isGroupB
        group = 'B';
        groupName = 'Expanded';
    else
        group = 'A';
        groupName = 'Focused';
    end

    % 50/50 distractor absent/present, shuffled per subject
    crossPresent = [zeros(1, nTrialsPerSubject/2), ones(1, nTrialsPerSubject/2)];
    crossPresent = crossPresent(randperm(nTrialsPerSubject));

    etData = struct();
    etData.sampleRate = sRate;
    etData.screenW    = screenW;
    etData.screenH    = screenH;
    etData.centreX    = centreX;
    etData.centreY    = centreY;
    etData.subjectID  = subjIDstr;
    etData.group      = group;
    etData.groupName  = groupName;

    etData.gazeX  = cell(1, nTrialsPerSubject);
    etData.gazeY  = cell(1, nTrialsPerSubject);
    etData.pupil  = cell(1, nTrialsPerSubject);
    etData.time   = cell(1, nTrialsPerSubject);

    etData.trialinfo = zeros(nTrialsPerSubject, 3);
    etData.distractorPos  = cell(1, nTrialsPerSubject);
    etData.distractorTime = cell(1, nTrialsPerSubject);

    etData.correctSum         = zeros(1, nTrialsPerSubject);
    etData.participantSum     = zeros(1, nTrialsPerSubject);
    etData.continuousAccuracy = zeros(1, nTrialsPerSubject);
    etData.reactionTime       = zeros(1, nTrialsPerSubject);
    etData.crossPresent       = crossPresent;
    etData.digits             = cell(1, nTrialsPerSubject);
    etData.digitColors        = cell(1, nTrialsPerSubject);

    etData.fixations = cell(1, nTrialsPerSubject);
    etData.saccades  = cell(1, nTrialsPerSubject);

    groupCode = double(isGroupB); % 0=A, 1=B

    % Subject-level random effects increase realistic between-subject variance.
    subjNoiseScale = max(0.6, 1 + 0.22 * randn());
    subjPullScale = max(0.5, 1 + 0.28 * randn());
    subjPupilOffset = 220 * randn();

    for trl = 1:nTrialsPerSubject
        hasDistractor = crossPresent(trl) == 1;

        % Distractor path for present trials
        if hasDistractor
            dPos = make_distractor_path(tVec, centreX, centreY);
            etData.distractorPos{trl} = dPos;
            etData.distractorTime{trl} = tVec(:);
        else
            dPos = [];
            etData.distractorPos{trl} = [];
            etData.distractorTime{trl} = [];
        end

        % Simulate gaze and pupil
        [gx, gy, gp] = make_gaze_and_pupil(tVec, dPos, isGroupB, hasDistractor, ...
            centreX, centreY, screenW, screenH, subjNoiseScale, subjPullScale, subjPupilOffset);

        % Add sparse missing data (blink-like segments)
        missMask = false(1, nSamples);
        nDropouts = randi([2, 5]);
        for k = 1:nDropouts
            segLen = randi([8, 28]); % 16-56 ms
            segStart = randi([1, nSamples - segLen + 1]);
            missMask(segStart:(segStart + segLen - 1)) = true;
        end
        gx(missMask) = NaN;
        gy(missMask) = NaN;
        gp(missMask) = NaN;

        % Behavioral measures: subtle but clear group effects
        baseAcc = 86 - 4 * double(isGroupB) - 2 * double(hasDistractor);
        acc = baseAcc + randn() * 3.5;
        acc = min(100, max(50, acc));

        baseRt = 1.05 + 0.07 * double(isGroupB) + 0.06 * double(hasDistractor);
        rt = baseRt + randn() * 0.09;
        rt = max(0.45, rt);

        etData.continuousAccuracy(trl) = acc;
        etData.reactionTime(trl) = rt;
        etData.correctSum(trl) = round(acc / 10);  % placeholder scalar
        etData.participantSum(trl) = etData.correctSum(trl) + randi([-1, 1]);

        % Placeholder digit data (not used in ET pipeline)
        nd = randi([8, 14]);
        etData.digits{trl} = randi([0, 9], 1, nd);
        etData.digitColors{trl} = rand(1, nd) > 0.45;

        % Event arrays with small group/condition shifts
        etData.fixations{trl} = make_fixations(isGroupB, hasDistractor);
        etData.saccades{trl}  = make_saccades(isGroupB, hasDistractor);

        etData.gazeX{trl} = gx;
        etData.gazeY{trl} = gy;
        etData.pupil{trl} = gp;
        etData.time{trl}  = tVec;
        etData.trialinfo(trl, :) = [trl, crossPresent(trl), groupCode];
    end

    outDir = fullfile(OUT_PATH, subjIDstr);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    save(fullfile(outDir, 'etData_IAB.mat'), 'etData', '-v7.3');
    fprintf('  Saved simulated etData for subject %s (%s)\n', subjIDstr, groupName);
end

%% Save dataset metadata
simInfo = struct();
simInfo.seed = 42;
simInfo.subjects = subjects;
simInfo.nTrialsPerSubject = nTrialsPerSubject;
simInfo.sampleRate = sRate;
simInfo.durationSeconds = stimDuration;
simInfo.groupEffectDescription = [ ...
    'Group B has slightly higher gaze variability, longer scan paths, ', ...
    'higher distractor tracking, mildly slower RT, and lower accuracy.'];

save(fullfile(OUT_PATH, 'simulated_dataset_info.mat'), 'simInfo');
fprintf('\nDone. Metadata saved to simulated_dataset_info.mat\n');

%% ========================================================================
% Local functions
% ========================================================================

function dPos = make_distractor_path(tVec, centreX, centreY)
    n = numel(tVec);
    ampX = 120 + randn() * 8;
    ampY = 85 + randn() * 6;
    f1 = 0.18 + rand() * 0.06;
    f2 = 0.11 + rand() * 0.05;
    ph1 = rand() * 2 * pi;
    ph2 = rand() * 2 * pi;

    x = centreX + ampX * sin(2 * pi * f1 * tVec + ph1) + randn(1, n) * 2.0;
    y = centreY + ampY * cos(2 * pi * f2 * tVec + ph2) + randn(1, n) * 2.0;
    dPos = [x(:), y(:)];
end

function [gx, gy, gp] = make_gaze_and_pupil(tVec, dPos, isGroupB, hasDistractor, ...
    centreX, centreY, screenW, screenH, subjNoiseScale, subjPullScale, subjPupilOffset)

    n = numel(tVec);

    % Group B (Expanded) tracks monkey more in present trials.
    baseNoise = 22 + 4 * double(isGroupB);
    noiseSigma = baseNoise * subjNoiseScale;
    if hasDistractor
        if isGroupB
            pullWeight = 0.60 * subjPullScale;   % stronger monkey tracking
            noiseSigma = noiseSigma * 0.85;
        else
            pullWeight = 0.18 * subjPullScale;   % weaker monkey tracking
            noiseSigma = noiseSigma * 1.05;
        end
    else
        pullWeight = 0;
    end
    pullWeight = min(0.9, max(0, pullWeight));

    if hasDistractor
        targetX = centreX + pullWeight * (dPos(:,1)' - centreX);
        targetY = centreY + pullWeight * (dPos(:,2)' - centreY);
    else
        targetX = centreX * ones(1, n);
        targetY = centreY * ones(1, n);
    end

    % AR(1)-like gaze process around target
    gx = zeros(1, n);
    gy = zeros(1, n);
    gx(1) = centreX + randn() * 15;
    gy(1) = centreY + randn() * 15;
    phi = 0.965;
    for i = 2:n
        gx(i) = phi * gx(i-1) + (1 - phi) * targetX(i) + randn() * noiseSigma;
        gy(i) = phi * gy(i-1) + (1 - phi) * targetY(i) + randn() * noiseSigma;
    end

    % Clamp to screen range
    gx = min(screenW, max(0, gx));
    gy = min(screenH, max(0, gy));

    % Pupil values in arbitrary units (later divided by 1000 in extraction)
    trialPupilShift = 65 * randn();
    pupilBase = 3150 + 140 * double(isGroupB) + 60 * double(hasDistractor) + subjPupilOffset + trialPupilShift;
    gp = pupilBase + randn(1, n) * 165;
    gp = max(1500, gp);
end

function fixArr = make_fixations(isGroupB, hasDistractor)
    muFix = 15 + 2 * double(hasDistractor) - 1 * double(isGroupB);
    nFix = max(0, round(muFix + sqrt(muFix) * randn()));
    if nFix <= 0
        fixArr = [];
        return;
    end

    fixArr = repmat(struct( ...
        'eye', 'L', ...
        'startTime', 0, ...
        'endTime', 0, ...
        'duration', 0, ...
        'avgX', 0, ...
        'avgY', 0, ...
        'avgPupil', 0), nFix, 1);

    t0 = 0;
    for i = 1:nFix
        dur = max(70, 225 + randn() * 45 - 12 * double(isGroupB));
        gap = max(20, 85 + randn() * 20);
        st = t0 + gap;
        en = st + dur;
        t0 = en;

        fixArr(i).startTime = st / 1000;
        fixArr(i).endTime = en / 1000;
        fixArr(i).duration = dur;
        fixArr(i).avgX = 400 + randn() * 65;
        fixArr(i).avgY = 300 + randn() * 55;
        fixArr(i).avgPupil = 3200 + randn() * 130;
    end
end

function saccArr = make_saccades(isGroupB, hasDistractor)
    muSacc = 22 + 2 * double(isGroupB) + 2 * double(hasDistractor);
    nSacc = max(0, round(muSacc + sqrt(muSacc) * randn()));
    if nSacc <= 0
        saccArr = [];
        return;
    end

    saccArr = repmat(struct( ...
        'eye', 'L', ...
        'startTime', 0, ...
        'endTime', 0, ...
        'duration', 0, ...
        'startX', 0, ...
        'startY', 0, ...
        'endX', 0, ...
        'endY', 0, ...
        'amplitude', 0, ...
        'peakVel', 0), nSacc, 1);

    t0 = 0;
    for i = 1:nSacc
        dur = max(18, 42 + randn() * 8);
        gap = max(10, 45 + randn() * 10);
        st = t0 + gap;
        en = st + dur;
        t0 = en;

        amp = max(0.5, 3.2 + 0.45 * double(isGroupB) + 0.35 * double(hasDistractor) + randn() * 0.75);

        saccArr(i).startTime = st / 1000;
        saccArr(i).endTime = en / 1000;
        saccArr(i).duration = dur;
        saccArr(i).startX = 400 + randn() * 80;
        saccArr(i).startY = 300 + randn() * 70;
        saccArr(i).endX = saccArr(i).startX + randn() * 45;
        saccArr(i).endY = saccArr(i).startY + randn() * 40;
        saccArr(i).amplitude = amp;
        saccArr(i).peakVel = max(50, 220 + amp * 28 + randn() * 25);
    end
end
