%% IAB Eye-Tracking Feature Extraction
% Loads preprocessed etData, computes gaze features per trial and per
% subject×condition. Saves feature matrices for statistical analysis.
%
% Features extracted:
%   - BCEA (95%): Bivariate Contour Ellipse Area
%   - Time on Target: proportion of gaze within tot_radius_dva of monkey distractor
%   - Gaze Deviation: mean Euclidean distance from screen center
%   - Gaze Dispersion: SD of X and Y coordinates
%   - Fixation count and mean duration (from Eyelink events)
%   - Saccade count and mean amplitude (from Eyelink events)
%   - Scan Path Length: sum of consecutive gaze displacements
%   - Pupil Size: mean pupil area
%
% Input:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/[subjectID]/etData_IAB.mat
%
% Output:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/[subjectID]/features_IAB.mat
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/features_all.mat (group-level)

%% Setup
clear; clc; close all;

DATA_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';

% Screen parameters
screenW = 800;
screenH = 600;
centreX = 400;
centreY = 300;
sRate   = 500;
stim_duration = 7.0; % seconds; must match IAB_preprocessing.m

% BCEA parameters (95% confidence)
P95 = 0.95;
k95 = -log(1 - P95); % = 2.9957

% Time-on-target parameters (gaze counted as "on target" if within this radius of
% the moving distractor centroid). 1 dva is strict for a peripheral moving target
% while digits are tracked; 2 dva is a common relaxed default (tune as needed).
ppd = screenW / (2 * atand(48 / (2 * 80)) * 2); % pixels per degree
tot_radius_dva = 2; % degrees of visual angle
tot_radius_px  = tot_radius_dva * ppd;

% Subject IDs
subjects = 201:220;

% Preallocate group-level table
allFeatures = [];

