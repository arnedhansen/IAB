%% IAB Visualization Runner for Simulated Data
% Builds a minimal behavioral_summary.mat for simulated data (if needed),
% then runs IAB_visualize.m with simulated input/output paths.

%% Setup
clear; clc; close all;

SIM_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/simulated_data';
FIG_PATH = '/Volumes/g_psyplafor_methlab$/Students/Arne/IAB/data/simulated_data/figures';

if ~exist(FIG_PATH, 'dir')
    mkdir(FIG_PATH);
end

% Ensure paths are normalized for generated script text replacement.
if SIM_PATH(end) ~= filesep
    SIM_PATH = [SIM_PATH, filesep];
end
if FIG_PATH(end) ~= filesep
    FIG_PATH = [FIG_PATH, filesep];
end

%% Ensure behavioral_summary.mat exists for visualization
behFile = fullfile(SIM_PATH, 'behavioral_summary.mat');
if ~exist(behFile, 'file')
    load(fullfile(SIM_PATH, 'features_all.mat'), 'allFeatures');
    subjects = unique([allFeatures.subjectID]);

    subjMeans = struct('subjectID', {}, 'group', {}, 'groupName', {}, ...
        'contAccuracy', {}, 'rt', {}, ...
        'contAcc_noDist', {}, 'contAcc_dist', {}, ...
        'rt_noDist', {}, 'rt_dist', {});

    for i = 1:numel(subjects)
        sid = subjects(i);
        etFile = fullfile(SIM_PATH, num2str(sid), 'etData_IAB.mat');
        if ~exist(etFile, 'file')
            continue;
        end

        S = load(etFile, 'etData');
        etData = S.etData;

        acc = etData.continuousAccuracy(:)';
        rt  = etData.reactionTime(:)';
        cp  = etData.crossPresent(:)';

        row = struct();
        row.subjectID = sid;
        row.group = strcmp(etData.group, 'B');
        row.groupName = etData.groupName;
        row.contAccuracy = mean(acc, 'omitnan');
        row.rt = mean(rt, 'omitnan');
        row.contAcc_noDist = mean(acc(cp == 0), 'omitnan');
        row.contAcc_dist   = mean(acc(cp == 1), 'omitnan');
        row.rt_noDist      = mean(rt(cp == 0), 'omitnan');
        row.rt_dist        = mean(rt(cp == 1), 'omitnan');

        subjMeans(end+1) = row; %#ok<AGROW>
    end

    behavioral_summary = struct();
    behavioral_summary.behavData = [];
    behavioral_summary.subjMeans = subjMeans;
    behavioral_summary.perception = [];

    save(behFile, 'behavioral_summary');
    fprintf('Created: %s\n', behFile);
end

%% Run visualization with simulated paths by patching script in temp file
srcVis = '/Users/Arne/Documents/GitHub/IAB/visualization/IAB_visualize.m';
txt = fileread(srcVis);

% Robust replacement: tolerate whitespace/style changes in source script.
dataPat = "DATA_PATH\s*=\s*'[^']*';";
figPat  = "FIG_PATH\s*=\s*'[^']*';";
nData = numel(regexp(txt, dataPat, 'match'));
nFig  = numel(regexp(txt, figPat, 'match'));

txt = regexprep(txt, dataPat, "DATA_PATH = '" + SIM_PATH + "';");
txt = regexprep(txt, figPat,  "FIG_PATH  = '" + FIG_PATH + "';");

if nData ~= 1 || nFig ~= 1
    error(['Could not patch DATA_PATH/FIG_PATH in IAB_visualize.m. ', ...
           'Check path assignment lines before running simulated visualization.']);
end

tmpScript = [tempname, '.m'];
fid = fopen(tmpScript, 'w');
fwrite(fid, txt);
fclose(fid);

run(tmpScript);

fprintf('Simulated figures written to: %s\n', FIG_PATH);
