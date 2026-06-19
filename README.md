# IAB - Inattentional Blindness Task

An inattentional blindness paradigm implemented in MATLAB using PsychToolbox. This task investigates whether participants notice an unexpected stimulus (a gray cross) while engaged in an attentionally demanding primary task (summing black digits while ignoring white digits).

## Task Overview

Participants are presented with **12 digits** (1-20) moving randomly around the screen. Digits are either **black** or **white**. Their task is to add together **only the BLACK digits** and ignore the white ones. On some trials, an unexpected gray cross appears offset to the side of the screen. The task measures whether participants notice this unexpected stimulus while focusing on the primary counting task.

## Experimental Groups

The experiment uses a **two-group design** to investigate the role of attention allocation:

- **Group A (Focused Attention)**: 
  - Instruction: "Your task is to add together the BLACK numbers. Ignore the white numbers."
  - Subject IDs: 201, 203, 205, 207, 209, 211, 213, 215, 217, 219 (odd IDs)
  - 10 participants

- **Group B (Expanded Attention)**:
  - Instruction: "Your task is to calculate the sum of the BLACK numbers by adding them together. Ignore the white numbers. Additionally, visual changes may occur during the task. Please pay attention to everything that appears on the screen."
  - Subject IDs: 202, 204, 206, 208, 210, 212, 214, 216, 218, 220 (even IDs)
  - 10 participants

**Group assignment is deterministic** based on subject ID (odd = Group A, even = Group B).

## Task Structure

### Practice Block
- **3 practice trials**
- No unexpected cross appears
- Participants familiarize themselves with the task
- Always 12 digits per trial (6 black, 6 white)

### Main Task
- **100 trials**
- Always **12 digits** per trial
- **6 black digits** per trial (always)
- **6 white digits** per trial (always)
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

2. **Stimulus Presentation** (7000ms)
   - 12 digits appear and move randomly around the screen
   - Digits bounce off screen edges
   - Digits are either black (to be summed) or white (to be ignored)
   - On cross trials: A grayish cross appears offset to the side
     - Cross appears **5 seconds** into stimulus presentation
     - Cross is visible for **1.0-1.5 seconds** (randomized duration)
     - Cross position is randomly offset to left or right side (2-4 degrees from center)
     - Cross does not move (static position)

3. **Input Period** (3000ms)
   - Blank gray screen
   - Participants enter the sum of **black digits only**
   - Input is displayed on screen
   - Backspace to correct, Enter to submit
   - If no response within 3s, the last entered value (if any) is recorded

## Post-Trial Questions

After completing all 100 trials, participants answer **4 perception questions**:

1. "Ist Ihnen etwas Ungewöhnliches aufgefallen (während des Zusammenzählens der Ziffern)?"
2. "Haben Sie abgesehen von den Zahlen sonst noch etwas gesehen?"
3. "Haben Sie ein Objekt bemerkt, das nichts mit Zahlen zu tun hatte?"
4. "Haben Sie ein Kreuz gesehen?"

Responses are recorded as YES (1) or NO (0) and saved in the data file.

## Visual Design

- **Background**: Gray (RGB: 192)
- **Black digits**: Black (RGB: 0, 0, 0) - to be summed
- **White digits**: White (RGB: 255, 255, 255) - to be ignored
- **Fixation cross**: White (RGB: 255)
- **Unexpected cross**: Grayish (RGB: 120, 120, 120) - offset to side, static position

## Data Collected

For each trial, the following metrics are saved:

- `nDigits`: Number of digits in trial (always 8)
- `digits`: Cell array containing which digits appeared (1-20)
- `digitColors`: Cell array indicating color of each digit (1=black, 0=white)
- `crossPresent`: Binary indicator (1 = cross present, 0 = absent)
- `crossPosition`: Cross position [x, y] if present, [NaN, NaN] if absent
- `correctSum`: The correct sum of **black digits only**
- `participantSum`: What the participant entered
- `continuousAccuracy`: 100% = perfect, 0% = maximally wrong
- `reactionTime`: Time from stimulus end to response submission
- `inputTime`: Time spent in input period
- `trialDuration`: Total trial duration

**Subject information**:
- `subject.group`: Group assignment ('A' or 'B')
- `subject.groupName`: Group name ('Focused Attention' or 'Expanded Attention')
- `subject.ID`: Subject ID (201-220)

**Perception data** (after main task):
- `perceptionData.Q1-Q4`: Responses to perception questions (1=yes, 0=no)

## File Structure

- `master.m` - Main script that runs practice and main task, assigns groups
- `IAB_task.m` - Core paradigm implementation
- `screenSettings.m` - Screen configuration
- `sendtrigger.m` - EEG trigger sending functions
- `initEEG.m` - EEG initialization
- `calibrateET.m` - Eye tracker calibration
- `dialogID.m` - Subject ID collection dialog
- `closeEEGandET.m` - Cleanup routines
- `EL_*.m` - Eye tracker helper functions

## Data Output

Data is saved in `.mat` files:
- Practice: `[SubjectID]_practice.mat`
- Main task: `[SubjectID]_IAB.mat`

Each file contains:
- `saves`: Structure with all trial data, experiment parameters, screen settings, timing information, group assignment, and perception responses
- `trigger`: Structure with all trigger codes for EEG/ET synchronization
