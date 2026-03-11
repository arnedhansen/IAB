%% IAB Behavioral Data Analysis
% Loads raw .mat files, computes accuracy and RT by group and distractor
% condition, summarizes perception questions.
%
% Input:
%   /Volumes/g_psyplafor_methlab_data$/OCC/IAB/[subjectID]/[subjectID]_IAB.mat
%
% Output:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/behavioral_summary.mat

%% Setup
clear; clc; close all;

RAW_PATH  = '/Volumes/g_psyplafor_methlab_data$/OCC/IAB/';
OUT_PATH  = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';

subjects = 201:220;

% Preallocate
behavData  = [];
perception = [];

%% Load behavioral data from all subjects
for s = 1:length(subjects)
    subjID = num2str(subjects(s));
    matFile = fullfile(RAW_PATH, subjID, [subjID '_IAB.mat']);

    if ~exist(matFile, 'file')
        fprintf('No data for subject %s — skipping.\n', subjID);
        continue;
    end

    fprintf('Loading subject %s...\n', subjID);
    behav = load(matFile);
    data    = behav.saves.data;
    subject = behav.saves.subject;

    nTrials = length(data.correctSum);
    groupCode = strcmp(subject.group, 'B'); % 0=A, 1=B

    %% Per-trial behavioral data
    for trl = 1:nTrials
        row = struct();
        row.subjectID       = str2double(subjID);
        row.group           = groupCode;
        row.groupName       = subject.groupName;
        row.trial           = trl;
        row.crossPresent    = data.crossPresent(trl);
        row.correctSum      = data.correctSum(trl);
        row.participantSum  = data.participantSum(trl);
        row.contAccuracy    = data.continuousAccuracy(trl);
        row.reactionTime    = data.reactionTime(trl);
        row.trialDuration   = data.trialDuration(trl);

        % Digit info
        if iscell(data.digits)
            row.nDigits = length(data.digits{trl});
            row.nBlack  = sum(data.digitColors{trl} == 1);
            row.nWhite  = sum(data.digitColors{trl} == 0);
        end

        behavData = [behavData; row];
    end

    %% Perception data
    if isfield(behav.saves, 'perceptionData')
        pd = behav.saves.perceptionData;
        pRow = struct();
        pRow.subjectID = str2double(subjID);
        pRow.group     = groupCode;
        pRow.groupName = subject.groupName;
        pRow.Q1_unusual     = pd.Q1; % Noticed something unusual?
        pRow.Q2_besides     = pd.Q2; % Seen something besides numbers?
        pRow.Q3_object      = pd.Q3; % Noticed a non-number object?
        if isfield(pd, 'Q4')
            pRow.Q4_freetext = pd.Q4; % Free text description
        else
            pRow.Q4_freetext = '';
        end
        if isfield(pd, 'Q5')
            pRow.Q5_monkey = pd.Q5; % Saw the monkey?
        else
            pRow.Q5_monkey = NaN;
        end
        perception = [perception; pRow];
    end
end

%% Compute summary statistics
fprintf('\n====================================\n');
fprintf('  BEHAVIORAL SUMMARY\n');
fprintf('====================================\n');

allSubjects = unique([behavData.subjectID]);
nSubj = length(allSubjects);
fprintf('Total subjects: %d\n\n', nSubj);

%% Group-level accuracy and RT
fprintf('--- Accuracy & RT by Group ---\n');
for g = 0:1
    if g == 0; gName = 'Group A (Focused)'; else; gName = 'Group B (Expanded)'; end
    gIdx = [behavData.group] == g;
    gData = behavData(gIdx);

    fprintf('\n%s (n=%d subjects):\n', gName, length(unique([gData.subjectID])));

    % Overall
    fprintf('  Overall:\n');
    fprintf('    Accuracy: %.1f%% (SD = %.1f)\n', ...
        nanmean([gData.contAccuracy]), nanstd([gData.contAccuracy]));
    fprintf('    Reaction Time: %.2f s (SD = %.2f)\n', ...
        nanmean([gData.reactionTime]), nanstd([gData.reactionTime]));

    % By distractor condition
    for c = 0:1
        if c == 0; cName = 'No Distractor'; else; cName = 'Distractor Present'; end
        cIdx = [gData.crossPresent] == c;
        cData = gData(cIdx);
        fprintf('  %s:\n', cName);
        fprintf('    Accuracy: %.1f%% (SD = %.1f)\n', ...
            nanmean([cData.contAccuracy]), nanstd([cData.contAccuracy]));
        fprintf('    Reaction Time: %.2f s (SD = %.2f)\n', ...
            nanmean([cData.reactionTime]), nanstd([cData.reactionTime]));
    end
end

%% Group-level accuracy per subject (for stats)
subjMeans = struct();
for si = 1:nSubj
    sIdx = [behavData.subjectID] == allSubjects(si);
    sData = behavData(sIdx);

    subjMeans(si).subjectID      = allSubjects(si);
    subjMeans(si).group          = sData(1).group;
    subjMeans(si).groupName      = sData(1).groupName;

    % Overall
    subjMeans(si).contAccuracy   = nanmean([sData.contAccuracy]);
    subjMeans(si).rt             = nanmean([sData.reactionTime]);

    % By distractor
    noD = sData([sData.crossPresent] == 0);
    yesD = sData([sData.crossPresent] == 1);
    subjMeans(si).contAcc_noDist    = nanmean([noD.contAccuracy]);
    subjMeans(si).contAcc_dist      = nanmean([yesD.contAccuracy]);
    subjMeans(si).rt_noDist         = nanmean([noD.reactionTime]);
    subjMeans(si).rt_dist           = nanmean([yesD.reactionTime]);
