%% IAB Eye-Tracking Statistical Analysis
% Runs 2x2 mixed ANOVAs (Group x Distractor Presence) on all ET metrics.
%   Between-subjects factor: Group (A = Focused, B = Expanded)
%   Within-subjects factor: Distractor (0 = absent, 1 = present)
%
% Dependent variables:
%   BCEA (95%), Time on Target, Gaze Deviation, Gaze Dispersion (X, Y),
%   Fixation Count, Fixation Duration, Saccade Count, Saccade Amplitude,
%   Scan Path Length, Pupil Size
%
% Reports: F-statistics, p-values, partial eta-squared, post-hoc t-tests
%
% Input:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/features_all.mat
%
% Output:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/stats_results.mat

%% Setup
clear; clc; close all;

DATA_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';
load(fullfile(DATA_PATH, 'features_all.mat'), 'allFeatures');

%% Build subject-level data table for ANOVA
% Each subject has 2 rows: distractor absent (0) and present (1)
allSubjects = unique([allFeatures.subjectID]);
nSubj = length(allSubjects);

fprintf('=== IAB Eye-Tracking Statistical Analysis ===\n');
fprintf('Subjects: %d\n', nSubj);
fprintf('Group A (Focused):  %d\n', sum([allFeatures([allFeatures.crossPresent] == 0).group] == 0));
fprintf('Group B (Expanded): %d\n', sum([allFeatures([allFeatures.crossPresent] == 0).group] == 1));

%% Create data matrix for each DV
% Format: rows = subjects, columns = [distractor_absent, distractor_present]

dvNames = {'bcea95', 'timeOnTarget', 'gazeDeviation', 'gazeStdX', 'gazeStdY', ...
           'fixationCount', 'fixationDur', 'saccadeCount', 'saccadeAmp', ...
           'scanPathLen', 'pupilSize'};
dvLabels = {'BCEA 95%', 'Time on Target (%)', 'Gaze Deviation (px)', ...
            'Gaze Std X (px)', 'Gaze Std Y (px)', ...
            'Fixation Count', 'Fixation Duration (ms)', ...
            'Saccade Count', 'Saccade Amplitude (deg)', ...
            'Scan Path Length (px)', 'Pupil Size (a.u.)'};

% Group vector (0 = A, 1 = B) per subject
groupVec = zeros(nSubj, 1);

% Data matrices: nSubj x 2 (col1 = no distractor, col2 = distractor)
dataMat = struct();
for d = 1:length(dvNames)
    dataMat.(dvNames{d}) = NaN(nSubj, 2);
end

for si = 1:nSubj
    sID = allSubjects(si);
    sIdx = [allFeatures.subjectID] == sID;
    sData = allFeatures(sIdx);

    groupVec(si) = sData(1).group;

    for cond = 0:1
        cIdx = [sData.crossPresent] == cond;
        if ~any(cIdx); continue; end
        cData = sData(cIdx);
        col = cond + 1; % column 1 = absent, column 2 = present

        for d = 1:length(dvNames)
            dataMat.(dvNames{d})(si, col) = cData.(dvNames{d});
        end
    end
end

%% Run 2x2 Mixed ANOVAs
fprintf('\n====================================================================\n');
fprintf('  2x2 MIXED ANOVA: Group (A/B) x Distractor (Absent/Present)\n');
fprintf('====================================================================\n');

statsResults = struct();

