%% IAB Eye-Tracking and Behavior: Trial-Level Visualization
% Same layout as IAB_visualize.m (boxplots, jittered trial points, significance
% brackets) but each point is a trial.
%
% ET boxplots pool trials across distractor (monkey absent vs present). The
% between-group bracket (Focused vs Expanded) uses a two-sample t-test on trial
% pools (ttest2).
%
% Input:
%   [DATA_PATH]/[subjectID]/features_IAB.mat  (trialFeatures)
%   [DATA_PATH]/behavioral_summary.mat        (behavioral_summary.behavData)
%
% Output:
%   Figures in [FIG_PATH] with filename suffix _trials before .png (figure width
%   figW = 1512/2 px). Behavioral accuracy and RT are each saved as their own
%   figure; the same for group x distractor splits (four trial pools per panel).
%   [DATA_PATH]/IAB_features.csv        (trial-level data used for stats)
%   [DATA_PATH]/IAB_stats_results.csv   (all t-tests shown on figures)
%
% Prerequisite: run IAB_feature_extraction.m and IAB_analyze_behavioral.m.
%
% After stacking trials, values beyond mean +/- 3 SD (per variable) are set to
% NaN for plotting and tests. Design columns in the stack are unchanged; ET
% group plots ignore distractor level by pooling trials.

%% Setup
clear; clc; close all;

DATA_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/';
FIG_PATH  = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/figures/trials/';

if ~exist(FIG_PATH, 'dir')
    mkdir(FIG_PATH);
end

subjects = 201:220;

colA = [0.2 0.4 0.8];
colB = [0.8 0.3 0.2];
fontSize = 18;
figW = 1512 / 2;
lblGroupA = 'Fokussiert';
lblGroupB = 'Erweitert';
lblGroupsXY = {lblGroupA, lblGroupB};

%% Stack trial-level ET features from all subjects
fprintf('Loading trial-level features...\n');
trialStack = stackTrialFeatures(DATA_PATH, subjects);
if isempty(trialStack.subjectID)
    error('No features_IAB.mat files found under DATA_PATH. Run IAB_feature_extraction.m first.');
end

outlierSd = 3;
numericFields = {'gazeDeviation', 'gazeStdX', 'gazeStdY', 'fixationCount', 'fixationDurMean', ...
    'saccadeCount', 'saccadeAmpMean', 'scanPathLength', 'pupilSize', 'timeOnTarget', ...
    'contAccuracy', 'reactionTime'};
fprintf('Masking trial outliers beyond %g SD (per variable, set to NaN)...\n', outlierSd);
trialStack = applySdOutlierMask(trialStack, numericFields, outlierSd);

statsTable = table();

%% Boxplots settings (x at 1 and 2: two separate boxplot calls avoid grouped
% boxplot + custom Positions misalignment in some MATLAB versions)
catX = [1 2];
dotSize = 50;
jitter = 0.35;

%% ========================================================================
%  1. BOXPLOTS: ET METRICS BY GROUP (trials pooled across distractor)
%  ========================================================================
fprintf('Plotting trial-level ET metric boxplots...\n');

dvSpecs = {
    'gazeDeviation',   'Blickabweichung [px]',          'gazeDeviation'
    'gazeStdX',        'Blick-Std. X [px]',             'gazeStdX'
    'gazeStdY',        'Blick-Std. Y [px]',             'gazeStdY'
    'fixationCount',   'Fixationsanzahl',               'fixationCount'
    'fixationDur',     'Fixationsdauer [ms]',           'fixationDurMean'
    'saccadeCount',    'Sakkadenanzahl',                'saccadeCount'
    'saccadeAmp',      'Sakkadenamplitude [°]',         'saccadeAmpMean'
    'Scan Path Length',     'Scanstrecke [px]',              'scanPathLength'
    'pupilSize',       'Pupillengrösse [a.u.]',        'pupilSize'
    };

for d = 1:size(dvSpecs, 1)
    dvTag   = dvSpecs{d, 1};
    yLabelS = dvSpecs{d, 2};
    fld     = dvSpecs{d, 3};

    y = trialStack.(fld);
    g = trialStack.group;

    ya = y(g == 0);
    yb = y(g == 1);

    ya = ya(isfinite(ya));
    yb = yb(isfinite(yb));

    figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w'); hold on;

    valsAll = [ya(:); yb(:)];
    valid = isfinite(valsAll);
    if ~any(valid)
        warning('No valid data for DV %s, skipping.', dvTag);
        close;
        continue;
    end

    if ~isempty(ya)
        boxplot(ya, ones(numel(ya), 1), 'Positions', catX(1), 'Symbol', '', ...
            'Widths', 0.55, 'Colors', 'k');
    end
    if ~isempty(yb)
        boxplot(yb, 2*ones(numel(yb), 1), 'Positions', catX(2), 'Symbol', '', ...
            'Widths', 0.55, 'Colors', 'k');
    end

    scatter(catX(1) + jitter*(rand(numel(ya), 1) - 0.5), ya, dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.45);
    scatter(catX(2) + jitter*(rand(numel(yb), 1) - 0.5), yb, dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.45);
    styleCurrentBoxplot([colA; colB]);

    pGrp = runIndependentTtest(ya, yb);
    statsTable = appendTtestRow(statsTable, fld, 'ET_group', 'Focused_vs_Expanded', ya, yb);

    yMax = max(valsAll(valid));
    yMin = min(valsAll(valid));
    if isempty(yMax) || isempty(yMin); yMax = 1; yMin = 0; end
    yRange = max(eps, yMax - yMin);
    sigY = yMax + 0.08 * yRange;
    capH = 0.035 * yRange;
    addSigBracket(1, 2, sigY, pGrp, capH);
    ylim([yMin - 0.12*yRange, sigY + capH + 0.10*yRange]);
    xlim([0.5 2.5]);

    set(gca, 'XTick', catX, 'XTickLabel', lblGroupsXY, ...
        'FontSize', fontSize - 2);
    ylabel(yLabelS, 'FontSize', fontSize);
    title(titleFromYLabel(yLabelS), 'FontSize', fontSize);
    hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
    hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
    legend([hFocused, hExpanded], lblGroupsXY, 'FontSize', fontSize - 4, 'Location', 'northeast');
    xlim([0.5 2.5]);
    box off; hold off;

    saveas(gcf, fullfile(FIG_PATH, sprintf('IAB_box_%s_trials.png', dvTag)));
    close;
