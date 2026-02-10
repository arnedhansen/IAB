%% IAB Task (Inattentional Blindness)
% This code requires PsychToolbox. https://psychtoolbox.org
%
% Task: Participants sum only BLACK digits (ignore white digits)
% - Always 12 numbers per trial (1-20)
% - Numbers are black or white
% - Two groups: Group A (focused) vs Group B (expanded attention)
% - Cross appears in 1/3 of trials (offset to side, appears 5s into 7s stimulus)
% - Cross does NOT appear in practice trials or first 2 real trials

%% Initialize Eye Tracking

% Start of block message in CW
if TRAINING == 1
    disp('START OF PRACTICE BLOCK');
else
    disp('START OF MAIN TASK');
    fprintf('Group: %s (%s)\n', subject.group, subject.groupName);
end

% Calibrate ET (Tobii Pro Fusion)
disp('CALIBRATING ET...');
calibrateET;

% Hide cursor on participant screen
HideCursor(whichScreen);

%% Define TRIGGERS
TASK_START = 10; % trigger for ET cutting

PRACTICE_START = 15; % Trigger for start of practice block
MAIN_TASK_START = 11; % Trigger for start of main task

FIXCROSS = 16; % Trigger for fixation cross

TRIAL_START = 20; % Trigger for start of trial
STIMULUS_START = 21; % Trigger for start of stimulus presentation
INPUT_START = 22; % Trigger for start of input period

CROSS_APPEAR = 30; % Trigger when cross appears
CROSS_DISAPPEAR = 31; % Trigger when cross disappears

RESPONSE_SUBMITTED = 50; % Trigger when response is submitted

PRACTICE_END = 75; % End of practice block
TASK_END = 90; % Trigger for ET cutting

%% Set up experiment parameters
% Block and Trial Number
exp.nTrlPractice = 3; % n practice trials
exp.nTrlMain = 100; % n main task trials

% Time estimate per participant (total ~25-30 minutes):
% - Setup/calibration: 2-3 minutes
% - Reading instructions: ~30 seconds
% - Practice trials: 3 trials × ~13 seconds = ~40 seconds (+ feedback ~1 min total)
% - Main task: 100 trials × ~13 seconds = ~22 minutes
% - Perception questions: 4 questions × ~10 seconds = ~40 seconds
% - Breaks/transitions: ~1 minute
% Total: ~25-30 minutes per participant

if TRAINING == 1
    exp.nTrials = exp.nTrlPractice;
else
    exp.nTrials = exp.nTrlMain;
end

%% Screenshot and Video Options
% Enable (= 1) or disable (= 0) screenshots of key frames
enableScreenshots = 1; % Screenshots of: fixation, stimulus start, cross appear, input screen

% Enable (= 1) or disable (= 0) video recording per trial
enableVideo = 1; % Records full trial (fixation + stimulus + input)

%% Set up text parameters
% Define startExperimentText based on group
if TRAINING == 1
    startExperimentText = [
        'PRACTICE TRIALS \n\n' ...
        'You will now complete 3 practice trials to familiarize yourself \n\n' ...
        'with the task. \n\n' ...
        '\n\n' ...
        'You will see black and white digits moving around the screen. \n\n' ...
        'Your task is to add together ONLY the BLACK numbers \n\n' ...
        'and ignore the white ones. \n\n' ...
        'At the end, you will be asked for the sum. \n\n' ...
        '\n\n' ...
        'Press any key to continue...'];
    loadingText = 'Loading PRACTICE...';
else
    % Group-specific instructions
    if subject.group == 'A'
        % Group A: Focused attention
        startExperimentText = [
            'Your task is to add together the BLACK numbers. \n\n' ...
            'Ignore the white numbers. \n\n' ...
            'At the end you will be asked for the result. \n\n' ...
            '\n\n' ...
            'Press any key to continue...'];
    else
        % Group B: Expanded attention
        startExperimentText = [
            'Your task is to calculate the sum of the BLACK numbers \n\n' ...
            'by adding them together. Ignore the white numbers. \n\n' ...
            'Additionally, visual changes may occur during the task. \n\n' ...
            'Please pay attention to everything that appears on the screen. \n\n' ...
            'At the end you will be asked for the result. \n\n' ...
            '\n\n' ...
            'Press any key to continue...'];
    end
    loadingText = 'Loading TASK...';
end

%% Set up standard Psychtoolbox Settings
global GL;
AssertOpenGL; % Check OpenGL Psychtoolbox

% Disable clipping of text
global ptb_drawformattedtext_disableClipping;
ptb_drawformattedtext_disableClipping = 1;

% Set verbosity to disallow CW output
Screen('Preference','Verbosity', 0);
%Screen('Preference', 'SkipSyncTests', 0); % For linux (can be 0)

