%% Master script for the IAB (Inattentional Blindness) Study
%
% - Practice trials (5 trials, no cross)
% - Main task (100 trials: ~33 with cross, ~67 without cross)
%   - Cross does NOT appear in first 2 real trials
%   - Cross appears in 1/3 of remaining trials

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
% subject.ID = 991; %Set to 999 for tests

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
