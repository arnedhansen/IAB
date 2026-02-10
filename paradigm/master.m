%% Master script for the IAB (Inattentional Blindness) Study
%
% - Practice trials (3 trials, no cross)
% - Main task (100 trials: ~33 with cross, ~67 without cross)
%   - Cross does NOT appear in first 2 real trials
%   - Cross appears in 1/3 of remaining trials
% - Two groups: Group A (focused attention) vs Group B (expanded attention)
%   - Assignment based on Subject ID (201-220)
%   - Group A: Odd IDs (201, 203, ..., 219) - 10 subjects
%   - Group B: Even IDs (202, 204, ..., 220) - 10 subjects

%% General settings, screens and paths

% Set up MATLAB workspace
clear all;
close all;
clc;

% Define paths
PPDEV_PATH = '/home/methlab/Documents/MATLAB/ppdev-mex-master'; % For sending EEG triggers
DATA_PATH = '/home/methlab/Desktop/IAB_data'; % Folder to save data
FUNS_PATH = '/home/methlab/Desktop/IAB'; % Folder with all functions

addpath(FUNS_PATH) % Add path to folder with functions
screenSettings % Manage screens

%% Collect ID and Age
dialogID;

%% Group assignment based on Subject ID (201-220)
% Group A: Focused attention instruction (Odd IDs: 201, 203, 205, ..., 219)
% Group B: Expanded attention instruction (Even IDs: 202, 204, 206, ..., 220)
% Total: 10 subjects per group

% Check if subject ID is in valid range
if subject.ID < 201 || subject.ID > 220
    warning('Subject ID %d is outside expected range (201-220)', subject.ID);
end

% Assign group based on odd/even ID
if mod(subject.ID, 2) == 1
    % Odd ID -> Group A
    subject.group = 'A';
    subject.groupName = 'Focused Attention';
else
    % Even ID -> Group B
    subject.group = 'B';
    subject.groupName = 'Expanded Attention';
end
fprintf('Subject %d assigned to Group %s (%s)\n', subject.ID, subject.group, subject.groupName);

%% Protect Matlab code from participant keyboard input
ListenChar(2);

%% Check for existing files and start tasks

if ~isfile([DATA_PATH, '/', num2str(subject.ID), '/', [num2str(subject.ID), '_practice.mat']])
    TRAINING = 1;
    TASK = 'IAB';
    IAB_task;
else
    disp('PRACTICE DATA ALREADY EXISTS');
end

TRAINING = 0;
TASK = 'IAB';
if isfile([DATA_PATH, '/', num2str(subject.ID), '/', [num2str(subject.ID), '_IAB.mat']])
    disp('MAIN TASK DATA ALREADY EXISTS');
else
    disp([TASK, ' STARTING...']);
    IAB_task; % Run the task
end

%% Allow keyboard input into Matlab code
ListenChar(0);
disp('IAB RECORDING FINISHED')
