%% IAB Eye-Tracking Visualization
% Creates all plots for the IAB study. Run after feature extraction and
% behavioral analysis.
%
% Plots:
%   1. BCEA ellipse overlay (Group A vs B, pooled gaze)
%   2. Bar plots: ET metrics by Group x Distractor
%   3. Gaze heatmaps by group
%   4. Behavioral summary (accuracy, RT)
%   5. Perception question summary
%   6. Time on Target by group
%
% Input:
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/features_all.mat
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/behavioral_summary.mat
%   /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/[subjectID]/etData_IAB.mat
%
% Output:
%   Figures saved to /Volumes/g_psyplafor_methlab$/Students/Arne/IAB/figures/

%% Setup
clear; clc; close all;

DATA_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';
FIG_PATH  = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/figures/';
if ~exist(FIG_PATH, 'dir'); mkdir(FIG_PATH); end

% Load data
load(fullfile(DATA_PATH, 'features_all.mat'), 'allFeatures');
load(fullfile(DATA_PATH, 'behavioral_summary.mat'), 'behavioral_summary');

% Screen parameters
screenW = 800; screenH = 600;
centreX = 400; centreY = 300;

% Colors
colA = [0.2 0.4 0.8]; % Blue for Group A (Focused)
colB = [0.8 0.3 0.2]; % Red for Group B (Expanded)
colors = [colA; colB];
groupLabels = {'Group A (Focused)', 'Group B (Expanded)'};

fontSize = 18;
subjects = 201:220;

%% ========================================================================
%  1. BCEA ELLIPSE OVERLAY
%  ========================================================================
fprintf('Plotting BCEA ellipses...\n');

P95 = 0.95;
k95 = -log(1 - P95);
theta = linspace(0, 2*pi, 200);

figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w'); hold on;
legendHandles = gobjects(1, 2);

for g = 0:1
    gCol = colors(g+1, :);

    % Pool all gaze data for this group across all subjects and trials
    all_x = []; all_y = [];

    for s = 1:length(subjects)
        subjID = num2str(subjects(s));
        etFile = fullfile(DATA_PATH, subjID, 'etData_IAB.mat');
        if ~exist(etFile, 'file'); continue; end
        load(etFile, 'etData');
        if strcmp(etData.group, 'B') ~= g; continue; end

        for trl = 1:length(etData.gazeX)
            gx = etData.gazeX{trl};
            gy = etData.gazeY{trl};
            valid = isfinite(gx) & isfinite(gy);
            all_x = [all_x, gx(valid)];
            all_y = [all_y, gy(valid)];
        end
    end

    if numel(all_x) < 10; continue; end

    % Compute BCEA ellipse
    mx = mean(all_x); my = mean(all_y);
    sx = std(all_x);  sy = std(all_y);
    rho = corr(double(all_x(:)), double(all_y(:)));
    cov_mat = [sx^2, rho*sx*sy; rho*sx*sy, sy^2];
    [V, D] = eig(cov_mat);

    % Draw 95% ellipse
    r = sqrt(2 * k95 * diag(D));
    ell = V * [r(1)*cos(theta); r(2)*sin(theta)];
    ex = ell(1,:) + mx; ey = ell(2,:) + my;

    fill(ex, ey, gCol, 'FaceAlpha', 0.15, 'EdgeColor', gCol, 'LineWidth', 2.5);
    legendHandles(g+1) = plot(ex, ey, '-', 'Color', gCol, 'LineWidth', 2.5);
end

plot(centreX, centreY, '+', 'MarkerSize', 20, 'LineWidth', 2.5, 'Color', 'k');
rectangle('Position', [0 0 screenW screenH], 'EdgeColor', [0.5 0.5 0.5], ...
    'LineWidth', 1, 'LineStyle', '--');
xlim([-20 screenW+20]); ylim([-20 screenH+20]);
set(gca, 'YDir', 'normal', 'FontSize', fontSize);
xlabel('Screen X [px]', 'FontSize', fontSize);
ylabel('Screen Y [px]', 'FontSize', fontSize);
title('BCEA (95%) by Group', 'FontSize', fontSize+2);
legend(legendHandles, groupLabels, 'FontSize', fontSize-2, 'Location', 'northeast');
axis equal; xlim([-20 screenW+20]); ylim([-20 screenH+20]);
hold off;
saveas(gcf, fullfile(FIG_PATH, 'IAB_BCEA_ellipse.png'));

%% ========================================================================
%  2. BAR PLOTS: ET METRICS BY GROUP x DISTRACTOR
%  ========================================================================
fprintf('Plotting ET metric bar plots...\n');

