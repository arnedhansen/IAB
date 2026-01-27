%% IAB Task (Inattentional Blindness)
% This code requires PsychToolbox. https://psychtoolbox.org
%
% Task: Participants add together all digits moving on screen
% - Two conditions: 4 digits or 8 digits per trial
% - Digits move randomly and bounce off edges
% - Cross appears in 1/3 of trials (moving across screen)
% - Cross does NOT appear in practice trials or first 2 real trials

%% Initialize EEG and ET

% Start of block message in CW
if TRAINING == 1
    disp('START OF PRACTICE BLOCK');
else
    disp('START OF MAIN TASK');
end

% Calibrate ET (Tobii Pro Fusion)
disp('CALIBRATING ET...');
calibrateET;

if TRAINING == 0
    % Start recording EEG
    disp('STARTING EEG RECORDING...');
    initEEG;

    % Wait ten seconds to initialize EEG
    clc
    disp('INITIALIZING EEG... PLEASE WAIT 10 SECONDS')
    for i=1:10
        if i > 1
            wbar = findall(0,'type','figure','tag','TMWWaitbar');
            delete(wbar)
        end
        waitbar(i/10, 'INITIALIZING EEG');
        pause(1);
    end
    wbar = findall(0,'type','figure','tag','TMWWaitbar');
    delete(wbar)
    clc
    disp('EEG INITIALIZED!')
end

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

CONDITION_4_DIGITS = 40; % Trigger for 4-digit condition
CONDITION_8_DIGITS = 41; % Trigger for 8-digit condition

RESPONSE_SUBMITTED = 50; % Trigger when response is submitted

PRACTICE_END = 75; % End of practice block
TASK_END = 90; % Trigger for ET cutting

%% Set up experiment parameters
% Block and Trial Number
exp.nTrlPractice = 5; % n practice trials
exp.nTrlMain = 100; % n main task trials

if TRAINING == 1
    exp.nTrials = exp.nTrlPractice;
else
    exp.nTrials = exp.nTrlMain;
end

% Enable (= 1) or disable (= 0) screenshots
enableScreenshots = 1;

%% Set up text parameters
% Define startExperimentText
if TRAINING == 1
    startExperimentText = [
        'PRACTICE TRIALS \n\n' ...
        'You will see digits moving around the screen. \n\n' ...
        'Your task is to add together ALL the numbers \n\n' ...
        'you see and enter the sum. \n\n' ...
        '\n\n' ...
        'Press any key to continue...'];
    loadingText = 'Loading PRACTICE...';
else
    startExperimentText = [
        'You will see digits moving around the screen. \n\n' ...
        'Your task is to add together ALL the numbers \n\n' ...
        'you see and enter the sum. \n\n' ...
        'Sometimes there will be 4 digits, sometimes 8. \n\n' ...
        'Focus on the center of the screen. \n\n' ...
        '\n\n' ...
        'Press any key to continue...'];
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
numKeys = [KbName('0'), KbName('1'), KbName('2'), KbName('3'), KbName('4'), ...
           KbName('5'), KbName('6'), KbName('7'), KbName('8'), KbName('9')];

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
Screen('TextSize', ptbWindow, 25); % Font size for instructions and stimuli
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
timing.stimulusDuration = 3.0; % Stimulus presentation duration (seconds)
timing.inputDuration = 3.0; % Input period duration (seconds)

%% Digit parameters
digitSize_dva = 1.0; % Size of digits in degrees of visual angle
digitSize_pix = round(digitSize_dva * screen.ppd);
digitColor = [50 50 50]; % Slightly darker than background (gray background is 192)

% Movement parameters
digitSpeed = 2; % cm/s (will be converted to pixels)
digitSpeed_pix = digitSpeed * (screen.resolutionX / screen.width); % Convert to pixels per second

% Movement boundaries (leave some margin from edges)
margin = 50; % pixels
moveBounds = [margin, margin, screen.resolutionX - margin, screen.resolutionY - margin];

