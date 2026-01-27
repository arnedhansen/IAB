# IAB - Inattentional Blindness Task

An inattentional blindness paradigm implemented in MATLAB using PsychToolbox. This task investigates whether participants notice an unexpected stimulus (a moving cross) while engaged in an attentionally demanding primary task (summing moving digits).

## Task Overview

Participants are presented with digits (0-9) moving randomly around the screen. Their task is to add together **all** the digits they see and enter the sum. On some trials, an unexpected gray cross moves across the screen. The task measures whether participants notice this unexpected stimulus while focusing on the primary counting task.

## Task Structure

### Practice Block
- **5 practice trials**
- No unexpected cross appears
- Participants familiarize themselves with the task
- Mix of 4-digit and 8-digit conditions

### Main Task
- **100 trials**
- Two conditions:
  - **4 digits** per trial
  - **8 digits** per trial
- **Cross appears in ~33 trials** (1/3 of trials)
  - Cross does **NOT** appear in:
    - Practice trials
    - First 2 real trials
  - Cross appears randomly in remaining trials

## Trial Structure

Each trial consists of three phases:

1. **Fixation Period** (500-1500ms, jittered)
   - White fixation cross appears in the center of the screen
   - Participants prepare for the trial

2. **Stimulus Presentation** (3000ms)
   - Digits appear and move randomly around the screen
   - Digits bounce off screen edges
   - On cross trials: A grayish cross enters from the right side, moves horizontally across the center, and exits the left side
     - Cross appears 0.5s into stimulus presentation
     - Cross is visible for 1.5s

3. **Input Period** (3000ms)
   - Blank gray screen
   - Participants enter the sum of all digits they saw
   - Input is displayed on screen
   - Backspace to correct, Enter to submit
   - If no response within 3s, the last entered value (if any) is recorded

## Visual Design

- **Background**: Gray (RGB: 192)
- **Digits**: Dark gray (RGB: 50) - slightly darker than background
- **Fixation cross**: White (RGB: 255)
- **Unexpected cross**: Grayish (RGB: 120) - moves horizontally across screen

## Data Collected

For each trial, the following metrics are saved:

- `nDigits`: Number of digits in trial (4 or 8)
- `digits`: Cell array containing which digits appeared (0-9)
- `crossPresent`: Binary indicator (1 = cross present, 0 = absent)
- `correctSum`: The correct sum of all digits
- `participantSum`: What the participant entered
- `binaryAccuracy`: Correct (1) or incorrect (0)
- `continuousAccuracy`: Percentage deviation from correct sum
- `reactionTime`: Time from stimulus end to response submission
- `inputTime`: Time spent in input period
- `trialDuration`: Total trial duration

## Requirements

- **MATLAB** (tested with R2023b)
- **PsychToolbox** (version 3.0.15 or compatible)
- **EEG System**: ANT Neuro (for trigger sending)
- **Eye Tracker**: Tobii Pro Fusion (optional, for eye tracking)
- **ppdev-mex-master**: For parallel port communication (EEG triggers)

## Setup

1. Update paths in `master.m`:
   - `PPDEV_PATH`: Path to ppdev-mex-master
   - `DATA_PATH`: Where to save data files
   - `FUNS_PATH`: Path to this IAB folder

2. Ensure screen settings are configured in `screenSettings.m`:
   - Screen resolution: 800x600
   - Refresh rate: 100 Hz (Linux)

3. Run the experiment:
   ```matlab
   master
   ```

## File Structure

- `master.m` - Main script that runs practice and main task
- `IAB_task.m` - Core paradigm implementation
- `screenSettings.m` - Screen configuration
- `sendtrigger.m` - EEG trigger sending functions
- `initEEG.m` - EEG initialization
- `calibrateET.m` - Eye tracker calibration
- `dialogID.m` - Subject ID collection dialog
- `closeEEGandET.m` - Cleanup routines
- `EL_*.m` - Eye tracker helper functions
- `screenshot.m` - Screenshot utility

## Data Output

Data is saved in `.mat` files:
- Practice: `[SubjectID]_practice.mat`
- Main task: `[SubjectID]_IAB.mat`

Each file contains:
- `saves`: Structure with all trial data, experiment parameters, screen settings, timing information
- `trigger`: Structure with all trigger codes for EEG/ET synchronization

## Based On

This paradigm is adapted from:
- Most, S. B., Simons, D. J., Scholl, B. J., & Chabris, C. F. (2000). Sustained Inattentional Blindness: The Role of Location in the Detection of Unexpected Dynamic Events. *PSYCHE*, 6(14).

## Notes

- The task uses time-based movement calculations for smooth digit and cross motion regardless of frame rate
- All events are synchronized with EEG/ET via triggers
- The cross is designed to be subtle (grayish) to maximize inattentional blindness effects
- Participants are not warned about the cross before the experiment
