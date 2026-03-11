%% IAB Eye-Tracking Visualization
% Creates all plots for the IAB study. Run after feature extraction and
% behavioral analysis.
%
% Plots:
%   1. BCEA ellipse overlay (Group A vs B, pooled gaze)
%   2. Boxplots: ET metrics by Group x Distractor
%   3. Gaze heatmaps by group
%   4. Behavioral summary boxplots (accuracy, RT)
%   5. Perception question boxplots
%   6. Time on Target boxplot by group
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
colA = [0.2 0.4 0.8]; % Blue for Focused
colB = [0.8 0.3 0.2]; % Red for Expanded
colors = [colA; colB];
groupLabels = {'Focused', 'Expanded'};

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
validLegend = isgraphics(legendHandles);
if any(validLegend)
    legend(legendHandles(validLegend), groupLabels(validLegend), ...
        'FontSize', fontSize-2, 'Location', 'northeast');
end
axis equal; xlim([-20 screenW+20]); ylim([-20 screenH+20]);
hold off;
saveas(gcf, fullfile(FIG_PATH, 'IAB_BCEA_ellipse.png'));

%% ========================================================================
%  2. BOXPLOTS: ET METRICS BY GROUP x DISTRACTOR
%  ========================================================================
fprintf('Plotting ET metric boxplots...\n');

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

    % Build subject-level means for paired (within-group) comparisons
    subjIDs = unique([allFeatures.subjectID]);
    subjGroup = NaN(numel(subjIDs), 1);
    subjCondVals = NaN(numel(subjIDs), 2); % [noDistractor, distractor]

    for si = 1:numel(subjIDs)
        sIdx = [allFeatures.subjectID] == subjIDs(si);
        sData = allFeatures(sIdx);
        if isempty(sData); continue; end
        subjGroup(si) = sData(1).group;
        for c = 0:1
            cIdx = [sData.crossPresent] == c;
            vals = [sData(cIdx).(dv)];
            vals = vals(~isnan(vals));
            if ~isempty(vals)
                subjCondVals(si, c+1) = mean(vals);
            end
        end
    end

    YA = subjCondVals(subjGroup == 0, :);
    YB = subjCondVals(subjGroup == 1, :);

    boxPos = [1 2 4 5];
    valsAll = [YA(:,1); YA(:,2); YB(:,1); YB(:,2)];
    grpAll = [ones(size(YA,1),1); 2*ones(size(YA,1),1); 3*ones(size(YB,1),1); 4*ones(size(YB,1),1)];
    valid = ~isnan(valsAll);
    boxplot(valsAll(valid), grpAll(valid), 'Positions', boxPos, 'Symbol', '', 'Widths', 0.55, 'Colors', 'k');

    hBoxes = findobj(gca, 'Tag', 'Box');
    boxColors = [colA; colA; colB; colB];
    for bi = 1:min(numel(hBoxes), 4)
        patch(get(hBoxes(bi), 'XData'), get(hBoxes(bi), 'YData'), ...
              boxColors(5-bi,:), 'FaceAlpha', 0.25, 'EdgeColor', boxColors(5-bi,:), 'LineWidth', 1.5);
    end

    dotSize = 80;
    jitter = 0.12;
    scatter(boxPos(1) + jitter*(rand(size(YA,1),1)-0.5), YA(:,1), dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.65);
    scatter(boxPos(2) + jitter*(rand(size(YA,1),1)-0.5), YA(:,2), dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.65);
    scatter(boxPos(3) + jitter*(rand(size(YB,1),1)-0.5), YB(:,1), dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.65);
    scatter(boxPos(4) + jitter*(rand(size(YB,1),1)-0.5), YB(:,2), dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.65);

    % t-tests: paired within group, independent between groups (by condition)
    pA = runPairedTtest(YA(:,1), YA(:,2));
    pB = runPairedTtest(YB(:,1), YB(:,2));
    pNoDist = runIndependentTtest(YA(:,1), YB(:,1));
    pDist = runIndependentTtest(YA(:,2), YB(:,2));

    yMax = max(valsAll(valid));
    yMin = min(valsAll(valid));
    if isempty(yMax) || isempty(yMin); yMax = 1; yMin = 0; end
    yRange = max(eps, yMax - yMin);
    sigStep = 0.10 * yRange;
    sigBase = yMax + 0.08 * yRange;
    sigLevels = sigBase + (0:3) * sigStep;
    capH = 0.035 * yRange;
    addSigBracket(1, 2, sigLevels(1), pA, capH);
    addSigBracket(4, 5, sigLevels(2), pB, capH);
    addSigBracket(1, 4, sigLevels(3), pNoDist, capH);
    addSigBracket(2, 5, sigLevels(4), pDist, capH);
    ylim([yMin - 0.12*yRange, sigLevels(end) + 0.10*yRange]);

    set(gca, 'XTick', boxPos, ...
             'XTickLabel', {'Monkey not present', 'Monkey present', ...
                            'Monkey not present', 'Monkey present'}, ...
             'FontSize', fontSize-2);
    addGroupedXAxisLabels(gca, [1.5 4.5], {'Focused', 'Expanded'});
    ylabel(label, 'FontSize', fontSize);
    title(strrep(dv, '_', ' '), 'FontSize', fontSize);
    hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
    hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
    legend([hFocused, hExpanded], {'Focused', 'Expanded'}, 'FontSize', fontSize-4, 'Location', 'best');
    box off; hold off;

    saveas(gcf, fullfile(FIG_PATH, ['IAB_box_' dv '.png']));
    close;