for d = 1:length(dvNames)
    dv = dvNames{d};
    Y = dataMat.(dv);
    label = dvLabels{d};

    % Skip time-on-target for distractor-absent condition (always NaN)
    if strcmp(dv, 'timeOnTarget')
        fprintf('\n--- %s ---\n', label);
        fprintf('  (Only computed for distractor-present trials)\n');

        % Simple Group comparison (t-test on distractor-present only)
        groupA_vals = Y(groupVec == 0, 2);
        groupB_vals = Y(groupVec == 1, 2);
        groupA_vals = groupA_vals(~isnan(groupA_vals));
        groupB_vals = groupB_vals(~isnan(groupB_vals));

        if length(groupA_vals) > 1 && length(groupB_vals) > 1
            [~, p, ~, stats] = ttest2(groupA_vals, groupB_vals);
            cohens_d = (mean(groupA_vals) - mean(groupB_vals)) / ...
                       sqrt((var(groupA_vals) + var(groupB_vals)) / 2);
            fprintf('  Group A: M = %.2f, SD = %.2f\n', mean(groupA_vals), std(groupA_vals));
            fprintf('  Group B: M = %.2f, SD = %.2f\n', mean(groupB_vals), std(groupB_vals));
            fprintf('  t(%d) = %.3f, p = %.4f, d = %.3f\n', stats.df, stats.tstat, p, cohens_d);

            statsResults.(dv).test = 'ttest2';
            statsResults.(dv).t    = stats.tstat;
            statsResults.(dv).df   = stats.df;
            statsResults.(dv).p    = p;
            statsResults.(dv).d    = cohens_d;
            statsResults.(dv).meanA = mean(groupA_vals);
            statsResults.(dv).meanB = mean(groupB_vals);
        end
        continue;
    end

    fprintf('\n--- %s ---\n', label);

    % Remove subjects with NaN in either condition
    validSubj = ~isnan(Y(:,1)) & ~isnan(Y(:,2));
    Yv = Y(validSubj, :);
    Gv = groupVec(validSubj);
    nv = sum(validSubj);

    if nv < 4
        fprintf('  Insufficient data (n=%d). Skipping.\n', nv);
        continue;
    end

    nA = sum(Gv == 0);
    nB = sum(Gv == 1);

    %% Compute 2x2 mixed ANOVA manually
    % Grand mean
    GM = mean(Yv(:));

    % Group means
    meanA = mean(Yv(Gv == 0, :), 'all');
    meanB = mean(Yv(Gv == 1, :), 'all');

    % Condition means (within-subject)
    meanAbsent  = mean(Yv(:, 1));
    meanPresent = mean(Yv(:, 2));

    % Cell means
    cellMeans = zeros(2, 2); % group x condition
    cellMeans(1, 1) = mean(Yv(Gv == 0, 1)); % A, absent
    cellMeans(1, 2) = mean(Yv(Gv == 0, 2)); % A, present
    cellMeans(2, 1) = mean(Yv(Gv == 1, 1)); % B, absent
    cellMeans(2, 2) = mean(Yv(Gv == 1, 2)); % B, present

    % Subject means (across conditions)
    subjMeans = mean(Yv, 2);

    % SS Between (Group effect)
    SS_group = 2 * (nA * (meanA - GM)^2 + nB * (meanB - GM)^2);
    df_group = 1;

    % SS Within-subjects error (for between-subjects effect)
    SS_subj_within = 0;
    for si = 1:nv
        g = Gv(si) + 1; % 1 or 2
        gMean = [meanA, meanB];
        SS_subj_within = SS_subj_within + 2 * (subjMeans(si) - gMean(g))^2;
    end
    df_subj_within = nv - 2;

    % SS Condition (within-subjects)
    SS_cond = nv * ((meanAbsent - GM)^2 + (meanPresent - GM)^2);
    df_cond = 1;

    % SS Interaction (Group x Condition)
    SS_interact = 0;
    for g = 1:2
        for c = 1:2
            gMean = [meanA, meanB];
            cMean = [meanAbsent, meanPresent];
            SS_interact = SS_interact + sum(Gv == (g-1)) * ...
                (cellMeans(g,c) - gMean(g) - cMean(c) + GM)^2;
        end
    end
    df_interact = 1;

    % SS Error (within-subjects x condition interaction residual)
    SS_error_within = 0;
    for si = 1:nv
        g = Gv(si) + 1;
        for c = 1:2
            cMean = [meanAbsent, meanPresent];
            SS_error_within = SS_error_within + ...
                (Yv(si, c) - subjMeans(si) - cellMeans(g, c) + [meanA, meanB] * [Gv(si)==0; Gv(si)==1])^2;
        end
    end
    df_error_within = nv - 2;

    % F-statistics
    MS_group    = SS_group / df_group;
    MS_subj_err = SS_subj_within / max(1, df_subj_within);
    MS_cond     = SS_cond / df_cond;
    MS_interact = SS_interact / df_interact;
    MS_error_w  = SS_error_within / max(1, df_error_within);

    F_group    = MS_group / MS_subj_err;
    F_cond     = MS_cond / MS_error_w;
    F_interact = MS_interact / MS_error_w;

    p_group    = 1 - fcdf(F_group, df_group, df_subj_within);
    p_cond     = 1 - fcdf(F_cond, df_cond, df_error_within);
    p_interact = 1 - fcdf(F_interact, df_interact, df_error_within);

    % Partial eta-squared
    eta2_group    = SS_group / (SS_group + SS_subj_within);
    eta2_cond     = SS_cond / (SS_cond + SS_error_within);
    eta2_interact = SS_interact / (SS_interact + SS_error_within);

    % Print results
    fprintf('  Cell means:\n');
    fprintf('    Group A: Absent = %.2f, Present = %.2f\n', cellMeans(1,1), cellMeans(1,2));
    fprintf('    Group B: Absent = %.2f, Present = %.2f\n', cellMeans(2,1), cellMeans(2,2));
    fprintf('  Main effect Group:     F(1,%d) = %.3f, p = %.4f, eta2p = %.3f\n', ...
        df_subj_within, F_group, p_group, eta2_group);
    fprintf('  Main effect Distractor: F(1,%d) = %.3f, p = %.4f, eta2p = %.3f\n', ...
        df_error_within, F_cond, p_cond, eta2_cond);
    fprintf('  Interaction:            F(1,%d) = %.3f, p = %.4f, eta2p = %.3f\n', ...
        df_error_within, F_interact, p_interact, eta2_interact);

    % Flag significance
    sigStr = '';
    if p_group < 0.05; sigStr = [sigStr ' *Group']; end
    if p_cond < 0.05; sigStr = [sigStr ' *Distractor']; end
    if p_interact < 0.05; sigStr = [sigStr ' *Interaction']; end
    if ~isempty(sigStr)
        fprintf('  SIGNIFICANT:%s\n', sigStr);
    end

    % Post-hoc t-tests if interaction is significant
    if p_interact < 0.05
        fprintf('  Post-hoc (interaction):\n');
        % Group A: absent vs present
        [~, p1, ~, s1] = ttest(Yv(Gv==0, 1), Yv(Gv==0, 2));
        fprintf('    Group A (absent vs present): t(%d) = %.3f, p = %.4f\n', s1.df, s1.tstat, p1);
        % Group B: absent vs present
        [~, p2, ~, s2] = ttest(Yv(Gv==1, 1), Yv(Gv==1, 2));
        fprintf('    Group B (absent vs present): t(%d) = %.3f, p = %.4f\n', s2.df, s2.tstat, p2);
        % Absent: Group A vs B
        [~, p3, ~, s3] = ttest2(Yv(Gv==0, 1), Yv(Gv==1, 1));
        fprintf('    Absent (A vs B): t(%d) = %.3f, p = %.4f\n', s3.df, s3.tstat, p3);
        % Present: Group A vs B
        [~, p4, ~, s4] = ttest2(Yv(Gv==0, 2), Yv(Gv==1, 2));
        fprintf('    Present (A vs B): t(%d) = %.3f, p = %.4f\n', s4.df, s4.tstat, p4);

        % Bonferroni correction
        pvals = [p1, p2, p3, p4];
        pvals_corr = min(pvals * 4, 1);
        fprintf('    Bonferroni-corrected: [%.4f, %.4f, %.4f, %.4f]\n', pvals_corr);
    end

    % Store results
    statsResults.(dv).F_group      = F_group;
    statsResults.(dv).p_group      = p_group;
    statsResults.(dv).eta2_group   = eta2_group;
    statsResults.(dv).F_cond       = F_cond;
    statsResults.(dv).p_cond       = p_cond;
    statsResults.(dv).eta2_cond    = eta2_cond;
    statsResults.(dv).F_interact   = F_interact;
    statsResults.(dv).p_interact   = p_interact;
    statsResults.(dv).eta2_interact = eta2_interact;
    statsResults.(dv).cellMeans    = cellMeans;
    statsResults.(dv).n            = nv;
    statsResults.(dv).nA           = nA;
    statsResults.(dv).nB           = nB;