%% Cross parameters (for unexpected cross)
crossSize_dva = 1.0; % Size of cross in degrees of visual angle
crossSize_pix = round(crossSize_dva * screen.ppd);
crossColor = [120 120 120]; % Grayish color (slightly darker than background)

% Cross movement path (enters from right, exits left, moves horizontally)
crossStartX = screen.resolutionX + crossSize_pix;
crossEndX = -crossSize_pix;
crossY = screen.centerY; % Moves through center

% Cross horizontal/vertical extent
crossExtent = crossSize_pix / 2;
crossCoords = [-crossExtent crossExtent 0 0; 0 0 -crossExtent crossExtent];

% Cross movement speed (time-based)
crossTravelDistance = crossStartX - crossEndX; % Total distance to travel
crossTravelDuration = 1.5; % Seconds to cross screen
crossSpeed_pixPerSec = crossTravelDistance / crossTravelDuration;

% Use realtime priority for better timing precision
priorityLevel = MaxPriority(ptbWindow);
Priority(priorityLevel);

%% Create data structure for preallocating data
data = struct;
data.nDigits(1, exp.nTrials) = NaN; % Number of digits in trial (4 or 8)
data.digits(1, exp.nTrials) = {[]}; % Cell array to store which digits appeared
data.crossPresent(1, exp.nTrials) = NaN; % Binary: was cross present?
data.correctSum(1, exp.nTrials) = NaN; % Correct sum of digits
data.participantSum(1, exp.nTrials) = NaN; % What participant entered
data.binaryAccuracy(1, exp.nTrials) = NaN; % Correct (1) or incorrect (0)
data.continuousAccuracy(1, exp.nTrials) = NaN; % Percentage deviation from correct sum
data.reactionTime(1, exp.nTrials) = NaN; % Time from stimulus end to response submission
data.inputTime(1, exp.nTrials) = NaN; % Time spent in input period
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

% Determine condition (4 or 8 digits) for each trial
if TRAINING == 1
    % Mix of conditions in practice
    conditionSequence = [4 8 4 8 4]; % Alternating for practice
else
    % Randomly assign 4 or 8 digits to each trial
    conditionSequence = randi([4 8], 1, exp.nTrials);
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

% Send triggers for start of task (ET cutting)
if TRAINING == 1
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "START"');
    Eyelink('Message', num2str(PRACTICE_START));
    Eyelink('command', 'record_status_message "START PRACTICE"');
else
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "START"');
    sendtrigger(TASK_START,port,SITE,stayup);
    Eyelink('Message', num2str(MAIN_TASK_START));
    Eyelink('command', 'record_status_message "START MAIN TASK"');
    sendtrigger(MAIN_TASK_START,port,SITE,stayup);
end