% Retrieve key codes
spaceKeyCode = KbName('Space');
enterKeyCode = KbName('Return');
backspaceKeyCode = KbName('BackSpace');

%% Imaging set up
screen.ID = whichScreen; % Get index for stimulus presentation screen

% Background color (gray like GCP)
backgroundColorGray = 192; % Gray background

% Open a double buffered fullscreen window and select a gray background color:
[ptbWindow, winRect] = Screen('OpenWindow', screen.ID, backgroundColorGray);

% Get screen size and center coordinates
[screen.centerX, screen.centerY] = RectCenter(winRect); % Screen center in pixels
screen.width = 48; % Screen width in cm
screen.height = 29.89; % Screen height in cm
screen.resolutionX = 800; % Screen resolution width in pixels
screen.resolutionY = 600; % Screen resolution height in pixels
screen.viewDist = 80; % Viewing distance in cm from participant on head rest to screen center

% Calculate visual parameters
screen.totVisDeg = 2*atan(screen.width / (2*screen.viewDist))*(180/pi); % Calculate degrees of visual angle
screen.ppd = screen.resolutionX / screen.totVisDeg; % Pixels per degree
screen.ppd = 50; % Override with measured value

% Get frame duration
ifi = Screen('GetFlipInterval', ptbWindow);
frameRate = Screen('FrameRate', screen.ID); % MethLab 100 Hz

% Define color values (if not already defined by screenSettings)
if ~exist('black', 'var')
    black = BlackIndex(ptbWindow);
end
if ~exist('backColor', 'var')
    backColor = [0, 0, 0]; % black
end
if ~exist('backPos', 'var')
    backPos = [4, screen.resolutionY - 20];
end
if ~exist('backDiameter', 'var')
    backDiameter = 35;
end

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', ptbWindow, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%% Text parameters
Screen('TextSize', ptbWindow, 18); % Font size for instructions and stimuli (reduced)
Screen('TextFont', ptbWindow, 'Courier'); % Monospace font for digits

% Show loading text
DrawFormattedText(ptbWindow,loadingText,'center','center',black);
Screen('Flip',ptbWindow);

%% Fixation cross parameters
% Size
fixationSize_dva = 0.5; % Size of fixation cross in degrees of visual angle
fixationLineWidth = 2; % Line width of fixation cross

% Color
whiteLevel = WhiteIndex(ptbWindow); % Get RGB values for white
fixationColorWhite = [255 255 255]; % White fixation cross

% Location
fixationSize_pix = round(fixationSize_dva*screen.ppd);
fixHorizontal = [round(-fixationSize_pix/2) round(fixationSize_pix/2) 0 0];
fixVertical = [0 0 round(-fixationSize_pix/2) round(fixationSize_pix/2)];
fixCoords = [fixHorizontal; fixVertical];
fixPos = [screen.centerX, screen.centerY];

% Temporal parameters
timing.fixLower = 500; % Lower limit of fixation duration (ms)
timing.fixUpper = 1500; % Upper limit of fixation duration (ms)
timing.stimulusDuration = 7.0; % Stimulus presentation duration (seconds)
timing.inputDuration = 5.0; % Input period duration (seconds)
% Cross appears from the beginning and moves throughout stimulus period

%% Digit parameters
digitSize_dva = 1.5; % Size of digits in degrees of visual angle (increased)
digitSize_pix = round(digitSize_dva * screen.ppd);
digitColorBlack = [0 0 0]; % Black digits (to be summed)
digitColorWhite = [255 255 255]; % White digits (to be ignored)

% Movement parameters
digitSpeed = 2.5; % cm/s (will be converted to pixels)
digitSpeed_pix = digitSpeed * (screen.resolutionX / screen.width); % Convert to pixels per second

% Movement boundaries (leave some margin from edges)
margin = 50; % pixels
moveBounds = [margin, margin, screen.resolutionX - margin, screen.resolutionY - margin];

%% Cross parameters (for unexpected cross)
crossSize_dva = 1.5; % Size of cross in degrees of visual angle (same as digits, increased)
crossSize_pix = round(crossSize_dva * screen.ppd);
crossColor = [120 120 120]; % Grayish color (slightly darker than background)

% Cross horizontal/vertical extent
crossExtent = crossSize_pix / 2;
crossCoords = [-crossExtent crossExtent 0 0; 0 0 -crossExtent crossExtent];

% Cross movement parameters (moves randomly like digits)
crossSpeed = 2.5; % cm/s (same as digits)
crossSpeed_pix = crossSpeed * (screen.resolutionX / screen.width); % Convert to pixels per second

% Use realtime priority for better timing precision
priorityLevel = MaxPriority(ptbWindow);
Priority(priorityLevel);