end

%% ========================================================================
%  2. BEHAVIORAL SUMMARY (trial-level accuracy and RT by group)
%  ========================================================================
bd = [];
behavFile = fullfile(DATA_PATH, 'behavioral_summary.mat');
if ~exist(behavFile, 'file')
    warning('behavioral_summary.mat not found, skipping behavioral trial plots.');
else
    fprintf('Plotting trial-level behavioral summary...\n');
    B = load(behavFile, 'behavioral_summary');
    bd = B.behavioral_summary.behavData;

    accAll = [bd.contAccuracy]';
    rtAll = [bd.reactionTime]';
    accAll = maskSdOutliersNaN(accAll, outlierSd);
    rtAll = maskSdOutliersNaN(rtAll, outlierSd);
    for ii = 1:numel(bd)
        bd(ii).contAccuracy = accAll(ii);
        bd(ii).reactionTime = rtAll(ii);
    end

    accA = [bd([bd.group] == 0).contAccuracy];
    accB = [bd([bd.group] == 1).contAccuracy];
    rtA  = [bd([bd.group] == 0).reactionTime];
    rtB  = [bd([bd.group] == 1).reactionTime];

    accA = accA(isfinite(accA));
    accB = accB(isfinite(accB));
    rtA  = rtA(isfinite(rtA));
    rtB  = rtB(isfinite(rtB));

    axBeh1 = gobjects(1);
    figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w');
    hold on;
    if ~isempty(accA) || ~isempty(accB)
        if ~isempty(accA)
            boxplot(accA, ones(numel(accA), 1), 'Positions', 1, 'Symbol', '', ...
                'Widths', 0.55, 'Colors', 'k');
        end
        if ~isempty(accB)
            boxplot(accB, 2*ones(numel(accB), 1), 'Positions', 2, 'Symbol', '', ...
                'Widths', 0.55, 'Colors', 'k');
        end
        scatter(1 + jitter*(rand(numel(accA), 1) - 0.5), accA, dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.45);
        scatter(2 + jitter*(rand(numel(accB), 1) - 0.5), accB, dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.45);
        styleCurrentBoxplot([colA; colB]);
        pAcc = runIndependentTtest(accA, accB);
        statsTable = appendTtestRow(statsTable, 'contAccuracy', 'behavioral_group', ...
            'Focused_vs_Expanded', accA, accB);
        yValsAcc = [accA(:); accB(:)];
        yMaxAcc = max(yValsAcc);
        yMinAcc = min(yValsAcc);
        if isempty(yMaxAcc) || isempty(yMinAcc); yMaxAcc = 1; yMinAcc = 0; end
        yRangeAcc = max(eps, yMaxAcc - yMinAcc);
        sigYAcc = yMaxAcc + 0.08 * yRangeAcc;
        capHAcc = 0.035 * yRangeAcc;
        addSigBracket(1, 2, sigYAcc, pAcc, capHAcc);
        ylim([yMinAcc - 0.12*yRangeAcc, sigYAcc + capHAcc + 0.10*yRangeAcc]);
        xlim([0.5 2.5]);
        axBeh1 = gca;
    end
    set(gca, 'XTick', 1:2, 'XTickLabel', lblGroupsXY, 'FontSize', fontSize - 2);
    ylabelAcc = 'Genauigkeit (%)';
    ylabel(ylabelAcc, 'FontSize', fontSize);
    title('Genauigkeit', 'FontSize', fontSize);
    hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
    hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
    legend([hFocused, hExpanded], lblGroupsXY, 'FontSize', fontSize - 4, 'Location', 'southwest');
    box off; hold off;
    if isgraphics(axBeh1)
        xlim(axBeh1, [0.5 2.5]);
        bumpAxesTitleMargin(axBeh1);
    end
    saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_accuracy_trials.png'));

    axBeh2 = gobjects(1);
    figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w');
    hold on;
    if ~isempty(rtA) || ~isempty(rtB)
        if ~isempty(rtA)
            boxplot(rtA, ones(numel(rtA), 1), 'Positions', 1, 'Symbol', '', ...
                'Widths', 0.55, 'Colors', 'k');
        end
        if ~isempty(rtB)
            boxplot(rtB, 2*ones(numel(rtB), 1), 'Positions', 2, 'Symbol', '', ...
                'Widths', 0.55, 'Colors', 'k');
        end
        scatter(1 + jitter*(rand(numel(rtA), 1) - 0.5), rtA, dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.45);
        scatter(2 + jitter*(rand(numel(rtB), 1) - 0.5), rtB, dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.45);
        styleCurrentBoxplot([colA; colB]);
        pRT = runIndependentTtest(rtA, rtB);
        statsTable = appendTtestRow(statsTable, 'reactionTime', 'behavioral_group', ...
            'Focused_vs_Expanded', rtA, rtB);
        yValsRT = [rtA(:); rtB(:)];
        yMaxRT = max(yValsRT);
        yMinRT = min(yValsRT);
        if isempty(yMaxRT) || isempty(yMinRT); yMaxRT = 1; yMinRT = 0; end
        yRangeRT = max(eps, yMaxRT - yMinRT);
        sigYRT = yMaxRT + 0.08 * yRangeRT;
        capHRT = 0.035 * yRangeRT;
        addSigBracket(1, 2, sigYRT, pRT, capHRT);
        ylim([yMinRT - 0.12*yRangeRT, sigYRT + capHRT + 0.10*yRangeRT]);
        xlim([0.5 2.5]);
        axBeh2 = gca;
    end
    set(gca, 'XTick', 1:2, 'XTickLabel', lblGroupsXY, 'FontSize', fontSize - 2);
    ylabelRT = 'Reaktionszeit [s]';
    ylabel(ylabelRT, 'FontSize', fontSize);
    title(titleFromYLabel(ylabelRT), 'FontSize', fontSize);
    hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
    hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
    legend([hFocused, hExpanded], lblGroupsXY, 'FontSize', fontSize - 4, 'Location', 'southwest');
    box off; hold off;
    if isgraphics(axBeh2)
        xlim(axBeh2, [0.5 2.5]);
        bumpAxesTitleMargin(axBeh2);
    end
    saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_reaction_time_trials.png'));

    %% Behavioral: group x distractor (trial pools, four boxes per DV)
    fprintf('Plotting trial-level accuracy by group x distractor...\n');
    boxPos4 = [1 2 4 5];
    jitter4 = 0.12;

    accFA = [bd([bd.group] == 0 & [bd.crossPresent] == 0).contAccuracy];
    accFP = [bd([bd.group] == 0 & [bd.crossPresent] == 1).contAccuracy];
    accEA = [bd([bd.group] == 1 & [bd.crossPresent] == 0).contAccuracy];
    accEP = [bd([bd.group] == 1 & [bd.crossPresent] == 1).contAccuracy];
    rtFA = [bd([bd.group] == 0 & [bd.crossPresent] == 0).reactionTime];
    rtFP = [bd([bd.group] == 0 & [bd.crossPresent] == 1).reactionTime];
    rtEA = [bd([bd.group] == 1 & [bd.crossPresent] == 0).reactionTime];
    rtEP = [bd([bd.group] == 1 & [bd.crossPresent] == 1).reactionTime];

    accFA = accFA(isfinite(accFA));
    accFP = accFP(isfinite(accFP));
    accEA = accEA(isfinite(accEA));
    accEP = accEP(isfinite(accEP));
    rtFA = rtFA(isfinite(rtFA));
    rtFP = rtFP(isfinite(rtFP));
    rtEA = rtEA(isfinite(rtEA));
    rtEP = rtEP(isfinite(rtEP));

    figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w');
    axGd1 = gca;
    [axGd1, TaccGd] = plotFourGroupTrialBoxplot(axGd1, accFA, accFP, accEA, accEP, boxPos4, ...
        jitter4, dotSize, colA, colB, fontSize, 'Genauigkeit (%)', 'Genauigkeit', true, ...
        'contAccuracy', 'behavioral_group_x_distractor', lblGroupsXY);
    statsTable = [statsTable; TaccGd];
    if isgraphics(axGd1)
        bumpAxesTitleMargin(axGd1);
    end
    saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_accuracy_group_x_distractor_trials.png'));

    fprintf('Plotting trial-level reaction time by group x distractor...\n');
    figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w');
    axGd2 = gca;
    [axGd2, TrtGd] = plotFourGroupTrialBoxplot(axGd2, rtFA, rtFP, rtEA, rtEP, boxPos4, ...
        jitter4, dotSize, colA, colB, fontSize, 'Reaktionszeit [s]', ...
        titleFromYLabel('Reaktionszeit [s]'), true, ...
        'reactionTime', 'behavioral_group_x_distractor', lblGroupsXY);
    statsTable = [statsTable; TrtGd];
    if isgraphics(axGd2)
        bumpAxesTitleMargin(axGd2);
    end
    saveas(gcf, fullfile(FIG_PATH, 'IAB_behavioral_reaction_time_group_x_distractor_trials.png'));