end

%% Perception question summary
fprintf('\n--- Perception Questions ---\n');
if ~isempty(perception)
    for g = 0:1
        if g == 0; gName = 'Group A (Focused)'; else; gName = 'Group B (Expanded)'; end
        gIdx = [perception.group] == g;
        gPerc = perception(gIdx);
        n = length(gPerc);
        fprintf('\n%s (n=%d):\n', gName, n);
        fprintf('  Q1 (Noticed unusual):   %d/%d (%.0f%%)\n', ...
            sum([gPerc.Q1_unusual]), n, sum([gPerc.Q1_unusual])/n*100);
        fprintf('  Q2 (Seen besides nums): %d/%d (%.0f%%)\n', ...
            sum([gPerc.Q2_besides]), n, sum([gPerc.Q2_besides])/n*100);
        fprintf('  Q3 (Non-number object): %d/%d (%.0f%%)\n', ...
            sum([gPerc.Q3_object]), n, sum([gPerc.Q3_object])/n*100);
        fprintf('  Q4 (Free text):\n');
        for p = 1:length(gPerc)
            fprintf('    Sub %d: "%s"\n', gPerc(p).subjectID, gPerc(p).Q4_freetext);
        end
        q5vals = [gPerc.Q5_monkey];
        q5vals = q5vals(~isnan(q5vals));
        fprintf('  Q5 (Saw monkey):        %d/%d (%.0f%%)\n', ...
            sum(q5vals), length(q5vals), sum(q5vals)/max(1,length(q5vals))*100);
    end
end

%% Statistical tests on behavioral data
fprintf('\n--- Statistical Tests ---\n');

% Accuracy: Group comparison (t-test)
groupA_acc = [subjMeans([subjMeans.group] == 0).contAccuracy];
groupB_acc = [subjMeans([subjMeans.group] == 1).contAccuracy];
if length(groupA_acc) > 1 && length(groupB_acc) > 1
    [~, p_acc, ~, stats_acc] = ttest2(groupA_acc, groupB_acc);
    d_acc = (mean(groupA_acc) - mean(groupB_acc)) / ...
            sqrt((var(groupA_acc) + var(groupB_acc)) / 2);
    fprintf('Continuous Accuracy: Group A = %.1f%%, Group B = %.1f%%\n', ...
        mean(groupA_acc), mean(groupB_acc));
    fprintf('  t(%d) = %.3f, p = %.4f, Cohen''s d = %.3f\n', ...
        stats_acc.df, stats_acc.tstat, p_acc, d_acc);
end

% RT: Group comparison
groupA_rt = [subjMeans([subjMeans.group] == 0).rt];
groupB_rt = [subjMeans([subjMeans.group] == 1).rt];
if length(groupA_rt) > 1 && length(groupB_rt) > 1
    [~, p_rt, ~, stats_rt] = ttest2(groupA_rt, groupB_rt);
    d_rt = (mean(groupA_rt) - mean(groupB_rt)) / ...
           sqrt((var(groupA_rt) + var(groupB_rt)) / 2);
    fprintf('Reaction Time: Group A = %.2f s, Group B = %.2f s\n', ...
        mean(groupA_rt), mean(groupB_rt));
    fprintf('  t(%d) = %.3f, p = %.4f, Cohen''s d = %.3f\n', ...
        stats_rt.df, stats_rt.tstat, p_rt, d_rt);
end

% Perception Q5 (monkey detection): Fisher exact / chi-square
if ~isempty(perception)
    gA_q5 = [perception([perception.group] == 0).Q5_monkey];
    gB_q5 = [perception([perception.group] == 1).Q5_monkey];
    gA_q5 = gA_q5(~isnan(gA_q5));
    gB_q5 = gB_q5(~isnan(gB_q5));
    if ~isempty(gA_q5) && ~isempty(gB_q5)
        observed = [sum(gA_q5), length(gA_q5) - sum(gA_q5); ...
                    sum(gB_q5), length(gB_q5) - sum(gB_q5)];
        fprintf('\nMonkey Detection (Q5):\n');
        fprintf('  Group A: %d/%d (%.0f%%)\n', sum(gA_q5), length(gA_q5), mean(gA_q5)*100);
        fprintf('  Group B: %d/%d (%.0f%%)\n', sum(gB_q5), length(gB_q5), mean(gB_q5)*100);
        n_total = sum(observed(:));
        chi2 = 0;
        for r = 1:2
            for c = 1:2
                expected = sum(observed(r,:)) * sum(observed(:,c)) / n_total;
                if expected > 0
                    chi2 = chi2 + (observed(r,c) - expected)^2 / expected;
                end
            end
        end
        p_chi2 = 1 - chi2cdf(chi2, 1);
        fprintf('  Chi-square(1) = %.3f, p = %.4f\n', chi2, p_chi2);
    end
end

%% Save
behavioral_summary = struct();
behavioral_summary.behavData   = behavData;
behavioral_summary.subjMeans   = subjMeans;
behavioral_summary.perception  = perception;

save(fullfile(OUT_PATH, 'behavioral_summary.mat'), 'behavioral_summary');
fprintf('\nSaved: %s\n', fullfile(OUT_PATH, 'behavioral_summary.mat'));