%% Create data structure for preallocating data
data = struct;
data.digits(1, exp.nTrials) = {[]}; % Cell array to store which digits appeared
data.digitColors(1, exp.nTrials) = {[]}; % Cell array to store color of each digit (1=black, 0=white)
data.crossPresent(1, exp.nTrials) = NaN; % Binary: was cross present?
data.crossPosition(1, exp.nTrials) = {[]}; % Continuous cross position [x, y] sampled at 500 Hz
data.crossPositionTime(1, exp.nTrials) = {[]}; % Timestamps for each position sample
data.correctSum(1, exp.nTrials) = NaN; % Correct sum of BLACK digits only
data.participantSum(1, exp.nTrials) = NaN; % What participant entered
data.binaryAccuracy(1, exp.nTrials) = NaN; % Correct (1) or incorrect (0)
data.continuousAccuracy(1, exp.nTrials) = NaN; % Percentage deviation from correct sum
data.reactionTime(1, exp.nTrials) = NaN; % Time from stimulus end to response submission
data.trialDuration(1, exp.nTrials) = NaN; % Total trial duration

% Determine which trials will have cross (1/3 of trials, but not in practice or first 2 real trials)
if TRAINING == 1
    % No cross in practice trials
    crossTrials = zeros(1, exp.nTrials);
else
    % Cross in 1/3 of trials, but NOT in first 2 trials
    nCrossTrials = round(exp.nTrials / 3);
    crossTrials = zeros(1, exp.nTrials);
    % Randomly select trials for cross, excluding first 2
    availableTrials = 3:exp.nTrials;
    selectedTrials = randperm(length(availableTrials), nCrossTrials);
    crossTrials(availableTrials(selectedTrials)) = 1;
end

%% Show task instruction text
DrawFormattedText(ptbWindow, startExperimentText, 'center', 'center', black);
Screen('DrawDots',ptbWindow, backPos, backDiameter, backColor,[],1); % black background for photo diode
Screen('Flip',ptbWindow);
clc;
disp(upper('Participant is reading the instructions.'));
waitResponse = 1;
while waitResponse
    [time, keyCode] = KbWait(-1,2);
    waitResponse = 0;
end

% Send triggers for start of task (ET only)
if TRAINING == 1
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "START"');
    Eyelink('Message', num2str(PRACTICE_START));
    Eyelink('command', 'record_status_message "START PRACTICE"');
else
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "START"');
    Eyelink('Message', num2str(MAIN_TASK_START));
    Eyelink('command', 'record_status_message "START MAIN TASK"');
end

% Experiment prep
HideCursor(whichScreen); % Make sure to hide cursor from participant screen
timing.startTime = datestr(now, 'dd/mm/yy-HH:MM:SS'); % Measure duration

% Set up paths for screenshots and videos (after subject.ID is available)
if enableScreenshots || enableVideo
    subjectID = num2str(subject.ID);
    SCREENSHOT_PATH = fullfile(DATA_PATH, subjectID, 'screenshots');
    VIDEO_PATH = fullfile(DATA_PATH, subjectID, 'videos');
    if enableScreenshots && ~exist(SCREENSHOT_PATH, 'dir')
        mkdir(SCREENSHOT_PATH);
    end
    if enableVideo && ~exist(VIDEO_PATH, 'dir')
        mkdir(VIDEO_PATH);
    end
end

%% Experiment Loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc;
if TRAINING == 1
    disp('IAB PRACTICE TRIALS...');
else
    disp('IAB MAIN TASK...');
end