% Experiment prep
HideCursor(whichScreen); % Make sure to hide cursor from participant screen
timing.startTime = datestr(now, 'dd/mm/yy-HH:MM:SS'); % Measure duration

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
    data.nDigits(trl) = conditionSequence(trl);
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
    
    % Send fixation trigger
    TRIGGER = FIXCROSS;
    if TRAINING == 1
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "FIXCROSS"');
    else
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "FIXCROSS"');
        sendtrigger(TRIGGER,port,SITE,stayup);
    end
    
    WaitSecs(timing.fixDuration(trl));
    
    %% Initialize digit positions and movements
    nDigits = data.nDigits(trl);
    digits = randi([0 9], 1, nDigits); % Random digits 0-9
    data.digits{trl} = digits;
    data.correctSum(trl) = sum(digits);
    
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
    
    % Store last frame time for time-based movement
    lastFrameTime = stimulusStartTime;
    
    % Initialize cross position and movement
    crossX = crossStartX;
    crossVisible = false;
    crossStartTime = NaN;
    
    % Send trial start trigger
    TRIGGER = TRIAL_START;
    if TRAINING == 1
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "TRIAL_START"');
    else
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "TRIAL_START"');
        sendtrigger(TRIGGER,port,SITE,stayup);
    end
    
    % Send condition trigger
    if nDigits == 4
        TRIGGER = CONDITION_4_DIGITS;
    else
        TRIGGER = CONDITION_8_DIGITS;
    end
    if TRAINING == 1
        Eyelink('Message', num2str(TRIGGER));
    else
        Eyelink('Message', num2str(TRIGGER));
        sendtrigger(TRIGGER,port,SITE,stayup);
    end
    
    % Send stimulus start trigger
    TRIGGER = STIMULUS_START;
    stimulusStartTime = GetSecs;
    if TRAINING == 1
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "STIMULUS_START"');
    else
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "STIMULUS_START"');
        sendtrigger(TRIGGER,port,SITE,stayup);
    end
    
    %% Stimulus presentation loop (3000ms)
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
            
            % Draw digit
            digitText = num2str(digits(d));
            Screen('TextSize', ptbWindow, digitSize_pix);
            [textBounds] = Screen('TextBounds', ptbWindow, digitText);
            textWidth = textBounds(3) - textBounds(1);
            textHeight = textBounds(4) - textBounds(2);
            Screen('DrawText', ptbWindow, digitText, ...
                   digitPos(d, 1) - textWidth/2, digitPos(d, 2) - textHeight/2, ...
                   digitColor);
        end
        
        % Update and draw cross if present
        if data.crossPresent(trl) == 1
            elapsedTime = GetSecs - stimulusStartTime;
            % Cross appears 0.5 seconds into stimulus presentation and moves for 1.5 seconds
            if elapsedTime >= 0.5 && elapsedTime < 2.0
                if ~crossVisible
                    crossVisible = true;
                    crossStartTime = elapsedTime;
                    % Send cross appear trigger
                    TRIGGER = CROSS_APPEAR;
                    if TRAINING == 1
                        Eyelink('Message', num2str(TRIGGER));
                    else
                        Eyelink('Message', num2str(TRIGGER));
                        sendtrigger(TRIGGER,port,SITE,stayup);
                    end
                end
                
                % Update cross position (moves from right to left)
                % Cross should traverse screen width in crossTravelDuration seconds
                crossTravelTime = elapsedTime - 0.5; % Time since cross appeared
                crossX = crossStartX - crossTravelTime * crossSpeed_pixPerSec;
                
                % Draw cross
                Screen('DrawLines', ptbWindow, crossCoords, fixationLineWidth, ...
                       crossColor, [crossX crossY], 2);
            elseif elapsedTime >= 2.0 && crossVisible
                crossVisible = false;
                % Send cross disappear trigger
                TRIGGER = CROSS_DISAPPEAR;
                if TRAINING == 1
                    Eyelink('Message', num2str(TRIGGER));
                else
                    Eyelink('Message', num2str(TRIGGER));
                    sendtrigger(TRIGGER,port,SITE,stayup);
                end
            end
        end
        
        Screen('Flip', ptbWindow);
        frameCount = frameCount + 1;
    end
    
    %% Input period (3000ms)
    inputStartTime = GetSecs;
    
    % Send input start trigger
    TRIGGER = INPUT_START;
    if TRAINING == 1
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "INPUT_START"');
    else
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "INPUT_START"');
        sendtrigger(TRIGGER,port,SITE,stayup);
    end
    
    % Input loop
    inputString = '';
    responseSubmitted = false;
    lastKeyTime = 0;
    keyDebounceTime = 0.15; % Time to wait between key presses
    
    while (GetSecs - inputStartTime) < timing.inputDuration && ~responseSubmitted
        % Clear screen
        Screen('FillRect', ptbWindow, backgroundColorGray);
        
        % Display input prompt and current input
        promptText = 'Enter the sum:';
        inputDisplayText = [promptText ' ' inputString];
        
        Screen('TextSize', ptbWindow, 30);
        [textBounds] = Screen('TextBounds', ptbWindow, inputDisplayText);
        textWidth = textBounds(3) - textBounds(1);
        Screen('DrawText', ptbWindow, inputDisplayText, ...
               screen.centerX - textWidth/2, screen.centerY, black);
        
        Screen('Flip', ptbWindow);
        
        % Check for keyboard input (only if enough time has passed since last key)
        currentTime = GetSecs;
        if (currentTime - lastKeyTime) >= keyDebounceTime
            [keyIsDown, secs, keyCode] = KbCheck(-1);
            if keyIsDown
                keyPressed = false;
                
                % Check for number keys
                for i = 0:9
                    if keyCode(numKeys(i+1))
                        inputString = [inputString num2str(i)];
                        lastKeyTime = currentTime;
                        keyPressed = true;
                        break;
                    end
                end
                
                % Check for backspace
                if ~keyPressed && keyCode(backspaceKeyCode)
                    if length(inputString) > 0
                        inputString = inputString(1:end-1);
                    end
                    lastKeyTime = currentTime;
                    keyPressed = true;
                end
                
                % Check for enter
                if ~keyPressed && keyCode(enterKeyCode) && length(inputString) > 0
                    responseSubmitted = true;
                    responseTime = GetSecs - inputStartTime;
                    data.participantSum(trl) = str2double(inputString);
                    data.inputTime(trl) = GetSecs - inputStartTime;
                    
                    % Send response submitted trigger
                    TRIGGER = RESPONSE_SUBMITTED;
                    if TRAINING == 1
                        Eyelink('Message', num2str(TRIGGER));
                    else
                        Eyelink('Message', num2str(TRIGGER));
                        sendtrigger(TRIGGER,port,SITE,stayup);
                    end
                    break;
                end
            end
        end
        
        WaitSecs(0.01); % Small delay to prevent excessive CPU usage
    end
    
    % If no response submitted, use empty or last entered value
    if ~responseSubmitted
        if length(inputString) > 0
            data.participantSum(trl) = str2double(inputString);
        else
            data.participantSum(trl) = NaN;
        end
        data.inputTime(trl) = timing.inputDuration;
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
    
    %% Trial Info CW output
    overall_accuracy = round((nansum(data.binaryAccuracy(1:trl))/trl)*100);
    crossInfo = '';
    if data.crossPresent(trl) == 1
        crossInfo = ' | Cross: YES';
    else
        crossInfo = ' | Cross: NO';
    end
    
    disp(['Trial ' num2str(trl) '/' num2str(exp.nTrials) ...
          ' | N Digits: ' num2str(nDigits) ...
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

% Send triggers for block end
if TRAINING == 1
    TRIGGER = PRACTICE_END;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END PRACTICE"');
    disp('End of Practice Block.');
else
    TRIGGER = TASK_END;
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END TASK"');
    sendtrigger(TRIGGER,port,SITE,stayup);
    disp('End of Main Task');
end

% Send triggers for end of task (ET cutting)
if TRAINING == 1
    Eyelink('Message', num2str(TASK_END));
    Eyelink('command', 'record_status_message "TASK_END"');
else
    Eyelink('Message', num2str(TASK_END));
    Eyelink('command', 'record_status_message "TASK_END"');
    sendtrigger(TASK_END,port,SITE,stayup);
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
saves.subject = subject;
saves.timing = timing;

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
trigger.CONDITION_4_DIGITS = CONDITION_4_DIGITS;
trigger.CONDITION_8_DIGITS = CONDITION_8_DIGITS;
trigger.RESPONSE_SUBMITTED = RESPONSE_SUBMITTED;
trigger.PRACTICE_END = PRACTICE_END;
trigger.TASK_END = TASK_END;

%% Stop and close EEG and ET recordings
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