end

%% Multiple comparison correction across DVs (Benjamini-Hochberg FDR)
fprintf('\n====================================================================\n');
fprintf('  FDR CORRECTION ACROSS DEPENDENT VARIABLES\n');
fprintf('====================================================================\n');

% Collect all p-values for Group effect
dvsUsed = {};
pvals_group = [];
pvals_cond = [];
pvals_inter = [];

for d = 1:length(dvNames)
    dv = dvNames{d};
    if isfield(statsResults, dv) && isfield(statsResults.(dv), 'p_group')
        dvsUsed{end+1} = dv;
        pvals_group(end+1) = statsResults.(dv).p_group;
        pvals_cond(end+1)  = statsResults.(dv).p_cond;
        pvals_inter(end+1) = statsResults.(dv).p_interact;
    end
end

% FDR correction (Benjamini-Hochberg)
fprintf('\nFDR-corrected p-values (Group effect):\n');
fdr_group = bh_fdr(pvals_group);
for d = 1:length(dvsUsed)
    sig = ''; if fdr_group(d) < 0.05; sig = ' *'; end
    fprintf('  %-25s p = %.4f -> p_fdr = %.4f%s\n', dvsUsed{d}, pvals_group(d), fdr_group(d), sig);
end

fprintf('\nFDR-corrected p-values (Distractor effect):\n');
fdr_cond = bh_fdr(pvals_cond);
for d = 1:length(dvsUsed)
    sig = ''; if fdr_cond(d) < 0.05; sig = ' *'; end
    fprintf('  %-25s p = %.4f -> p_fdr = %.4f%s\n', dvsUsed{d}, pvals_cond(d), fdr_cond(d), sig);