for trl = 1:exp.nTrials
    tic;
    
    % Store trial condition
    data.crossPresent(trl) = crossTrials(trl);
    
    %% Present jittered fixation cross
    Screen('FillRect', ptbWindow, backgroundColorGray);
    Screen('Flip', ptbWindow);
    
    % Jittered fixation duration
    timing.fixDuration(trl) = (randsample(timing.fixLower:timing.fixUpper, 1))/1000; % Convert to seconds
    
    % Draw white fixation cross
    Screen('DrawLines', ptbWindow, fixCoords, fixationLineWidth, fixationColorWhite, ...
           [screen.centerX screen.centerY], 2);
    Screen('Flip', ptbWindow);
    
    % Screenshot: Fixation cross
    if enableScreenshots
        screenshotFilename = fullfile(SCREENSHOT_PATH, sprintf('trial%03d_fixation.png', trl));
        screenshot(screenshotFilename, ptbWindow, enableScreenshots);
    end
    
    % Initialize video recording for this trial
    if enableVideo
        videoFilename = fullfile(VIDEO_PATH, sprintf('trial%03d.avi', trl));
        videoWriter = VideoWriter(videoFilename, 'Motion JPEG AVI');
        videoWriter.FrameRate = 30; % Record at 30 fps (reduced from screen refresh rate)
        videoWriter.Quality = 90;
        open(videoWriter);
        lastVideoFrameTime = GetSecs;
        videoFrameInterval = 1/30; % Capture every 1/30 second
    end
    
    % Send fixation trigger (ET only)
    TRIGGER = FIXCROSS;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "FIXCROSS"');
    
    WaitSecs(timing.fixDuration(trl));
    
    %% Initialize digit positions and movements
    nDigits = 12; % Always 12 digits
    digits = randi([1 20], 1, nDigits); % Random digits 1-20
    
    % Randomly assign colors: always 6 black and 6 white
    digitColors = zeros(1, nDigits);
    blackIndices = randperm(nDigits, 6); % Always exactly 6 black digits
    digitColors(blackIndices) = 1; % 1 = black, 0 = white
    
    data.digits{trl} = digits;
    data.digitColors{trl} = digitColors;
    
    % Calculate correct sum (only black digits)
    blackDigits = digits(digitColors == 1);
    data.correctSum(trl) = sum(blackDigits);
    
    % Initialize positions (random starting positions)
    digitPos = zeros(nDigits, 2);
    digitVel = zeros(nDigits, 2);
    for d = 1:nDigits
        digitPos(d, 1) = randi([moveBounds(1), moveBounds(3)]);
        digitPos(d, 2) = randi([moveBounds(2), moveBounds(4)]);
        % Random velocity direction (in pixels per second)
        angle = rand * 2 * pi;
        digitVel(d, 1) = cos(angle) * digitSpeed_pix;
        digitVel(d, 2) = sin(angle) * digitSpeed_pix;
    end
    
    % Initialize cross position and movement (if present)
    crossX = NaN;
    crossY = NaN;
    crossVel = [NaN, NaN];
    crossVisible = false;
    
    % Initialize continuous position recording (500 Hz sampling for eye tracker)
    eyeTrackerSamplingRate = 500; % Hz
    sampleInterval = 1 / eyeTrackerSamplingRate; % 0.002 seconds between samples
    crossPositionSamples = []; % Will store [x, y] positions
    crossPositionTimes = []; % Will store timestamps
    lastSampleTime = NaN;
    
    if data.crossPresent(trl) == 1
        % Random starting position (within movement bounds)
        crossX = randi([moveBounds(1), moveBounds(3)]);
        crossY = randi([moveBounds(2), moveBounds(4)]);
        % Random velocity direction (moves randomly like digits)
        angle = rand * 2 * pi;
        crossVel(1) = cos(angle) * crossSpeed_pix;
        crossVel(2) = sin(angle) * crossSpeed_pix;
        crossVisible = true; % Cross appears from the beginning
    end
    
    % Store last frame time for time-based movement
    lastFrameTime = GetSecs;
    
    % Send trial start trigger (ET only)
    TRIGGER = TRIAL_START;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "TRIAL_START"');
    
    % Send stimulus start trigger (ET only)
    TRIGGER = STIMULUS_START;
    stimulusStartTime = GetSecs;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "STIMULUS_START"');
    
    % Initialize position sampling for distractor (if present) at 500 Hz
    if data.crossPresent(trl) == 1
        % Record initial position at stimulus start
        crossPositionSamples = [crossX, crossY];
        crossPositionTimes = stimulusStartTime;
        lastSampleTime = stimulusStartTime;
    end
    
    % Screenshot: Stimulus start (number cloud)
    if enableScreenshots
        % Draw first frame of stimulus for screenshot
        Screen('FillRect', ptbWindow, backgroundColorGray);
        for d = 1:nDigits
            digitText = num2str(digits(d));
            Screen('TextSize', ptbWindow, digitSize_pix);
            [textBounds] = Screen('TextBounds', ptbWindow, digitText);
            textWidth = textBounds(3) - textBounds(1);
            textHeight = textBounds(4) - textBounds(2);
            if digitColors(d) == 1
                Screen('DrawText', ptbWindow, digitText, ...
                       digitPos(d, 1) - textWidth/2, digitPos(d, 2) - textHeight/2, ...
                       digitColorBlack);
            else
                Screen('DrawText', ptbWindow, digitText, ...
                       digitPos(d, 1) - textWidth/2, digitPos(d, 2) - textHeight/2, ...
                       digitColorWhite);
            end
        end
        Screen('Flip', ptbWindow);
        screenshotFilename = fullfile(SCREENSHOT_PATH, sprintf('trial%03d_stimulus_start.png', trl));
        screenshot(screenshotFilename, ptbWindow, enableScreenshots);
    end
    
    %% Stimulus presentation loop (7000ms)
    frameCount = 0;
    while (GetSecs - stimulusStartTime) < timing.stimulusDuration
        % Calculate time delta for smooth movement
        currentTime = GetSecs;
        deltaTime = currentTime - lastFrameTime;
        lastFrameTime = currentTime;
        
        % Clear screen
        Screen('FillRect', ptbWindow, backgroundColorGray);
        
        % Update and draw digits
        for d = 1:nDigits
            % Update position (time-based movement)
            digitPos(d, 1) = digitPos(d, 1) + digitVel(d, 1) * deltaTime;
            digitPos(d, 2) = digitPos(d, 2) + digitVel(d, 2) * deltaTime;
            
            % Bounce off edges
            if digitPos(d, 1) <= moveBounds(1) || digitPos(d, 1) >= moveBounds(3)
                digitVel(d, 1) = -digitVel(d, 1);
                digitPos(d, 1) = max(moveBounds(1), min(moveBounds(3), digitPos(d, 1)));
            end
            if digitPos(d, 2) <= moveBounds(2) || digitPos(d, 2) >= moveBounds(4)
                digitVel(d, 2) = -digitVel(d, 2);
                digitPos(d, 2) = max(moveBounds(2), min(moveBounds(4), digitPos(d, 2)));
            end
            
            % Draw digit with appropriate color
            digitText = num2str(digits(d));
            Screen('TextSize', ptbWindow, digitSize_pix);
            [textBounds] = Screen('TextBounds', ptbWindow, digitText);
            textWidth = textBounds(3) - textBounds(1);
            textHeight = textBounds(4) - textBounds(2);
            
            if digitColors(d) == 1
                % Black digit
                Screen('DrawText', ptbWindow, digitText, ...
                       digitPos(d, 1) - textWidth/2, digitPos(d, 2) - textHeight/2, ...
                       digitColorBlack);
            else
                % White digit
                Screen('DrawText', ptbWindow, digitText, ...
                       digitPos(d, 1) - textWidth/2, digitPos(d, 2) - textHeight/2, ...
                       digitColorWhite);
            end
        end
        
        % Update and draw cross if present (moves randomly like digits)
        if data.crossPresent(trl) == 1 && crossVisible
            % Update cross position (time-based movement, same as digits)
            crossX = crossX + crossVel(1) * deltaTime;
            crossY = crossY + crossVel(2) * deltaTime;
            
            % Bounce off edges (same as digits)
            if crossX <= moveBounds(1) || crossX >= moveBounds(3)
                crossVel(1) = -crossVel(1);
                crossX = max(moveBounds(1), min(moveBounds(3), crossX));
            end
            if crossY <= moveBounds(2) || crossY >= moveBounds(4)
                crossVel(2) = -crossVel(2);
                crossY = max(moveBounds(2), min(moveBounds(4), crossY));
            end
            
            % Record position at 500 Hz sampling rate (eye tracker rate)
            % Position only changes when frame updates, so record current position
            % whenever enough time has passed for next sample
            currentTime = GetSecs;
            timeSinceLastSample = currentTime - lastSampleTime;
            
            if timeSinceLastSample >= sampleInterval
                % Calculate how many samples we should record (catch up if needed)
                nSamplesToRecord = floor(timeSinceLastSample / sampleInterval);
                
                % Record the current position for each sample interval that passed
                for s = 1:nSamplesToRecord
                    sampleTime = lastSampleTime + s * sampleInterval;
                    crossPositionSamples = [crossPositionSamples; crossX, crossY];
                    crossPositionTimes = [crossPositionTimes; sampleTime];
                end
                
                lastSampleTime = lastSampleTime + nSamplesToRecord * sampleInterval;
            end
            
            % Draw cross
            Screen('DrawLines', ptbWindow, crossCoords, fixationLineWidth, ...
                   crossColor, [crossX crossY], 2);
            
            % Screenshot: Cross appear (only once at start)
            elapsedTime = GetSecs - stimulusStartTime;
            if enableScreenshots && elapsedTime < 0.1
                screenshotFilename = fullfile(SCREENSHOT_PATH, sprintf('trial%03d_cross_appear.png', trl));
                screenshot(screenshotFilename, ptbWindow, enableScreenshots);
            end
            
            % Send cross appear trigger (only once at start)
            if elapsedTime < 0.1
                TRIGGER = CROSS_APPEAR;
                Eyelink('Message', num2str(TRIGGER));
                Eyelink('command', 'record_status_message "CROSS_APPEAR"');
            end
        end
        
        Screen('Flip', ptbWindow);
        frameCount = frameCount + 1;
        
        % Capture frame for video (at reduced frame rate)
        if enableVideo
            currentTime = GetSecs;
            if (currentTime - lastVideoFrameTime) >= videoFrameInterval
                frameImage = Screen('GetImage', ptbWindow);
                writeVideo(videoWriter, frameImage);
                lastVideoFrameTime = currentTime;
            end
        end
    end
    
    % Store continuous distractor positions (sampled at 500 Hz)
    if data.crossPresent(trl) == 1
        data.crossPosition{trl} = crossPositionSamples; % N×2 matrix: [x, y] positions
        data.crossPositionTime{trl} = crossPositionTimes; % N×1 vector: timestamps
    else
        data.crossPosition{trl} = [];
        data.crossPositionTime{trl} = [];
    end
    
    %% Input period (3000ms)
    inputStartTime = GetSecs;
    
    % Screenshot: Input screen (before any input)
    if enableScreenshots
        Screen('FillRect', ptbWindow, backgroundColorGray);
        promptText = 'Enter the sum of BLACK numbers:';
        Screen('TextSize', ptbWindow, 20);
        [textBounds] = Screen('TextBounds', ptbWindow, promptText);
        textWidth = textBounds(3) - textBounds(1);
        Screen('DrawText', ptbWindow, promptText, ...
               screen.centerX - textWidth/2, screen.centerY, black);
        Screen('Flip', ptbWindow);
        screenshotFilename = fullfile(SCREENSHOT_PATH, sprintf('trial%03d_input.png', trl));
        screenshot(screenshotFilename, ptbWindow, enableScreenshots);
    end
    
    % Send input start trigger (ET only)
    TRIGGER = INPUT_START;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "INPUT_START"');
    
    % Input loop
    inputString = '';
    responseSubmitted = false;
    lastKeyTime = 0;
    keyDebounceTime = 0.15; % Time to wait between key presses
    
    while (GetSecs - inputStartTime) < timing.inputDuration && ~responseSubmitted
        % Clear screen
        Screen('FillRect', ptbWindow, backgroundColorGray);
        
        % Display input prompt and current input
        promptText = 'Enter the sum of BLACK numbers:';
        inputDisplayText = [promptText ' ' inputString];
        
        Screen('TextSize', ptbWindow, 20); % Reduced text size
        [textBounds] = Screen('TextBounds', ptbWindow, inputDisplayText);
        textWidth = textBounds(3) - textBounds(1);
        Screen('DrawText', ptbWindow, inputDisplayText, ...
               screen.centerX - textWidth/2, screen.centerY, black);
        
        Screen('Flip', ptbWindow);
        
        % Capture frame for video during input phase (at reduced frame rate)
        if enableVideo
            currentTime = GetSecs;
            if (currentTime - lastVideoFrameTime) >= videoFrameInterval
                frameImage = Screen('GetImage', ptbWindow);
                writeVideo(videoWriter, frameImage);
                lastVideoFrameTime = currentTime;
            end
        end
        
        % Check for keyboard input (only if enough time has passed since last key)
        currentTime = GetSecs;
        if (currentTime - lastKeyTime) >= keyDebounceTime
            [keyIsDown, secs, keyCode] = KbCheck(-1);
            if keyIsDown
                keyPressed = false;
                
                % Check for backspace first
                if any(keyCode(backspaceKeyCode))
                    if length(inputString) > 0
                        inputString = inputString(1:end-1);
                    end
                    lastKeyTime = currentTime;
                    keyPressed = true;
                end
                
                % Check for enter (submit response)
                if ~keyPressed && any(keyCode(enterKeyCode)) && length(inputString) > 0
                    responseSubmitted = true;
                    responseTime = GetSecs - inputStartTime;
                    data.participantSum(trl) = str2double(inputString);
                    
                    % Send response submitted trigger (ET only)
                    TRIGGER = RESPONSE_SUBMITTED;
                    Eyelink('Message', num2str(TRIGGER));
                    Eyelink('command', 'record_status_message "RESPONSE_SUBMITTED"');
                    break;
                end
                
                % Check for any other key (allow all keys including letters)
                if ~keyPressed
                    % Get the key name
                    keyName = KbName(keyCode);
                    if iscell(keyName)
                        keyName = keyName{1}; % Take first if multiple
                    end
                    
                    % Process key if it's a single character or space
                    if ~isempty(keyName)
                        if length(keyName) == 1
                            % Single character key - add to input string
                            inputString = [inputString keyName];
                            lastKeyTime = currentTime;
                        elseif strcmpi(keyName, 'space')
                            inputString = [inputString ' '];
                            lastKeyTime = currentTime;
                        end
                    end
                end
            end
        end
        
        WaitSecs(0.01); % Small delay to prevent excessive CPU usage
    end
    
    % If no response submitted, show "Too Slow!" message
    if ~responseSubmitted
        % Show "Too Slow!" message
        Screen('FillRect', ptbWindow, backgroundColorGray);
        Screen('TextSize', ptbWindow, 20);
        slowText = 'Too Slow!';
        [textBounds] = Screen('TextBounds', ptbWindow, slowText);
        textWidth = textBounds(3) - textBounds(1);
        Screen('DrawText', ptbWindow, slowText, ...
               screen.centerX - textWidth/2, screen.centerY, black);
        Screen('Flip', ptbWindow);
        WaitSecs(1.5); % Show message for 1.5 seconds
        
        % Record response
        if length(inputString) > 0
            data.participantSum(trl) = str2double(inputString);
        else
            data.participantSum(trl) = NaN;
        end
        responseTime = timing.inputDuration;
    end
    
    % Calculate accuracy metrics
    correctSum = data.correctSum(trl);
    participantSum = data.participantSum(trl);
    
    if ~isnan(participantSum) && participantSum == correctSum
        data.binaryAccuracy(trl) = 1; % Correct
    else
        data.binaryAccuracy(trl) = 0; % Incorrect
    end
    
    % Continuous accuracy (percentage deviation)
    if ~isnan(participantSum) && correctSum ~= 0
        data.continuousAccuracy(trl) = abs((participantSum - correctSum) / correctSum) * 100;
    elseif ~isnan(participantSum) && correctSum == 0
        % Special case: correct sum is 0
        if participantSum == 0
            data.continuousAccuracy(trl) = 0;
        else
            data.continuousAccuracy(trl) = 100; % Maximum deviation
        end
    else
        data.continuousAccuracy(trl) = NaN;
    end
    
    data.reactionTime(trl) = responseTime;
    data.trialDuration(trl) = toc;
    
    % Close video recording for this trial
    if enableVideo
        close(videoWriter);
        fprintf('Video saved: %s\n', videoFilename);
    end
    
    %% Feedback for practice trials
    if TRAINING == 1
        Screen('FillRect', ptbWindow, backgroundColorGray);
        Screen('TextSize', ptbWindow, 20);
        
        if data.binaryAccuracy(trl) == 1
            feedbackText = 'Correct!';
            feedbackColor = [0 150 0]; % Green
        else
            feedbackText = 'Incorrect!';
            feedbackColor = [200 0 0]; % Red
        end
        
        [textBounds] = Screen('TextBounds', ptbWindow, feedbackText);
        textWidth = textBounds(3) - textBounds(1);
        Screen('DrawText', ptbWindow, feedbackText, ...
               screen.centerX - textWidth/2, screen.centerY, feedbackColor);
        
        % Also show correct answer
        correctAnswerText = ['Correct answer: ' num2str(correctSum)];
        Screen('TextSize', ptbWindow, 16);
        [textBounds2] = Screen('TextBounds', ptbWindow, correctAnswerText);
        textWidth2 = textBounds2(3) - textBounds2(1);
        Screen('DrawText', ptbWindow, correctAnswerText, ...
               screen.centerX - textWidth2/2, screen.centerY + 40, black);
        
        Screen('Flip', ptbWindow);
        WaitSecs(2.0); % Show feedback for 2 seconds
    end
    
    %% Trial Info CW output
    overall_accuracy = round((nansum(data.binaryAccuracy(1:trl))/trl)*100);
    crossInfo = '';
    if data.crossPresent(trl) == 1
        crossInfo = ' | Cross: YES';
    else
        crossInfo = ' | Cross: NO';
    end
    
    nBlackDigits = sum(data.digitColors{trl});
    disp(['Trial ' num2str(trl) '/' num2str(exp.nTrials) ...
          ' | Black Digits: ' num2str(nBlackDigits) ...
          crossInfo ...
          ' | Correct Sum: ' num2str(correctSum) ...
          ' | Participant Sum: ' num2str(participantSum) ...
          ' | Binary Acc: ' num2str(data.binaryAccuracy(trl)) ...
          ' | Cont Acc: ' num2str(round(data.continuousAccuracy(trl), 2)) '%' ...
          ' | Overall Acc: ' num2str(overall_accuracy) '%']);