end

%% ========================================================================
%  3. GAZE HEATMAPS BY GROUP (BASELINE-CHANGE + DISTRACTOR-CENTERED)
%  ========================================================================
fprintf('Plotting gaze heatmaps...\n');

nBins = 50;
xEdges = linspace(0, screenW, nBins+1);
yEdges = linspace(0, screenH, nBins+1);
kernel = fspecial('gaussian', [5 5], 1.5);
brMap = rdbu_cmap(256);

% 3a. Baseline-change heatmap: distractor-present minus no-distractor
figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');

for g = 0:1
    subplot(1, 2, g+1);

    base_x = []; base_y = [];
    dist_x = []; dist_y = [];

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
            if ~any(valid); continue; end

            if etData.crossPresent(trl) == 1
                dist_x = [dist_x, gx(valid)];
                dist_y = [dist_y, gy(valid)];
            else
                base_x = [base_x, gx(valid)];
                base_y = [base_y, gy(valid)];
            end
        end
    end

    Hbase = buildHeatmap(base_x, base_y, xEdges, yEdges, kernel);
    Hdist = buildHeatmap(dist_x, dist_y, xEdges, yEdges, kernel);
    Hdelta = Hdist - Hbase;

    imagesc(xEdges(1:end-1), yEdges(1:end-1), Hdelta');
    set(gca, 'YDir', 'normal');
    colormap(gca, brMap);
    cLim = max(abs(Hdelta(:)));
    if ~isfinite(cLim) || cLim == 0; cLim = 1; end
    caxis([-cLim, cLim]);
    cb = colorbar;
    cb.Label.String = '\Delta gaze density (present - absent)';

    hold on;
    plot(centreX, centreY, '+k', 'MarkerSize', 15, 'LineWidth', 2);
    hold off;
    xlabel('X [px]', 'FontSize', fontSize-2);
    ylabel('Y [px]', 'FontSize', fontSize-2);
    title([groupLabels{g+1}, ': baseline-change'], 'FontSize', fontSize-1);
    set(gca, 'FontSize', fontSize-2);
    axis equal; xlim([0 screenW]); ylim([0 screenH]);
end

sgtitle('Gaze Heatmaps: Baseline Change', 'FontSize', fontSize+2);
saveas(gcf, fullfile(FIG_PATH, 'IAB_gaze_heatmaps_baseline_change.png'));

% 3b. Distractor-centered heatmap: gaze relative to distractor location
figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');

xRelLim = screenW / 2;
yRelLim = screenH / 2;
xRelEdges = linspace(-xRelLim, xRelLim, nBins+1);
yRelEdges = linspace(-yRelLim, yRelLim, nBins+1);

for g = 0:1
    subplot(1, 2, g+1);

    rel_x = [];
    rel_y = [];

    for s = 1:length(subjects)
        subjID = num2str(subjects(s));
        etFile = fullfile(DATA_PATH, subjID, 'etData_IAB.mat');
        if ~exist(etFile, 'file'); continue; end
        load(etFile, 'etData');
        if strcmp(etData.group, 'B') ~= g; continue; end

        for trl = 1:length(etData.gazeX)
            if etData.crossPresent(trl) ~= 1 || isempty(etData.distractorPos{trl})
                continue;
            end

            gx = etData.gazeX{trl};
            gy = etData.gazeY{trl};
            dPos = etData.distractorPos{trl};
            nSamples = numel(gx);
            nDistSamples = size(dPos, 1);

            if nDistSamples == 0
                continue;
            elseif nDistSamples ~= nSamples
                dTimeOrig = linspace(0, 7, nDistSamples);
                dTimeNew  = linspace(0, 7, nSamples);
                dPos = [interp1(dTimeOrig, dPos(:,1), dTimeNew, 'nearest', 'extrap'); ...
                        interp1(dTimeOrig, dPos(:,2), dTimeNew, 'nearest', 'extrap')]';
            end

            dX = dPos(1:nSamples, 1)';
            dY = dPos(1:nSamples, 2)';
            valid = isfinite(gx) & isfinite(gy) & isfinite(dX) & isfinite(dY);

            if ~any(valid); continue; end
            rel_x = [rel_x, gx(valid) - dX(valid)];
            rel_y = [rel_y, gy(valid) - dY(valid)];
        end
    end

    Hrel = buildHeatmap(rel_x, rel_y, xRelEdges, yRelEdges, kernel);

    imagesc(xRelEdges(1:end-1), yRelEdges(1:end-1), Hrel');
    set(gca, 'YDir', 'normal');
    colormap(gca, brMap);
    caxis([0 max(eps, max(Hrel(:)))]);
    cb = colorbar;
    cb.Label.String = 'Relative gaze density';

    hold on;
    plot(0, 0, '+w', 'MarkerSize', 15, 'LineWidth', 2);
    hold off;
    xlabel('\DeltaX from distractor [px]', 'FontSize', fontSize-2);
    ylabel('\DeltaY from distractor [px]', 'FontSize', fontSize-2);
    title([groupLabels{g+1}, ': distractor-centered'], 'FontSize', fontSize-1);
    set(gca, 'FontSize', fontSize-2);
    axis equal; xlim([-xRelLim xRelLim]); ylim([-yRelLim yRelLim]);
end

sgtitle('Gaze Heatmaps: Distractor-Centered', 'FontSize', fontSize+2);
saveas(gcf, fullfile(FIG_PATH, 'IAB_gaze_heatmaps_distractor_centered.png'));

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
    boxplot(vals, repmat(g+1, 1, length(vals)), 'Positions', g+1, 'Symbol', '', 'Widths', 0.55, 'Colors', 'k');
    scatter(repmat(g+1, 1, length(vals)) + 0.12*(rand(1,length(vals))-0.5), vals, ...
        80, colors(g+1,:), 'filled', 'MarkerFaceAlpha', 0.65);
end
styleCurrentBoxplot([colA; colB]);
pAcc = runIndependentTtest([subjMeans([subjMeans.group] == 0).contAccuracy], ...
                           [subjMeans([subjMeans.group] == 1).contAccuracy]);
yValsAcc = [subjMeans.contAccuracy];
yMaxAcc = max(yValsAcc); yMinAcc = min(yValsAcc); yRangeAcc = max(eps, yMaxAcc - yMinAcc);
sigYAcc = yMaxAcc + 0.10*yRangeAcc;
addSigBracket(1, 2, sigYAcc, pAcc, 0.04*yRangeAcc);
ylim([yMinAcc - 0.12*yRangeAcc, sigYAcc + 0.10*yRangeAcc]);
set(gca, 'XTick', 1:2, 'XTickLabel', {'Focused', 'Expanded'}, 'FontSize', fontSize-2);
ylabel('Continuous Accuracy (%)', 'FontSize', fontSize);
title('Accuracy by Group', 'FontSize', fontSize);
hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
legend([hFocused, hExpanded], {'Focused', 'Expanded'}, 'FontSize', fontSize-4, 'Location', 'best');
box off; hold off;

% Reaction Time
subplot(1, 2, 2); hold on;
for g = 0:1
    gIdx = [subjMeans.group] == g;
    vals = [subjMeans(gIdx).rt];
    boxplot(vals, repmat(g+1, 1, length(vals)), 'Positions', g+1, 'Symbol', '', 'Widths', 0.55, 'Colors', 'k');
    scatter(repmat(g+1, 1, length(vals)) + 0.12*(rand(1,length(vals))-0.5), vals, ...
        80, colors(g+1,:), 'filled', 'MarkerFaceAlpha', 0.65);
end
styleCurrentBoxplot([colA; colB]);
pRT = runIndependentTtest([subjMeans([subjMeans.group] == 0).rt], ...
                          [subjMeans([subjMeans.group] == 1).rt]);
yValsRT = [subjMeans.rt];
yMaxRT = max(yValsRT); yMinRT = min(yValsRT); yRangeRT = max(eps, yMaxRT - yMinRT);
sigYRT = yMaxRT + 0.10*yRangeRT;
addSigBracket(1, 2, sigYRT, pRT, 0.04*yRangeRT);
ylim([yMinRT - 0.12*yRangeRT, sigYRT + 0.10*yRangeRT]);
set(gca, 'XTick', 1:2, 'XTickLabel', {'Focused', 'Expanded'}, 'FontSize', fontSize-2);
ylabel('Reaction Time [s]', 'FontSize', fontSize);
title('RT by Group', 'FontSize', fontSize);
hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
legend([hFocused, hExpanded], {'Focused', 'Expanded'}, 'FontSize', fontSize-4, 'Location', 'best');
box off; hold off;

saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_summary.png'));

%% ========================================================================
%  5. PERCEPTION QUESTIONS
%  ========================================================================
fprintf('Plotting perception questions...\n');

perc = behavioral_summary.perception;
if ~isempty(perc)
    figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');

    qLabels = {'Q1: Unusual', 'Q2: Besides nums', 'Q3: Non-num object', 'Q5: Saw monkey'};
    qFields = {'Q1_unusual', 'Q2_besides', 'Q3_object', 'Q5_monkey'};

    for q = 1:length(qFields)
        subplot(2,2,q); hold on;
        valsA = [perc([perc.group] == 0).(qFields{q})];
        valsB = [perc([perc.group] == 1).(qFields{q})];
        valsA = valsA(~isnan(valsA));
        valsB = valsB(~isnan(valsB));

        if ~isempty(valsA)
            boxplot(valsA*100, ones(size(valsA)), 'Positions', 1, 'Symbol', '', 'Widths', 0.5, 'Colors', 'k');
            scatter(1 + 0.12*(rand(size(valsA))-0.5), valsA*100, 80, colA, 'filled', 'MarkerFaceAlpha', 0.65);
        end
        if ~isempty(valsB)
            boxplot(valsB*100, 2*ones(size(valsB)), 'Positions', 2, 'Symbol', '', 'Widths', 0.5, 'Colors', 'k');
            scatter(2 + 0.12*(rand(size(valsB))-0.5), valsB*100, 80, colB, 'filled', 'MarkerFaceAlpha', 0.65);
        end

        pQ = runBinaryGroupTest(valsA, valsB);
        allQ = [valsA(:); valsB(:)] * 100;
        if isempty(allQ); allQ = [0; 1]; end
        yMaxQ = max(allQ); yMinQ = min(allQ); yRangeQ = max(eps, yMaxQ - yMinQ);
        sigYQ = yMaxQ + 0.12*yRangeQ;
        addSigBracket(1, 2, sigYQ, pQ, 0.05*yRangeQ);
        ylim([max(0, yMinQ - 0.1*yRangeQ), min(105, sigYQ + 0.12*yRangeQ)]);
        set(gca, 'XTick', [1 2], 'XTickLabel', {'Focused', 'Expanded'}, 'FontSize', fontSize-4);
        ylabel('% Yes', 'FontSize', fontSize-4);
        title(qLabels{q}, 'FontSize', fontSize-2);
        box off; hold off;
    end

    sgtitle('Perception Questions by Group', 'FontSize', fontSize+2);

    saveas(gcf, fullfile(FIG_PATH, 'IAB_perception_questions.png'));
end

%% ========================================================================
%  6. TIME ON TARGET BY GROUP
%  ========================================================================
fprintf('Plotting time on target...\n');

figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w'); hold on;

subjIDs = unique([allFeatures.subjectID]);
subjGroup = NaN(numel(subjIDs), 1);
subjTOT = NaN(numel(subjIDs), 1);
for si = 1:numel(subjIDs)
    sIdx = [allFeatures.subjectID] == subjIDs(si) & [allFeatures.crossPresent] == 1;
    sData = allFeatures(sIdx);
    if isempty(sData); continue; end
    subjGroup(si) = sData(1).group;
    vals = [sData.timeOnTarget];
    vals = vals(~isnan(vals));
    if ~isempty(vals); subjTOT(si) = mean(vals); end
end

valsA = subjTOT(subjGroup == 0);
valsB = subjTOT(subjGroup == 1);
valsA = valsA(~isnan(valsA));
valsB = valsB(~isnan(valsB));

boxplot(valsA, ones(size(valsA)), 'Positions', 1, 'Symbol', '', 'Widths', 0.55, 'Colors', 'k');
boxplot(valsB, 2*ones(size(valsB)), 'Positions', 2, 'Symbol', '', 'Widths', 0.55, 'Colors', 'k');
scatter(1 + 0.12*(rand(size(valsA))-0.5), valsA, 80, colA, 'filled', 'MarkerFaceAlpha', 0.65);
scatter(2 + 0.12*(rand(size(valsB))-0.5), valsB, 80, colB, 'filled', 'MarkerFaceAlpha', 0.65);
styleCurrentBoxplot([colA; colB]);

pTOT = runIndependentTtest(valsA, valsB);
yAll = [valsA(:); valsB(:)];
if isempty(yAll); yAll = [0; 1]; end
yMax = max(yAll); yMin = min(yAll); yRange = max(eps, yMax - yMin);
sigYTOT = yMax + 0.10*yRange;
addSigBracket(1, 2, sigYTOT, pTOT, 0.04*yRange);
ylim([yMin - 0.12*yRange, sigYTOT + 0.10*yRange]);

set(gca, 'XTick', 1:2, 'XTickLabel', {'Focused', 'Expanded'}, ...
    'FontSize', fontSize-2);
ylabel('Time on Target [%]', 'FontSize', fontSize);
title('Time on Target (Monkey-present Trials)', 'FontSize', fontSize);
hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
legend([hFocused, hExpanded], {'Focused', 'Expanded'}, 'FontSize', fontSize-4, 'Location', 'best');
box off; hold off;

saveas(gcf, fullfile(FIG_PATH, 'IAB_time_on_target.png'));

%% Done
fprintf('\n=== All figures saved to: %s ===\n', FIG_PATH);
close all;

%% Local helper functions
function p = runPairedTtest(x, y)
valid = isfinite(x) & isfinite(y);
if sum(valid) > 1
    [~, p] = ttest(x(valid), y(valid));
else
    p = NaN;
end
end

function p = runIndependentTtest(x, y)
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) > 1 && numel(y) > 1
    [~, p] = ttest2(x, y);
else
    p = NaN;
end
end

function addSigBracket(x1, x2, y, p, capHeight)
if ~isfinite(y)
    return;
end
if nargin < 5 || ~isfinite(capHeight) || capHeight <= 0
    yl = ylim;
    capHeight = 0.02 * max(eps, yl(2) - yl(1));
end
tick = capHeight;
plot([x1 x1 x2 x2], [y-tick y y y-tick], 'k-', 'LineWidth', 1.5);
text(mean([x1 x2]), y + 0.15*tick, pToStars(p), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 14, 'FontWeight', 'bold');
end

function styleCurrentBoxplot(boxColors)
hBoxes = findobj(gca, 'Tag', 'Box');
for bi = 1:min(numel(hBoxes), size(boxColors,1))
    cIdx = size(boxColors,1) - bi + 1;
    patch(get(hBoxes(bi), 'XData'), get(hBoxes(bi), 'YData'), ...
        boxColors(cIdx,:), 'FaceAlpha', 0.25, 'EdgeColor', boxColors(cIdx,:), 'LineWidth', 1.5);
end
end

function addGroupedXAxisLabels(ax, xCenters, labels)
yl = ylim(ax);
yRange = max(eps, yl(2) - yl(1));
yText = yl(1) - 0.12 * yRange;
for i = 1:numel(xCenters)
    text(ax, xCenters(i), yText, labels{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontSize', ax.FontSize, ...
        'FontWeight', 'normal', ...
        'Clipping', 'off');
end
end

function s = pToStars(p)
if ~isfinite(p)
    s = 'n.s.';
elseif p < 0.001
    s = '***';
elseif p < 0.01
    s = '**';
elseif p < 0.05
    s = '*';
else
    s = 'n.s.';
end
end

function H = buildHeatmap(x, y, xEdges, yEdges, kernel)
if isempty(x) || isempty(y)
    H = zeros(numel(xEdges)-1, numel(yEdges)-1);
    return;
end
H = histcounts2(x, y, xEdges, yEdges);
if sum(H(:)) > 0
    H = H ./ sum(H(:));
end
H = imfilter(H, kernel, 'replicate');
end

function cmap = rdbu_cmap(n)
if nargin < 1
    n = 256;
end
rdbu_11 = [33 102 172; 67 147 195; 146 197 222; 209 229 240; 247 247 247; ...
    253 219 199; 244 165 130; 214 96 77; 178 24 43] / 255;
x = linspace(0, 1, size(rdbu_11, 1));
xi = linspace(0, 1, n);
cmap = interp1(x, rdbu_11, xi, 'linear');
end

function p = runBinaryGroupTest(x, y)
% Exact test for 2x2 binary outcomes (Group x Yes/No).
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
    p = NaN;
    return;
end

yesA = sum(x == 1); noA = sum(x == 0);
yesB = sum(y == 1); noB = sum(y == 0);

if (yesA + noA) == 0 || (yesB + noB) == 0
    p = NaN;
    return;
end

obs = [yesA, noA; yesB, noB];
p = fisherExact2x2(obs);
end

function p = fisherExact2x2(obs)
% Two-sided Fisher exact p-value for a 2x2 table.
a = obs(1,1); b = obs(1,2); c = obs(2,1); d = obs(2,2);
r1 = a + b; r2 = c + d;
c1 = a + c; c2 = b + d;
n = r1 + r2;

aMin = max(0, c1 - r2);
aMax = min(r1, c1);
aVals = aMin:aMax;

logChoose = @(N, K) gammaln(N + 1) - gammaln(K + 1) - gammaln(N - K + 1);
logP = @(aa) logChoose(c1, aa) + logChoose(c2, r1 - aa) - logChoose(n, r1);

logObs = logP(a);
pObs = exp(logObs);

p = 0;
tol = 1e-12;
for aa = aVals
    pCurr = exp(logP(aa));
    if pCurr <= pObs + tol
        p = p + pCurr;
    end
end
p = min(1, p);
end