end

%% ========================================================================
%  3. GAZE HEATMAPS BY GROUP (baseline-change + distractor-centered)
%  ========================================================================
fprintf('Plotting gaze heatmaps...\n');

screenW = 800;
screenH = 600;
centreX = 400;
centreY = 300;
nBins = 50;
xEdges = linspace(0, screenW, nBins + 1);
yEdges = linspace(0, screenH, nBins + 1);
if exist('fspecial', 'file') == 2
    kernel = fspecial('gaussian', [5 5], 1.5);
else
    halfK = 2;
    [Xk, Yk] = meshgrid(-halfK:halfK, -halfK:halfK);
    kernel = exp(-(Xk.^2 + Yk.^2) / (2 * 1.5^2));
    kernel = kernel / sum(kernel(:));
end
brMap = rdbuCmap(256);
tot_radius_dva = 2;
ppd = 50; % matches IAB_task.m measured override
tot_radius_px = tot_radius_dva * ppd;

% Monkey image at display size used in the paradigm (0.25 dva)
distractorSize_dva = 0.25;
distractorSize_pix = round(distractorSize_dva * ppd);
monkeyImagePath = '/Users/Arne/Documents/GitHub/IAB/0_paradigm/monkey.png';
[monkeyRGB, ~, monkeyAlpha] = imread(monkeyImagePath);
if isempty(monkeyAlpha)
    monkeyAlpha = 255 * ones(size(monkeyRGB, 1), size(monkeyRGB, 2), 'uint8');