end

%% End task and save data

% Send triggers to end task
Screen('Flip',ptbWindow);

% Send triggers for block end (ET only)
if TRAINING == 1
    TRIGGER = PRACTICE_END;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END PRACTICE"');
    disp('End of Practice Block.');
else
    TRIGGER = TASK_END;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END TASK"');
    disp('End of Main Task');
end

% Send triggers for end of task (ET only)
Eyelink('Message', num2str(TASK_END));
Eyelink('command', 'record_status_message "TASK_END"');

%% Perception Questions (only after main task, not practice)
perceptionData = struct;
if TRAINING == 0
    % Show perception questions
    Screen('FillRect', ptbWindow, backgroundColorGray);
    
    questions = {
        'Ist Ihnen etwas Ungewöhnliches aufgefallen (während des Zusammenzählens der Ziffern)?';
        'Haben Sie abgesehen von den Zahlen sonst noch etwas gesehen?';
        'Haben Sie ein Objekt bemerkt, das nichts mit Zahlen zu tun hatte?';
        'Haben Sie ein Kreuz gesehen?'
    };
    
    questionKeys = {'Q1', 'Q2', 'Q3', 'Q4'};
    yesKeyCode = KbName('Y');
    noKeyCode = KbName('N');
    
    for q = 1:length(questions)
        questionText = questions{q};
        responseGiven = false;
        response = NaN; % 1 = yes, 0 = no
        
        while ~responseGiven
            Screen('FillRect', ptbWindow, backgroundColorGray);
            
            % Display question
            Screen('TextSize', ptbWindow, 25);
            DrawFormattedText(ptbWindow, questionText, 'center', screen.centerY - 50, black);
            
            % Display instructions
            instructionText = 'Press Y for YES, N for NO';
            Screen('TextSize', ptbWindow, 20);
            DrawFormattedText(ptbWindow, instructionText, 'center', screen.centerY + 50, black);
            
            Screen('Flip', ptbWindow);
            
            % Check for response
            [keyIsDown, secs, keyCode] = KbCheck(-1);
            if keyIsDown
                if keyCode(yesKeyCode)
                    response = 1;
                    responseGiven = true;
                    WaitSecs(0.3);
                elseif keyCode(noKeyCode)
                    response = 0;
                    responseGiven = true;
                    WaitSecs(0.3);
                end
            end
            WaitSecs(0.01);
        end
        
        perceptionData.(questionKeys{q}) = response;
        if response == 1
            fprintf('Question %d: YES\n', q);
        else
            fprintf('Question %d: NO\n', q);
        end
    end
