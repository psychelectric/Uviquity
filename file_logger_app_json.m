function file_logger_app_text
    % Main GUI Window
    fig = uifigure('Name', 'Scrollable File Monitoring Application', 'Position', [100 100 650 650]);
    
    % Scrollable Panel for All Components
    scrollPanel = uipanel(fig, 'Position', [20 20 560 620], 'Scrollable', 'on');
    
    % Directory Path Label and Edit Field
    uilabel(scrollPanel, 'Position', [20 940 120 30], 'Text', 'Directory Path:');
    dirPathField = uieditfield(scrollPanel, 'text', 'Position', [150 940 300 30]);
    
    % Number of Input Fields to Create
    numFields = 22;
    
    % Define unique names for each of the 23 variables
    uniqueLabels = {'Scans_to_Average', 'Integration_Time', 'Fixed_Pattern_Noise_Subtraction_Enabled', 'Fixed_Pattern_Noise_Subtraction_Reference', 'Gain', 'Frame_Rate', 'Sample_ID', 'Sample_Date', 'Device_ID', 'Chip_Identifier', 'Experiment_ID', 'Experiment_Name', 'Experiment_Date', 'Operator_Name', 'Folder_Location', 'Spectrum_File_Name', 'Image_File_Name', 'Average_Power_Reference', 'Wavelength', 'Output_Filters', 'Input_ND_Filters', 'Light_Source'};
    
    % Define default values for each variable
    defaultValues = {1, 100000, 'False', 'N/A', 1, 10, 'UvqA-sd7', datestr(now, 'dd-mm-yyyy'), 'Lwgnh310id1.1', 'UvqA-sd7', '001', 'DefaultExperiment', datestr(now, 'dd.mm.yyyy; HH.MM.SS'), 'UVLab2', 'C:\experID\', 'N/A', 'N/A', 1000, 450, 'ET214/BP10', 'None', 'TS1'};
    
    % Define input types for each variable
    inputTypes = {'numeric', 'numeric', 'text', 'text', 'numeric', ...
                  'numeric', 'text', 'text', 'text', 'text', ...
                  'text', 'text', 'text', 'text', 'text', ...
                  'text', 'text', 'numeric', 'numeric', 'text', 'text', 'text'};
    
    % Create Labels and Input Fields in the Scrollable Panel
    inputFields = gobjects(numFields, 1); % Preallocate for input fields
    labels = gobjects(numFields, 1); % Preallocate for labels
    
    for i = 1:numFields
        % Define position for each label and field
        labelYPos = 900 - (i-1) * 30; % Adjust spacing between labels
        fieldYPos = labelYPos;
        
        % Create label for each input field with a unique name from the list
        labels(i) = uilabel(scrollPanel, ...
            'Position', [20 labelYPos 200 30], ...
            'Text', uniqueLabels{i});
        
        % Create an input field for each label based on its type and set the default value
        if strcmp(inputTypes{i}, 'numeric')
            inputFields(i) = uieditfield(scrollPanel, 'numeric', ...
                'Position', [250 fieldYPos 100 30], 'Value', defaultValues{i});
        else
            inputFields(i) = uieditfield(scrollPanel, 'text', ...
                'Position', [250 fieldYPos 200 30], 'Value', defaultValues{i});
        end
    end
    
    % Start and Stop Buttons
    startButton = uibutton(scrollPanel, 'push', 'Text', 'Start Monitoring', 'Position', [500 880 120 30], 'ButtonPushedFcn', @(src, event) startMonitoring(inputFields, dirPathField));
    stopButton = uibutton(scrollPanel, 'push', 'Text', 'Stop Monitoring', 'Position', [630 880 120 30], 'ButtonPushedFcn', @(src, event) stopMonitoring(), 'Enable', 'off');
    
    % Log Text Area to display messages
    logArea = uitextarea(scrollPanel, 'Position', [500 750 240 100], 'Editable', 'off');
    
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
        metadataFilePath = fullfile(directoryPath, 'file_logger_metadata.json');
        
        % Create or update the metadata file if it doesn't exist
        if ~isfile(metadataFilePath)
            fid = fopen(metadataFilePath, 'w');
            if fid == -1
                appendLog('Error: Unable to create metadata file.');
                return;
            end
            % Write an empty JSON array to initialize the file
            fprintf(fid, '%s', jsonencode([]));
            fclose(fid);
        end
        
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
    function onNewFileDetected(eventArgs, values)
        newFilePath = char(eventArgs.FullPath);
       
        % Avoid triggering on temporary files or double firing events
        if contains(newFilePath, '~$') || contains(newFilePath, '.tmp') || strcmp(newFilePath, metadataFilePath)
            return; % Skip temporary files or if it's the metadata file itself
        end

        % Check if the same file was processed in the last call
        if strcmp(newFilePath, lastFileProcessed)
            return; % Skip if it's the same file being processed again
        end
        
        % Update the last processed file
        lastFileProcessed = newFilePath;
        
        appendLog(['New file detected: ', newFilePath]);

        % Read existing JSON data
        fid = fopen(metadataFilePath, 'r');
        if fid == -1
            appendLog('Error: Unable to read metadata file.');
            return;
        end
        fileContent = fread(fid, '*char')';
        fclose(fid);
        if isempty(strtrim(fileContent))
            existingData = [];
        else
            existingData = jsondecode(fileContent);
        end
        % Create a new metadata entry
        newEntry = struct();
        for k = 1:numFields
            newEntry.(uniqueLabels{k}) = values{k};
        end
        
        % Append the new entry to the existing data
        updatedData = [existingData; newEntry];
        
        % Write the updated JSON data back to the file
        fid = fopen(metadataFilePath, 'w');
        if fid == -1
            appendLog('Error: Unable to update metadata file.');
            return;
        end
        fprintf(fid, '%s', jsonencode(updatedData)); % Write updated JSON data
        fclose(fid);
        
        appendLog(['Metadata updated for file: ', newFilePath]);
    end

    % Helper function to append messages to the log area
    function appendLog(message)
        currentText = logArea.Value;
        logArea.Value = [currentText; {message}];
    end
end