end
[origH, origW, ~] = size(monkeyRGB);
aspectRatio = origW / origH;
if aspectRatio >= 1
    monkeyW = distractorSize_pix;
    monkeyH = max(1, round(distractorSize_pix / aspectRatio));
else
    monkeyH = distractorSize_pix;
    monkeyW = max(1, round(distractorSize_pix * aspectRatio));
end
monkeyRGB = imresize(monkeyRGB, [monkeyH, monkeyW]);
monkeyAlpha = imresize(monkeyAlpha, [monkeyH, monkeyW]);
monkeyX = linspace(-monkeyW/2, monkeyW/2, monkeyW);
monkeyY = linspace(-monkeyH/2, monkeyH/2, monkeyH);

% Accumulate 2-D histograms once while loading each etData file (avoid
% reloading subjects twice and avoid growing million-sample arrays with []).
Hbase_by_g = {zeros(nBins), zeros(nBins)};
Hdist_by_g = {zeros(nBins), zeros(nBins)};
Hrel_by_g  = {zeros(nBins), zeros(nBins)};
xRelLim = 250;
yRelLim = 200;
xRelEdges = linspace(-xRelLim, xRelLim, nBins + 1);
yRelEdges = linspace(-yRelLim, yRelLim, nBins + 1);

fprintf('  Loading etData and binning gaze samples once per subject...\n');
tHeat = tic;
for s = 1:numel(subjects)
    subjID = num2str(subjects(s));
    etFile = fullfile(DATA_PATH, subjID, 'etData_IAB.mat');
    if ~exist(etFile, 'file')
        continue;
    end
    fprintf('    subject %s ...\n', subjID);
    D = load(etFile, 'etData');
    etData = D.etData;
    gIdx = strcmp(etData.group, 'B') + 1;

    for trl = 1:numel(etData.gazeX)
        gx = etData.gazeX{trl}(:);
        gy = etData.gazeY{trl}(:);
        valid = isfinite(gx) & isfinite(gy);
        if ~any(valid)
            continue;
        end

        Htrl = histcounts2(gx(valid), gy(valid), xEdges, yEdges);
        if etData.crossPresent(trl) == 1
            Hdist_by_g{gIdx} = Hdist_by_g{gIdx} + Htrl;
        else
            Hbase_by_g{gIdx} = Hbase_by_g{gIdx} + Htrl;
        end

        if etData.crossPresent(trl) ~= 1 || isempty(etData.distractorPos{trl})
            continue;
        end
        nSamples = numel(gx);
        dPos = etData.distractorPos{trl};
        nDist = size(dPos, 1);
        if nSamples < 2 || nDist < 2
            continue;
        end

        if isfield(etData, 'distractorTime') && numel(etData.distractorTime) >= trl && ~isempty(etData.distractorTime{trl})
            dTime = etData.distractorTime{trl}(:);
            if numel(dTime) ~= nDist
                dRel = linspace(0, 7.0, nDist)';
            else
                dRel = dTime - dTime(1);
            end
        else
            dRel = linspace(0, 7.0, nDist)';
        end

        if isfield(etData, 'time') && numel(etData.time) >= trl && ~isempty(etData.time{trl})
            tGaze = etData.time{trl}(:);
            if numel(tGaze) ~= nSamples
                tGaze = linspace(0, 7.0, nSamples)';
            end
        else
            tGaze = linspace(0, 7.0, nSamples)';
        end

        dX = interp1(dRel, dPos(:, 1), tGaze, 'linear', 'extrap');
        dY = interp1(dRel, dPos(:, 2), tGaze, 'linear', 'extrap');
        validRel = valid & isfinite(dX) & isfinite(dY);
        if ~any(validRel)
            continue;
        end
        Hrel_by_g{gIdx} = Hrel_by_g{gIdx} + histcounts2( ...
            gx(validRel) - dX(validRel), gy(validRel) - dY(validRel), ...
            xRelEdges, yRelEdges);
    end