end

%% Record block duration
timing.endTime = datestr(now, 'dd/mm/yy-HH:MM:SS');
% Convert to datetime objects
startTime = datetime(timing.startTime, 'InputFormat', 'dd/MM/yy-HH:mm:ss');
endTime = datetime(timing.endTime, 'InputFormat', 'dd/MM/yy-HH:mm:ss');
% Calculate block duration in seconds
timing.duration = seconds(endTime - startTime);

%% Save data
subjectID = num2str(subject.ID);
filePath = fullfile(DATA_PATH, subjectID);
mkdir(filePath)

if TRAINING == 1
    fileName = [subjectID, '_practice.mat'];
else
    fileName = [subjectID, '_IAB.mat'];
end

% Save data
saves = struct;
saves.data = data;
saves.experiment = exp;
saves.screen = screen;
saves.startExperimentText = startExperimentText;
saves.subjectID = subjectID;
saves.subject = subject; % Includes group assignment
saves.timing = timing;
if TRAINING == 0
    saves.perceptionData = perceptionData; % Perception question responses
end

% Save triggers
trigger = struct;
trigger.TASK_START = TASK_START;
trigger.PRACTICE_START = PRACTICE_START;
trigger.MAIN_TASK_START = MAIN_TASK_START;
trigger.FIXCROSS = FIXCROSS;
trigger.TRIAL_START = TRIAL_START;
trigger.STIMULUS_START = STIMULUS_START;
trigger.INPUT_START = INPUT_START;
trigger.CROSS_APPEAR = CROSS_APPEAR;
trigger.CROSS_DISAPPEAR = CROSS_DISAPPEAR;
trigger.RESPONSE_SUBMITTED = RESPONSE_SUBMITTED;
trigger.PRACTICE_END = PRACTICE_END;
trigger.TASK_END = TASK_END;

%% Stop and close Eye Tracking recordings
if TRAINING == 1
    disp('PRACTICE FINISHED...');
else
    disp('MAIN TASK FINISHED...');
end
disp('SAVING DATA...');
save(fullfile(filePath, fileName), 'saves', 'trigger');
closeEEGandET;

try
    PsychPortAudio('Close');
catch
end

%% Show break instruction text
if TRAINING == 1
    breakInstructionText = 'Well done! \n\n Press any key to start the main task.';
else
    breakInstructionText = ['End of the Task! ' ...
        '\n\n Thank you very much for your participation.'...
        '\n\n Please press any key to finalize the experiment.'];
end

DrawFormattedText(ptbWindow,breakInstructionText,'center','center',black);
Screen('Flip',ptbWindow);
waitResponse = 1;
while waitResponse
    [time, keyCode] = KbWait(-1,2);
    waitResponse = 0;
end

% Show final screen
if TRAINING == 0
    FinalText = ['You are done.' ...
        '\n\n Have a great day!'];
    DrawFormattedText(ptbWindow, FinalText, 'center', 'center', black);
    Screen('Flip',ptbWindow);
    WaitSecs(2);
end

%% Close Psychtoolbox window
Priority(0);
Screen('Close');
Screen('CloseAll');