%% Main loop
for s = 1:length(subjects)
    subjID = num2str(subjects(s));
    dataFile = fullfile(DATA_PATH, subjID, 'etData_IAB.mat');

    if ~exist(dataFile, 'file')
        fprintf('No data for subject %s — skipping.\n', subjID);
        continue;
    end

    fprintf('\n=== Feature extraction: Subject %s (%d/%d) ===\n', subjID, s, length(subjects));
    load(dataFile, 'etData');

    nTrials = length(etData.gazeX);

    % Preallocate per-trial features
    trialFeatures = struct();
    trialFeatures.subjectID       = repmat(str2double(subjID), nTrials, 1);
    trialFeatures.trial           = (1:nTrials)';
    trialFeatures.group           = repmat(strcmp(etData.group, 'B'), nTrials, 1); % 0=A, 1=B
    trialFeatures.crossPresent    = etData.crossPresent(1:nTrials)';
    trialFeatures.bcea95          = NaN(nTrials, 1);
    trialFeatures.timeOnTarget    = NaN(nTrials, 1);
    trialFeatures.gazeDeviation   = NaN(nTrials, 1);
    trialFeatures.gazeStdX        = NaN(nTrials, 1);
    trialFeatures.gazeStdY        = NaN(nTrials, 1);
    trialFeatures.fixationCount   = NaN(nTrials, 1);
    trialFeatures.fixationDurMean = NaN(nTrials, 1);
    trialFeatures.saccadeCount    = NaN(nTrials, 1);
    trialFeatures.saccadeAmpMean  = NaN(nTrials, 1);
    trialFeatures.scanPathLength  = NaN(nTrials, 1);
    trialFeatures.pupilSize       = NaN(nTrials, 1);
    trialFeatures.contAccuracy    = etData.continuousAccuracy(1:nTrials)';
    trialFeatures.reactionTime    = etData.reactionTime(1:nTrials)';

    for trl = 1:nTrials
        gx = etData.gazeX{trl};
        gy = etData.gazeY{trl};
        gp = etData.pupil{trl};

        % Valid (non-NaN) samples
        valid = isfinite(gx) & isfinite(gy);
        xv = double(gx(valid));
        yv = double(gy(valid));

        if numel(xv) < 10
            continue; % not enough data
        end

        %% BCEA (95%)
        sx = std(xv);
        sy = std(yv);
        rho = corr(xv(:), yv(:));
        trialFeatures.bcea95(trl) = 2 * k95 * pi * sx * sy * sqrt(1 - rho^2);

        %% Gaze Deviation (Euclidean distance from center)
        dx = xv - centreX;
        dy = yv - centreY;
        eucDist = sqrt(dx.^2 + dy.^2);
        trialFeatures.gazeDeviation(trl) = mean(eucDist);

        %% Gaze Dispersion (SD)
        trialFeatures.gazeStdX(trl) = sx;
        trialFeatures.gazeStdY(trl) = sy;

        %% Scan Path Length
        dxs = diff(xv);
        dys = diff(yv);
        trialFeatures.scanPathLength(trl) = sum(sqrt(dxs.^2 + dys.^2));

        %% Pupil Size
        validPupil = gp(valid);
        trialFeatures.pupilSize(trl) = mean(validPupil(isfinite(validPupil))) / 1000;

        %% Time on Target (distractor)
        if etData.crossPresent(trl) == 1 && ~isempty(etData.distractorPos{trl})
            dPos = etData.distractorPos{trl}; % N×2 [x, y]
            nSamples = numel(gx);
            tGaze = etData.time{trl}(:);
            if numel(tGaze) ~= nSamples
                tGaze = linspace(0, stim_duration, nSamples)';
            end

            nDistSamples = size(dPos, 1);
            if nDistSamples > 0
                % Align distractor to gaze timeline using recorded PTB timestamps when
                % available (first sample is at stimulus onset in IAB_task.m).
                if isfield(etData, 'distractorTime') && ~isempty(etData.distractorTime{trl})
                    dTime = etData.distractorTime{trl}(:);
                    if numel(dTime) ~= nDistSamples
                        dTrel = linspace(0, stim_duration, nDistSamples);
                    else
                        dTrel = dTime - dTime(1);
                    end
                else
                    dTrel = linspace(0, stim_duration, nDistSamples);
                end

                xD = interp1(dTrel, dPos(:, 1), tGaze, 'linear', 'extrap');
                yD = interp1(dTrel, dPos(:, 2), tGaze, 'linear', 'extrap');
                gxRow = gx(:)';
                gyRow = gy(:)';
                xD = xD(:)';
                yD = yD(:)';
                distToTarget = hypot(gxRow - xD, gyRow - yD);
                validRow = isfinite(gxRow) & isfinite(gyRow);
                onTarget = distToTarget <= tot_radius_px & validRow;
                trialFeatures.timeOnTarget(trl) = sum(onTarget) / sum(validRow) * 100; % percentage
            end
        end

        %% Fixation metrics (from Eyelink events)
        if ~isempty(etData.fixations{trl})
            fixArr = etData.fixations{trl};
            trialFeatures.fixationCount(trl) = length(fixArr);
            trialFeatures.fixationDurMean(trl) = mean([fixArr.duration]);
        else
            trialFeatures.fixationCount(trl) = 0;
            trialFeatures.fixationDurMean(trl) = NaN;
        end

        %% Saccade metrics (from Eyelink events)
        if ~isempty(etData.saccades{trl})
            saccArr = etData.saccades{trl};
            trialFeatures.saccadeCount(trl) = length(saccArr);
            trialFeatures.saccadeAmpMean(trl) = mean([saccArr.amplitude]);
        else
            trialFeatures.saccadeCount(trl) = 0;
            trialFeatures.saccadeAmpMean(trl) = NaN;
        end
    end

    %% Save per-subject features
    outFile = fullfile(DATA_PATH, subjID, 'features_IAB.mat');
    save(outFile, 'trialFeatures');
    fprintf('  Saved: %s\n', outFile);

    %% Aggregate into condition-level means for group analysis
    % Condition 1: distractor absent, Condition 2: distractor present
    for cond = 0:1
        idx = trialFeatures.crossPresent == cond;
        if sum(idx) == 0; continue; end

        row = struct();
        row.subjectID     = str2double(subjID);
        row.group         = strcmp(etData.group, 'B'); % 0=A, 1=B
        row.groupName     = etData.groupName;
        row.crossPresent  = cond;
        row.nTrials       = sum(idx);
        row.bcea95        = nanmean(trialFeatures.bcea95(idx));
        row.timeOnTarget  = nanmean(trialFeatures.timeOnTarget(idx));
        row.gazeDeviation = nanmean(trialFeatures.gazeDeviation(idx));
        row.gazeStdX      = nanmean(trialFeatures.gazeStdX(idx));
        row.gazeStdY      = nanmean(trialFeatures.gazeStdY(idx));
        row.fixationCount = nanmean(trialFeatures.fixationCount(idx));
        row.fixationDur   = nanmean(trialFeatures.fixationDurMean(idx));
        row.saccadeCount  = nanmean(trialFeatures.saccadeCount(idx));
        row.saccadeAmp    = nanmean(trialFeatures.saccadeAmpMean(idx));
        row.scanPathLen   = nanmean(trialFeatures.scanPathLength(idx));
        row.pupilSize     = nanmean(trialFeatures.pupilSize(idx));
        row.contAccuracy  = nanmean(trialFeatures.contAccuracy(idx));
        row.rt            = nanmean(trialFeatures.reactionTime(idx));

        allFeatures = [allFeatures; row];
    end

    clc;
    fprintf('Feature extraction: Subject %s done (%d/%d).\n', subjID, s, length(subjects));
end

%% Save group-level features
save(fullfile(DATA_PATH, 'features_all.mat'), 'allFeatures');
fprintf('\n=== Feature extraction complete ===\n');
fprintf('Saved group-level features: %s\n', fullfile(DATA_PATH, 'features_all.mat'));

%% Print summary
fprintf('\n--- Summary ---\n');
fprintf('Subjects processed: %d\n', length(unique([allFeatures.subjectID])));
groupA = [allFeatures([allFeatures.group] == 0)];
groupB = [allFeatures([allFeatures.group] == 1)];
fprintf('Group A (Focused):  %d subjects\n', length(unique([groupA.subjectID])));
fprintf('Group B (Expanded): %d subjects\n', length(unique([groupB.subjectID])));