end
fprintf('  Heatmap binning done in %.1f s.\n', toc(tHeat));

% Normalize, smooth, plot baseline-change (within group)
figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');
for gPlot = 0:1
    subplot(1, 2, gPlot + 1);
    Hbase = normalizeHeatmap(Hbase_by_g{gPlot + 1}, kernel);
    Hdist = normalizeHeatmap(Hdist_by_g{gPlot + 1}, kernel);
    Hdiff = Hdist - Hbase;
    imagesc(xEdges(1:end-1), yEdges(1:end-1), Hdiff');
    set(gca, 'YDir', 'normal');
    colormap(gca, brMap);
    cLim = max(abs(Hdiff(:)));
    if ~isfinite(cLim) || cLim == 0
        cLim = 1;
    end
    caxis([-cLim, cLim]);
    cb = colorbar;
    cb.Label.String = '\Delta Blickdichte (Affe anwesend - Affe abwesend)';
    hold on;
    th = linspace(0, 2*pi, 200);
    plot(centreX + tot_radius_px * cos(th), centreY + tot_radius_px * sin(th), ...
        ':', 'Color', [0 0 0], 'LineWidth', 1.5);
    hold off;
    xlabel('Bildschirmbreite [px]', 'FontSize', fontSize - 1);
    ylabel('Bildschirmhöhe [px]', 'FontSize', fontSize - 1);
    if gPlot == 0
        title('Fokussiert', 'FontSize', fontSize);
    else
        title('Erweitert', 'FontSize', fontSize);
    end
    set(gca, 'FontSize', fontSize - 2);
    axis equal;
    xlim([0 screenW]);
    ylim([0 screenH]);
end
sgtitle('Blick-Heatmap: Differenz Affe anwesend minus Affe abwesend', 'FontSize', fontSize + 1);
saveas(gcf, fullfile(FIG_PATH, 'IAB_gaze_heatmap_baseline_change_trials.png'));
close;

% Distraktor-zentrierte Gruppendifferenz
Hrel_foc = normalizeHeatmap(Hrel_by_g{1}, kernel);
Hrel_exp = normalizeHeatmap(Hrel_by_g{2}, kernel);
Hrel_diff = Hrel_exp - Hrel_foc;

%%
figure; set(gcf, 'Position', [0 0 1512 982], 'Color', 'w');
imagesc(xRelEdges(1:end-1), yRelEdges(1:end-1), Hrel_diff');
set(gca, 'YDir', 'normal');
colormap(gca, brMap);
cLim = max(abs(Hrel_diff(:)));
if ~isfinite(cLim) || cLim == 0
    cLim = 1;
end
caxis([-cLim, cLim]);
cb = colorbar;
cb.Label.String = '\Delta Blickdichte (Erweitert - Fokussiert)';
hold on;
hMonkey = image('XData', monkeyX, 'YData', monkeyY, 'CData', monkeyRGB);
set(hMonkey, 'AlphaData', double(monkeyAlpha) / 255);
hold off;
fontSize = fontSize*1.2
xlabel('\DeltaX relativ zum Affen [px]', 'FontSize', fontSize);
ylabel('\DeltaY relativ zum Affen [px]', 'FontSize', fontSize);
title('Zentrierte Blickdichte: Gruppendifferenz', 'FontSize', fontSize + 2);
set(gca, 'FontSize', fontSize - 2);
axis equal;
xlim([-xRelLim xRelLim]);
ylim([-yRelLim yRelLim]);
saveas(gcf, fullfile(FIG_PATH, 'IAB_gaze_heatmap_distractor_centered_group_diff_trials.png'));
%close;

%% ========================================================================
%  4. TIME ON TARGET (monkey-present trials only, trial-level)
%  ========================================================================
fprintf('Plotting trial-level time on target...\n');

y = trialStack.timeOnTarget;
g = trialStack.group;
c = trialStack.crossPresent;

totA = y(g == 0 & c == 1);
totB = y(g == 1 & c == 1);
totA = totA(isfinite(totA));
totB = totB(isfinite(totB));

nTotA = numel(totA);
nTotB = numel(totB);
nPosA = sum(totA > 0);
nPosB = sum(totB > 0);
pctPosA = 100 * nPosA / max(1, nTotA);
pctPosB = 100 * nPosB / max(1, nTotB);
fprintf('  Monkey-present trials (finite ToT): Focused %d, Expanded %d\n', nTotA, nTotB);
fprintf('  Trials with ToT > 0%%: Focused %d/%d (%.1f%%), Expanded %d/%d (%.1f%%)\n', ...
    nPosA, nTotA, pctPosA, nPosB, nTotB, pctPosB);

totA = totA(totA > 0);
totB = totB(totB > 0);

figure; set(gcf, 'Position', [0 0 figW 982], 'Color', 'w'); hold on;
if ~isempty(totA)
    boxplot(totA, ones(numel(totA), 1), 'Positions', 1, 'Symbol', '', ...
        'Widths', 0.55, 'Colors', 'k');
end
if ~isempty(totB)
    boxplot(totB, 2*ones(numel(totB), 1), 'Positions', 2, 'Symbol', '', ...
        'Widths', 0.55, 'Colors', 'k');
end
scatter(1 + jitter*(rand(numel(totA), 1) - 0.5), totA, dotSize, colA, 'filled', 'MarkerFaceAlpha', 0.45);
scatter(2 + jitter*(rand(numel(totB), 1) - 0.5), totB, dotSize, colB, 'filled', 'MarkerFaceAlpha', 0.45);
styleCurrentBoxplot([colA; colB]);
pTOT = runIndependentTtest(totA, totB);
statsTable = appendTtestRow(statsTable, 'timeOnTarget', 'time_on_target', ...
    'Focused_vs_Expanded_monkeyPresent_ToTgt0', totA, totB);
yAll = [totA(:); totB(:)];
if isempty(yAll); yAll = [0; 1]; end
yMax = max(yAll); yMin = min(yAll); yRange = max(eps, yMax - yMin);
sigYTOT = yMax + 0.10*yRange;
addSigBracket(1, 2, sigYTOT, pTOT, 0.04*yRange);
ylim([yMin - 0.12*yRange, sigYTOT + 0.10*yRange]);
xlim([0.5 2.5]);
%ylim([0 0.5])
set(gca, 'XTick', 1:2, 'XTickLabel', lblGroupsXY, ...
    'FontSize', fontSize - 2);
ylabelTOT = 'Zeit auf Ziel [%]';
ylabel(ylabelTOT, 'FontSize', fontSize);
title(titleFromYLabel(ylabelTOT), 'FontSize', fontSize);
hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
legend([hFocused, hExpanded], lblGroupsXY, 'FontSize', fontSize - 4, 'Location', 'northeast');
xlim([0.5 2.5]);
box off; hold off;

saveas(gcf, fullfile(FIG_PATH, 'IAB_time_on_target_trials.png'));

featuresCsv = fullfile(DATA_PATH, 'IAB_features.csv');
T_features = buildFeaturesTable(trialStack, bd);
writetable(T_features, featuresCsv);
fprintf('Saved trial-level features: %s (%d trials)\n', featuresCsv, height(T_features));

statsCsv = fullfile(DATA_PATH, 'IAB_stats_results.csv');
writetable(statsTable, statsCsv);
fprintf('Saved trial-level stats: %s (%d tests)\n', statsCsv, height(statsTable));
fprintf('\n=== Trial-level figures saved to: %s ===\n', FIG_PATH);

%% ========================================================================
%  Local functions
%  ========================================================================

function t = titleFromYLabel(ylab)
% Title text matching ylabel but without bracketed or (%) unit suffixes.
t = strtrim(ylab);
t = regexprep(t, ' \[[^\]]*\]$', '');
t = regexprep(t, ' \(%\)$', '');
end

function S = applySdOutlierMask(S, fieldNames, nSD)
for k = 1:numel(fieldNames)
    fn = fieldNames{k};
    if ~isfield(S, fn) || isempty(S.(fn))
        continue;
    end
    v0 = S.(fn);
    v1 = maskSdOutliersNaN(v0(:), nSD);
    S.(fn) = reshape(v1, size(v0));
    nMasked = nnz(isfinite(v0) & ~isfinite(v1));
    if nMasked > 0
        fprintf('  %s: %d trial(s) masked\n', fn, nMasked);
    end
end
end

function v = maskSdOutliersNaN(v, nSD)
if nargin < 2 || isempty(nSD)
    nSD = 3;
end
v = double(v(:));
ok = isfinite(v);
if nnz(ok) < 3
    return;
end
mu = mean(v(ok));
sig = std(v(ok), 0);
if ~isfinite(mu) || ~isfinite(sig) || sig <= 0
    return;
end
out = ok & abs(v - mu) > nSD * sig;
v(out) = NaN;
end

function S = stackTrialFeatures(dataPath, subjects)
S = struct();
fields = {'subjectID', 'trial', 'group', 'crossPresent', 'gazeDeviation', 'gazeStdX', ...
    'gazeStdY', 'fixationCount', 'fixationDurMean', 'saccadeCount', 'saccadeAmpMean', ...
    'scanPathLength', 'pupilSize', 'timeOnTarget', 'contAccuracy', 'reactionTime'};
for f = 1:numel(fields)
    S.(fields{f}) = [];
end

for k = 1:numel(subjects)
    sid = num2str(subjects(k));
    fpath = fullfile(dataPath, sid, 'features_IAB.mat');
    if ~exist(fpath, 'file')
        continue;
    end
    D = load(fpath, 'trialFeatures');
    if ~isfield(D, 'trialFeatures')
        continue;
    end
    tf = D.trialFeatures;
    if ~isfield(tf, 'subjectID') || isempty(tf.subjectID)
        continue;
    end
    n = numel(tf.subjectID);
    for f = 1:numel(fields)
        fn = fields{f};
        if ~isfield(tf, fn)
            v = NaN(n, 1);
        else
            v = tf.(fn);
            v = v(:);
            if numel(v) ~= n
                v = reshape(v, [], 1);
                if numel(v) ~= n
                    v = NaN(n, 1);
                end
            end
        end
        S.(fn) = [S.(fn); v];
    end
end
end

function p = runIndependentTtest(x, y)
p = independentTtestStats(x, y).p;
end

function s = independentTtestStats(x, y)
x = x(isfinite(x));
y = y(isfinite(y));
s = struct('test', 'ttest2', 'n1', numel(x), 'n2', numel(y), ...
    'mean1', NaN, 'mean2', NaN, 't', NaN, 'df', NaN, 'p', NaN, 'd', NaN);
if numel(x) > 1 && numel(y) > 1
    [~, p, ~, st] = ttest2(x, y);
    s.mean1 = mean(x);
    s.mean2 = mean(y);
    s.t = st.tstat;
    s.df = st.df;
    s.p = p;
    s.d = (mean(x) - mean(y)) / sqrt((var(x) + var(y)) / 2);
end
end

function T = buildFeaturesTable(trialStack, bd)
% Trial-level table used for figure stats (outlier-masked values).
Tet = struct2table(trialStack);
etFields = {'gazeDeviation', 'gazeStdX', 'gazeStdY', 'fixationCount', ...
    'fixationDurMean', 'saccadeCount', 'saccadeAmpMean', 'scanPathLength', ...
    'pupilSize', 'timeOnTarget'};
etFields = etFields(ismember(etFields, Tet.Properties.VariableNames));
etOnly = Tet(:, [{'subjectID', 'trial'}, etFields]);

if ~isempty(bd)
    T = struct2table(bd);
    keep = intersect({'subjectID', 'trial', 'group', 'groupName', 'crossPresent', ...
        'contAccuracy', 'reactionTime'}, T.Properties.VariableNames, 'stable');
    T = T(:, keep);
    T = outerjoin(T, etOnly, 'Keys', {'subjectID', 'trial'}, 'MergeKeys', true);
else
    T = Tet;
    gn = strings(height(T), 1);
    gn(T.group == 0) = "Fokussiert";
    gn(T.group == 1) = "Erweitert";
    T.groupName = gn;
end

if ismember('crossPresent', T.Properties.VariableNames)
    T = renamevars(T, 'crossPresent', 'monkeyPresent');
end

orderStart = {'subjectID', 'trial', 'group', 'groupName', 'monkeyPresent'};
orderEnd = {'contAccuracy', 'reactionTime'};
orderMid = setdiff(T.Properties.VariableNames, [orderStart, orderEnd], 'stable');
T = T(:, [orderStart, orderMid, orderEnd]);
end

function T = appendTtestRow(T, variable, figureTag, comparison, x, y)
s = independentTtestStats(x, y);
row = table(string(variable), string(figureTag), string(comparison), string(s.test), ...
    s.n1, s.n2, s.mean1, s.mean2, s.t, s.df, s.p, s.d, string(pToStars(s.p)), ...
    'VariableNames', {'variable', 'figure', 'comparison', 'test', ...
    'n1', 'n2', 'mean1', 'mean2', 't', 'df', 'p', 'd', 'stars'});
T = [T; row]; %#ok<AGROW>
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
plot([x1 x1 x2 x2], [y - tick, y, y, y - tick], 'k-', 'LineWidth', 1.5);
text(mean([x1 x2]), y + 0.15 * tick, pToStars(p), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 14, 'FontWeight', 'bold');
end

function styleCurrentBoxplot(boxColors)
hBoxes = findobj(gca, 'Tag', 'Box');
if isempty(hBoxes)
    return;
end
nB = numel(hBoxes);
mx = zeros(nB, 1);
for ii = 1:nB
    xd = get(hBoxes(ii), 'XData');
    mx(ii) = mean(xd(:), 'omitnan');
end
[~, ord] = sort(mx);
hBoxes = hBoxes(ord);
for bi = 1:min(numel(hBoxes), size(boxColors, 1))
    cIdx = bi;
    patch(get(hBoxes(bi), 'XData'), get(hBoxes(bi), 'YData'), ...
        boxColors(cIdx, :), 'FaceAlpha', 0.25, 'EdgeColor', boxColors(cIdx, :), 'LineWidth', 1.5);
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

function bumpAxesTitleMargin(ax)
% Extra space above axes for significance brackets and title when ylim is tight.
if ~isgraphics(ax)
    return;
end
try
    li = ax.LooseInset;
    ax.LooseInset = li + [0.03 0.03 0.03 0.14];
catch
    li = get(ax, 'LooseInset');
    set(ax, 'LooseInset', li + [0.03 0.03 0.03 0.14]);
end
end

function [ax, testRows] = plotFourGroupTrialBoxplot(ax, yFA, yFP, yEA, yEP, boxPos4, ...
    jitter4, dotSize, colA, colB, fontSize, yLabelStr, titleStr, showLegend, ...
    variableName, figureTag, groupLabels)
% Four trial pools: Focused absent / present, Expanded absent / present at x 1,2,4,5.
% Brackets use independent two-sample t-tests on trial pools (not paired by subject).
if nargin < 16
    variableName = '';
    figureTag = '';
end
if nargin < 17 || isempty(groupLabels)
    groupLabels = {'Fokussiert', 'Erweitert'};
end
testRows = table();
axes(ax);
hold on;
boxColors4 = [colA; colA; colB; colB];
yy = {yFA(:), yFP(:), yEA(:), yEP(:)};
for k = 1:4
    yk = yy{k};
    yk = yk(isfinite(yk));
    yy{k} = yk;
    if isempty(yk)
        continue;
    end
    boxplot(yk, k * ones(numel(yk), 1), 'Positions', boxPos4(k), 'Symbol', '', ...
        'Widths', 0.45, 'Colors', 'k');
    scatter(boxPos4(k) + jitter4 * (rand(numel(yk), 1) - 0.5), yk, dotSize, ...
        boxColors4(k, :), 'filled', 'MarkerFaceAlpha', 0.45);
end
styleCurrentBoxplot(boxColors4);

yFA = yy{1};
yFP = yy{2};
yEA = yy{3};
yEP = yy{4};
valsAll = [yFA(:); yFP(:); yEA(:); yEP(:)];
valid = isfinite(valsAll);
if ~any(valid)
    hold off;
    title(ax, titleStr, 'FontSize', fontSize);
    ylabel(ax, yLabelStr, 'FontSize', fontSize);
    return;
end

pFocusedDist = runIndependentTtest(yFA, yFP);
pExpandedDist = runIndependentTtest(yEA, yEP);
pAbsentGrp = runIndependentTtest(yFA, yEA);
pPresentGrp = runIndependentTtest(yFP, yEP);
if ~isempty(variableName)
    testRows = appendTtestRow(testRows, variableName, figureTag, ...
        'Focused_monkeyAbsent_vs_present', yFA, yFP);
    testRows = appendTtestRow(testRows, variableName, figureTag, ...
        'Expanded_monkeyAbsent_vs_present', yEA, yEP);
    testRows = appendTtestRow(testRows, variableName, figureTag, ...
        'monkeyAbsent_Focused_vs_Expanded', yFA, yEA);
    testRows = appendTtestRow(testRows, variableName, figureTag, ...
        'monkeyPresent_Focused_vs_Expanded', yFP, yEP);
end

yMax = max(valsAll(valid));
yMin = min(valsAll(valid));
if isempty(yMax) || isempty(yMin)
    yMax = 1;
    yMin = 0;
end
yRange = max(eps, yMax - yMin);
sigStep = 0.10 * yRange;
sigBase = yMax + 0.08 * yRange;
sigLevels = sigBase + (0:3) * sigStep;
capH = 0.035 * yRange;
axes(ax);
addSigBracket(1, 2, sigLevels(1), pFocusedDist, capH);
axes(ax);
addSigBracket(4, 5, sigLevels(2), pExpandedDist, capH);
axes(ax);
addSigBracket(1, 4, sigLevels(3), pAbsentGrp, capH);
axes(ax);
addSigBracket(2, 5, sigLevels(4), pPresentGrp, capH);
ylim(ax, [yMin - 0.12 * yRange, sigLevels(end) + capH + 0.10 * yRange]);
xlim(ax, [0.5 5.5]);

set(ax, 'XTick', boxPos4, ...
    'XTickLabel', {'Affe abwesend', 'Affe anwesend', 'Affe abwesend', 'Affe anwesend'}, ...
    'FontSize', fontSize - 2);
addGroupedXAxisLabels(ax, [1.5 4.5], groupLabels);
ylabel(ax, yLabelStr, 'FontSize', fontSize);
title(ax, titleStr, 'FontSize', fontSize);
if showLegend
    hFocused = patch(nan, nan, colA, 'FaceAlpha', 0.25, 'EdgeColor', colA, 'LineWidth', 1.5);
    hExpanded = patch(nan, nan, colB, 'FaceAlpha', 0.25, 'EdgeColor', colB, 'LineWidth', 1.5);
    legend(ax, [hFocused, hExpanded], groupLabels, ...
        'FontSize', fontSize - 4, 'Location', 'northeast');
end
box(ax, 'off');
hold off;
end

function addGroupedXAxisLabels(ax, xCenters, labels)
yl = ylim(ax);
yRange = max(eps, yl(2) - yl(1));
yText = yl(1) - 0.12 * yRange;
if isprop(ax, 'FontSize')
    fs = ax.FontSize;
else
    fs = get(ax, 'FontSize');
end
for i = 1:numel(xCenters)
    text(ax, xCenters(i), yText, labels{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontSize', fs, ...
        'FontWeight', 'normal', ...
        'Clipping', 'off');
end
end

function H = normalizeHeatmap(H, kernel)
if sum(H(:)) > 0
    H = H ./ sum(H(:));
end
if nargin >= 2 && ~isempty(kernel)
    H = conv2(H, kernel, 'same');
end
end

function cmap = rdbuCmap(n)
if nargin < 1
    n = 256;
end
rdbu = [33 102 172; 67 147 195; 146 197 222; 209 229 240; 247 247 247; ...
    253 219 199; 244 165 130; 214 96 77; 178 24 43] / 255;
x = linspace(0, 1, size(rdbu, 1));
xi = linspace(0, 1, n);
cmap = interp1(x, rdbu, xi, 'linear');
end