dvNames = {'bcea95', 'gazeDeviation', 'gazeStdX', 'gazeStdY', ...
           'fixationCount', 'fixationDur', 'saccadeCount', 'saccadeAmp', ...
           'scanPathLen', 'pupilSize'};
dvLabels = {'BCEA 95% [px^2]', 'Gaze Deviation [px]', 'Gaze Std X [px]', ...
            'Gaze Std Y [px]', 'Fixation Count', 'Fixation Duration [ms]', ...
            'Saccade Count', 'Saccade Amplitude [deg]', ...
            'Scan Path Length [px]', 'Pupil Size [a.u.]'};

for d = 1:length(dvNames)
    dv = dvNames{d};
    label = dvLabels{d};

    figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w'); hold on;

    barData = NaN(2, 2); % group x condition
    barSEM  = NaN(2, 2);

    for g = 0:1
        for c = 0:1
            idx = [allFeatures.group] == g & [allFeatures.crossPresent] == c;
            vals = [allFeatures(idx).(dv)];
            vals = vals(~isnan(vals));
            barData(g+1, c+1) = mean(vals);
            barSEM(g+1, c+1)  = std(vals) / sqrt(length(vals));
        end
    end

    b = bar(barData, 'grouped');
    b(1).FaceColor = [0.7 0.7 0.7]; % No distractor
    b(2).FaceColor = [0.3 0.3 0.3]; % Distractor present

    % Add error bars
    nGroups = size(barData, 1);
    nBars = size(barData, 2);
    groupWidth = min(0.8, nBars/(nBars + 1.5));
    for i = 1:nBars
        x = (1:nGroups) - groupWidth/2 + (2*i-1) * groupWidth / (2*nBars);
        errorbar(x, barData(:,i), barSEM(:,i), 'k.', 'LineWidth', 1.5);
    end

    set(gca, 'XTick', 1:2, 'XTickLabel', {'Group A\n(Focused)', 'Group B\n(Expanded)'}, 'FontSize', fontSize-2);
    ylabel(label, 'FontSize', fontSize);
    title(strrep(dv, '_', ' '), 'FontSize', fontSize);
    legend({'No Distractor', 'Distractor Present'}, 'FontSize', fontSize-4, 'Location', 'best');
    box off; hold off;

    saveas(gcf, fullfile(FIG_PATH, ['IAB_bar_' dv '.png']));
    close;
end

%% ========================================================================
%  3. GAZE HEATMAPS BY GROUP
%  ========================================================================
fprintf('Plotting gaze heatmaps...\n');

figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');