end

fprintf('\nFDR-corrected p-values (Interaction):\n');
fdr_inter = bh_fdr(pvals_inter);
for d = 1:length(dvsUsed)
    sig = ''; if fdr_inter(d) < 0.05; sig = ' *'; end
    fprintf('  %-25s p = %.4f -> p_fdr = %.4f%s\n', dvsUsed{d}, pvals_inter(d), fdr_inter(d), sig);
end

%% Save results
save(fullfile(DATA_PATH, 'stats_results.mat'), 'statsResults', 'dataMat', 'groupVec', 'allSubjects');
fprintf('\nSaved: %s\n', fullfile(DATA_PATH, 'stats_results.mat'));

%% ========================================================================
%  LOCAL FUNCTION: Benjamini-Hochberg FDR correction
%  ========================================================================
function p_fdr = bh_fdr(p_vals)
    m = length(p_vals);
    [p_sorted, sortIdx] = sort(p_vals);
    p_fdr = NaN(1, m);
    for i = m:-1:1
        if i == m
            p_fdr(sortIdx(i)) = p_sorted(i);
        else
            p_fdr(sortIdx(i)) = min(p_fdr(sortIdx(i+1)), p_sorted(i) * m / i);
        end
    end
    p_fdr = min(p_fdr, 1);
end
