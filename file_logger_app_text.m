%Make header at top , then values for the rest 
% Have logfile (this code) then process the data (read all fo the fils)
%Get list of all files
% Add default values to GUI 
% how can you get code to run independently (research, executable on machine)
%Code sharing (GitHub)
%Start and Stop monitoring ()


function file_logger_app_text
    % Main GUI Window
    fig = uifigure('Name', 'Scrollable File Monitoring Application', 'Position', [100 100 650 650]);
    
    % Scrollable Panel for All Components
    scrollPanel = uipanel(fig, 'Position', [20 20 560 620], 'Scrollable', 'on');
    
    % Directory Path Label and Edit Field
    uilabel(scrollPanel, 'Position', [20 940 120 30], 'Text', 'Directory Path:');
    dirPathField = uieditfield(scrollPanel, 'text', 'Position', [150 940 300 30]);
    
    % Number of Input Fields to Create
    numFields = 26;
    
    % Define unique names for each of the 26 variables
    uniqueLabels = {'Scans to Avg', 'Integration Time', 'Fixed Pattern Noise Subtraction Enabled', 'Fixed Pattern Noise Subtraction Reference', 'Integration Time', ...
                    'Gain', 'Frame Rate', 'Pixel X', 'Pixel Y', 'Intensity', ...
                    'Sample ID', 'Sample Date', 'Device ID', 'Chip Identifier' 'Experiment ID', ...
                    'Experiment Name', 'Experiment Date', 'Operator Name', 'Folder Location', 'Spectrum File Name', ...
                    'Image File Name', 'Average Power (Reference)', 'Wavelength', 'Output Filters', ...
                    'Input Reference Power', 'Light Source'};
    
    % Define input types for each variable
    inputTypes = {'numeric', 'numeric', 'text', 'text', 'numeric', ...
                  'numeric', 'numeric', 'numeric', 'numeric', 'text', ...
                  'text', 'text', 'text', 'text', 'text', ...
                  'text', 'text', 'text', 'text', 'text', ...
                  'text', 'numeric', 'numeric', 'text', ...
                  'numeric', 'text'};
    
    % Create Labels and Input Fields in the Scrollable Panel
    inputFields = gobjects(numFields, 1); % Preallocate for input fields
    labels = gobjects(numFields, 1); % Preallocate for labels
    
    for i = 1:numFields
        % Define position for each label and field
        labelYPos = 900 - (i-1) * 30; % Adjust spacing between labels
        fieldYPos = labelYPos;
        
        % Create label for each input field with a unique name from the list
        labels(i) = uilabel(scrollPanel, ...
            'Position', [20 labelYPos 120 30], ...
            'Text', uniqueLabels{i});
        
        % Create an input field for each label based on its type
        if strcmp(inputTypes{i}, 'numeric')
            inputFields(i) = uieditfield(scrollPanel, 'numeric', ...
                'Position', [150 fieldYPos 100 30]);
        else
            inputFields(i) = uieditfield(scrollPanel, 'text', ...
                'Position', [150 fieldYPos 100 30]);
        end
    end
    
    % Start and Stop Buttons
    startButton = uibutton(scrollPanel, 'push', 'Text', 'Start Monitoring', ...
        'Position', [280 880 120 30], 'ButtonPushedFcn', @(src, event) startMonitoring(inputFields, dirPathField));
    stopButton = uibutton(scrollPanel, 'push', 'Text', 'Stop Monitoring', ...
        'Position', [410 880 120 30], 'ButtonPushedFcn', @(src, event) stopMonitoring(), ...
        'Enable', 'off');
    
    % Log Text Area to display messages
    logArea = uitextarea(scrollPanel, 'Position', [280 750 240 100], 'Editable', 'off');
    
    % Variables for File Watcher and Metadata File Path
    watcher = [];
    metadataFilePath = '';  % Path to the metadata file
    lastFileProcessed = ''; % Track last processed file to avoid duplicate logging
    
    % Callback Function for Start Button
    function startMonitoring(fields, dirField)
        % Get the directory path from user input
        directoryPath = dirField.Value;
        if isempty(directoryPath) || ~isfolder(directoryPath)
            uialert(fig, 'Please enter a valid directory path.', 'Invalid Path');
            return;
        end
        
        % Read values from all input fields
        inputValues = cell(numFields, 1);
        for k = 1:numFields
            value = fields(k).Value;
            if isempty(value)
                value = 'N/A'; % Assign default value if empty
            end
            inputValues{k} = value;
        end
        
        % Set the metadata file path to be in the monitored directory
        metadataFilePath = fullfile(directoryPath, 'file_logger_metadata.txt');
        
        % Create FileSystemWatcher
        if ~isempty(watcher)
            % Disable and delete any existing watcher to prevent multiple instances
            watcher.EnableRaisingEvents = false;
            delete(watcher);
        end
        
        watcher = System.IO.FileSystemWatcher(directoryPath);
        watcher.Filter = '*.*';  % Monitor all files
        watcher.IncludeSubdirectories = false;
        watcher.EnableRaisingEvents = true;
        
        % Add event listeners for Created event
        addlistener(watcher, 'Created', @(src, event) onNewFileDetected(event, inputValues));
        
        % Update GUI elements
        startButton.Enable = 'off';
        stopButton.Enable = 'on';
        appendLog(['Monitoring started on: ', directoryPath]);
    end

    % Callback Function for Stop Button
    function stopMonitoring()
        if ~isempty(watcher)
            watcher.EnableRaisingEvents = false;
            delete(watcher);  % Delete watcher object to release resources
            watcher = [];
            appendLog('Monitoring stopped.');
        end
        
        % Update GUI elements
        startButton.Enable = 'on';
        stopButton.Enable = 'off';
    end

    % Callback Function for File Creation Event
    % Create Json file, follows appropriate rules (create function to write
    % in Json format for file reader) or XML 

    function onNewFileDetected(eventArgs, values)
        newFilePath = char(eventArgs.FullPath);
       
        % Avoid triggering on temporary files or double firing events
        if contains(newFilePath, '~$') || contains(newFilePath, '.tmp')
            return; % Skip temporary files that may trigger the event
        end

        % Check if the same file was processed in the last call
        if strcmp(newFilePath, lastFileProcessed)
            return; % Skip if it's the same file being processed again
        end
        
        % Update the last processed file
        lastFileProcessed = newFilePath;
        
        appendLog(['New file detected: ', newFilePath]);

        % Create metadata line using the predefined labels
        metadataContent = 'MetaData: ';
        for k = 1:numFields
            label = uniqueLabels{k};
            value = values{k};
            if isnumeric(value)
                metadataContent = strcat(metadataContent, sprintf('%s: %.2f', label, value), ', ');
            else
                metadataContent = strcat(metadataContent, sprintf('%s: %s', label, value), ', ');
            end
        end
        
        metadataContent = strcat(metadataContent(1:end-1), '\n'); % Remove trailing comma and space

        % Append metadata to the metadata file in the monitored directory
        fid = fopen(metadataFilePath, 'a');
        if fid == -1
            appendLog('Error: Unable to update metadata file.');
            return;
        end
        fprintf(fid, '%s\n', metadataContent); % Append each metadata line on a new line
        fclose(fid);
        
        appendLog(['Metadata updated for file: ', newFilePath]);
    end

    % Helper function to append messages to the log area
    function appendLog(message)
        currentText = logArea.Value;
        logArea.Value = [currentText; {message}];
    end
end