for g = 0:1
    subplot(1, 2, g+1);

    all_x = []; all_y = [];
    for s = 1:length(subjects)
        subjID = num2str(subjects(s));
        etFile = fullfile(DATA_PATH, subjID, 'etData_IAB.mat');
        if ~exist(etFile, 'file'); continue; end
        load(etFile, 'etData');
        if strcmp(etData.group, 'B') ~= g; continue; end

        for trl = 1:length(etData.gazeX)
            gx = etData.gazeX{trl};
            gy = etData.gazeY{trl};
            valid = isfinite(gx) & isfinite(gy);
            all_x = [all_x, gx(valid)];
            all_y = [all_y, gy(valid)];
        end
    end

    if isempty(all_x); continue; end

    % Create 2D histogram
    nBins = 50;
    xEdges = linspace(0, screenW, nBins+1);
    yEdges = linspace(0, screenH, nBins+1);
    H = histcounts2(all_x, all_y, xEdges, yEdges);
    H = H / max(H(:)); % Normalize

    % Smooth
    kernel = fspecial('gaussian', [5 5], 1.5);
    H = imfilter(H, kernel);

    imagesc(xEdges(1:end-1), yEdges(1:end-1), H');
    set(gca, 'YDir', 'normal');
    colormap(hot); colorbar;
    hold on;
    plot(centreX, centreY, '+w', 'MarkerSize', 15, 'LineWidth', 2);
    hold off;
    xlabel('X [px]', 'FontSize', fontSize-2);
    ylabel('Y [px]', 'FontSize', fontSize-2);
    title(groupLabels{g+1}, 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize-2);
    axis equal; xlim([0 screenW]); ylim([0 screenH]);
end

sgtitle('Gaze Heatmaps', 'FontSize', fontSize+2);
saveas(gcf, fullfile(FIG_PATH, 'IAB_gaze_heatmaps.png'));

%% ========================================================================
%  4. BEHAVIORAL SUMMARY (Accuracy & RT)
%  ========================================================================
fprintf('Plotting behavioral summary...\n');

subjMeans = behavioral_summary.subjMeans;

figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');

% Accuracy
subplot(1, 2, 1); hold on;
for g = 0:1
    gIdx = [subjMeans.group] == g;
    vals = [subjMeans(gIdx).contAccuracy];
    bar(g+1, mean(vals), 'FaceColor', colors(g+1,:), 'FaceAlpha', 0.6, 'EdgeColor', 'k');
    errorbar(g+1, mean(vals), std(vals)/sqrt(length(vals)), 'k.', 'LineWidth', 2);
    % Individual dots
    scatter(repmat(g+1, 1, length(vals)) + 0.1*(rand(1,length(vals))-0.5), vals, ...
        40, colors(g+1,:), 'filled', 'MarkerFaceAlpha', 0.5);
end
set(gca, 'XTick', 1:2, 'XTickLabel', {'Group A', 'Group B'}, 'FontSize', fontSize-2);
ylabel('Continuous Accuracy (%)', 'FontSize', fontSize);
title('Accuracy by Group', 'FontSize', fontSize);
box off; hold off;

% Reaction Time
subplot(1, 2, 2); hold on;
for g = 0:1
    gIdx = [subjMeans.group] == g;
    vals = [subjMeans(gIdx).rt];
    bar(g+1, mean(vals), 'FaceColor', colors(g+1,:), 'FaceAlpha', 0.6, 'EdgeColor', 'k');
    errorbar(g+1, mean(vals), std(vals)/sqrt(length(vals)), 'k.', 'LineWidth', 2);
    scatter(repmat(g+1, 1, length(vals)) + 0.1*(rand(1,length(vals))-0.5), vals, ...
        40, colors(g+1,:), 'filled', 'MarkerFaceAlpha', 0.5);
end
set(gca, 'XTick', 1:2, 'XTickLabel', {'Group A', 'Group B'}, 'FontSize', fontSize-2);
ylabel('Reaction Time [s]', 'FontSize', fontSize);
title('RT by Group', 'FontSize', fontSize);
box off; hold off;

saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_summary.png'));

%% ========================================================================
%  5. PERCEPTION QUESTIONS
%  ========================================================================
fprintf('Plotting perception questions...\n');

perc = behavioral_summary.perception;
if ~isempty(perc)
    figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w'); hold on;

    qLabels = {'Q1: Unusual', 'Q2: Besides nums', 'Q3: Non-num object', 'Q5: Saw monkey'};
    qFields = {'Q1_unusual', 'Q2_besides', 'Q3_object', 'Q5_monkey'};

    barPct = NaN(2, length(qFields));
    for g = 0:1
        gIdx = [perc.group] == g;
        gPerc = perc(gIdx);
        for q = 1:length(qFields)
            vals = [gPerc.(qFields{q})];
            vals = vals(~isnan(vals));
            if ~isempty(vals)
                barPct(g+1, q) = mean(vals) * 100;
            end
        end
    end

    b = bar(barPct', 'grouped');
    b(1).FaceColor = colA;
    b(2).FaceColor = colB;

    set(gca, 'XTick', 1:length(qLabels), 'XTickLabel', qLabels, 'FontSize', fontSize-4);
    ylabel('% Yes', 'FontSize', fontSize);
    title('Perception Questions by Group', 'FontSize', fontSize);
    legend(groupLabels, 'FontSize', fontSize-4, 'Location', 'best');
    ylim([0 105]);
    box off; hold off;

    saveas(gcf, fullfile(FIG_PATH, 'IAB_perception_questions.png'));
end

%% ========================================================================
%  6. TIME ON TARGET BY GROUP
%  ========================================================================
fprintf('Plotting time on target...\n');

figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w'); hold on;

for g = 0:1
    idx = [allFeatures.group] == g & [allFeatures.crossPresent] == 1;
    vals = [allFeatures(idx).timeOnTarget];
    vals = vals(~isnan(vals));
    bar(g+1, mean(vals), 'FaceColor', colors(g+1,:), 'FaceAlpha', 0.6, 'EdgeColor', 'k');
    errorbar(g+1, mean(vals), std(vals)/sqrt(length(vals)), 'k.', 'LineWidth', 2);
    scatter(repmat(g+1, 1, length(vals)) + 0.1*(rand(1,length(vals))-0.5), vals, ...
        40, colors(g+1,:), 'filled', 'MarkerFaceAlpha', 0.5);
end

set(gca, 'XTick', 1:2, 'XTickLabel', {'Group A\n(Focused)', 'Group B\n(Expanded)'}, ...
    'FontSize', fontSize-2);
ylabel('Time on Target [%]', 'FontSize', fontSize);
title('Time on Target (Distractor Trials)', 'FontSize', fontSize);
box off; hold off;

saveas(gcf, fullfile(FIG_PATH, 'IAB_time_on_target.png'));

%% Done
fprintf('\n=== All figures saved to: %s ===\n', FIG_PATH);
close all;
