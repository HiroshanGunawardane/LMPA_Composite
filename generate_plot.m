% MATLAB Script for Processing and Plotting DMA Data

clear;
clc;
close all;

%% --- Configuration ---
baseDir = 'D:\Guien MEMS Lab Final\new_method'; % Adjust if script is run from elsewhere
outputDir = fullfile(baseDir, 'output');
testTypes = {'ss0', 'ss80', 'ts'}; % Test types to process
materials = {'cerr_117', 'cerr_158', 'ecoflex_50'};
concentrations = {'10v', '20v', '30v', '40v', '50v'}; % For 'cerr' types

% Define Colormaps
nConcentrations = length(concentrations);
colorMaps = containers.Map;
colorMaps('cerr_117') = cool(nConcentrations + 2); % Get a few extra colors for spacing
colorMaps('cerr_158') = autumn(nConcentrations + 2);
colorMaps('ecoflex_50') = [0 0 0]; % Black

% Map concentrations to color indices (adjust if needed)
concColorIdx = containers.Map(concentrations, 1:nConcentrations);

% Columns to extract (Based on SigN descriptions)
colMap = containers.Map;
colMap('Temperature') = 2;
colMap('Storage Modulus') = 3;
colMap('Stress') = 5;
colMap('Strain') = 10;

% Create output directory if it doesn't exist
if ~isfolder(outputDir)
    mkdir(outputDir);
    fprintf('Created output directory: %s\n', outputDir);
end

%% --- Data Loading and Parsing ---
allData = struct('Material', {}, 'Concentration', {}, 'TestType', {}, ...
                 'Sample', {}, 'FilePath', {}, 'HeaderInfo', {}, ...
                 'Time', {}, 'Temperature', {}, 'StorageModulus', {}, ...
                 'LossModulus', {}, 'Stress', {}, 'TanDelta', {}, ...
                 'Frequency', {}, 'DriveForce', {}, 'Amplitude', {}, ...
                 'Strain', {}, 'Displacement', {}, 'StaticForce', {}, ...
                 'Position', {}, 'Length', {}, 'Force', {}, ...
                 'Stiffness', {}, 'GCAPressure', {});

fileCounter = 0;

disp('Starting data loading and parsing...');

for iTest = 1:length(testTypes)
    currentTest = testTypes{iTest};
    exportDir = fullfile(baseDir, currentTest, 'export');

    if ~isfolder(exportDir)
        warning('Directory not found: %s. Skipping.', exportDir);
        continue;
    end

    fprintf('Processing directory: %s\n', exportDir);
    dataFiles = dir(fullfile(exportDir, '*.txt'));

    for iFile = 1:length(dataFiles)
        fileName = dataFiles(iFile).name;
        filePath = fullfile(exportDir, fileName);

       % --- Parse Filename ---
        material = '';
        concentration = '';
        sample = '';
        testFromFile = ''; % Extract test type from filename for verification/completeness

        % CORRECTED Regex for cerr: No outer group on material part
        pattern_cerr = '^cerr_(117|158)_(\d+v)_(ss0|ss80|ts)_s(\d+\.\d+)\.txt$';
        % Group 1: (117|158) - Material number
        % Group 2: (\d+v)     - Concentration
        % Group 3: (ss0|ss80|ts) - Test type
        % Group 4: (\d+\.\d+)   - Sample number part
        tokens_cerr = regexp(fileName, pattern_cerr, 'tokens');

        % Regex for ecoflex (remains the same)
        pattern_eco = '^(ecoflex_50)_(ss0|ss80|ts)_s(\d+\.\d+)\.txt$';
        % Group 1: (ecoflex_50) - Material name
        % Group 2: (ss0|ss80|ts)  - Test type
        % Group 3: (\d+\.\d+)    - Sample number part
        tokens_eco = regexp(fileName, pattern_eco, 'tokens');

        if ~isempty(tokens_cerr)
            material_num = tokens_cerr{1}{1}; % e.g., '117' or '158'
            material = ['cerr_', material_num]; % Reconstruct full material name
            concentration = tokens_cerr{1}{2};   % Group 2 is concentration
            testFromFile = tokens_cerr{1}{3};    % Group 3 is test type
            sample_num_part = tokens_cerr{1}{4}; % Group 4 is sample number part
            sample = ['s', sample_num_part];
        elseif ~isempty(tokens_eco)
            material = tokens_eco{1}{1};         % Group 1 is material name
            concentration = 'N/A';               % No concentration for ecoflex
            testFromFile = tokens_eco{1}{2};     % Group 2 is test type
            sample_num_part = tokens_eco{1}{3};  % Group 3 is sample number part
            sample = ['s', sample_num_part];
        else
            warning('Could not parse filename: %s. Skipping.', fileName);
            continue;
        end

        % Verify test type matches folder (rest of the loop is the same)
        if ~strcmpi(testFromFile, currentTest)
             warning('Filename test type "%s" does not match folder "%s" for file: %s. Using folder type.', ...
                 testFromFile, currentTest, fileName);
             % Continue using currentTest from the folder structure
        end

        % --- Read Data File ---
        try
            fid = fopen(filePath, 'r');
            if fid == -1
                warning('Cannot open file: %s. Skipping.', filePath);
                continue;
            end

            headerLines = 0;
            dataStartLine = -1;
            headerInfo = {};
            currentLine = fgetl(fid);
            while ischar(currentLine)
                headerLines = headerLines + 1;
                headerInfo{end+1} = currentLine; %#ok<AGROW>
                if strcmpi(strtrim(currentLine), 'StartOfData')
                    dataStartLine = headerLines;
                    break;
                end
                currentLine = fgetl(fid);
            end
            fclose(fid);

            if dataStartLine == -1
                warning('Could not find "StartOfData" in file: %s. Skipping.', fileName);
                continue;
            end

            % Read numeric data using readmatrix (more robust)
            % Specify expected number of columns based on 'Nsig' if possible, otherwise auto-detect
            nsigLine = headerInfo{find(startsWith(headerInfo, 'Nsig'), 1)};
            numCols = sscanf(nsigLine, 'Nsig %d');
            if isempty(numCols)
                numCols = 17; % Default based on example
                warning('Could not read Nsig, assuming %d columns for %s', numCols, fileName);
            end

            rawData = readmatrix(filePath, 'FileType', 'text', ...
                                 'NumHeaderLines', dataStartLine, ...
                                 'ExpectedNumVariables', numCols, ...
                                 'ConsecutiveDelimitersRule', 'split', ...
                                 'Whitespace', ' \b\t');

            if isempty(rawData)
               warning('No numeric data found after StartOfData in file: %s. Skipping.', fileName);
               continue;
            end

            % --- Store Data ---
            fileCounter = fileCounter + 1;
            allData(fileCounter).Material = material;
            allData(fileCounter).Concentration = concentration;
            allData(fileCounter).TestType = currentTest; % Use folder structure test type
            allData(fileCounter).Sample = sample;
            allData(fileCounter).FilePath = filePath;
            allData(fileCounter).HeaderInfo = headerInfo; % Store header if needed later

            % Assign data to named fields based on colMap
            allData(fileCounter).Time = rawData(:, 1);
            allData(fileCounter).Temperature = rawData(:, colMap('Temperature'));
            allData(fileCounter).StorageModulus = rawData(:, colMap('Storage Modulus'));
            % Add other Sig columns if needed by extracting from rawData(:, SigN_column_number)
            allData(fileCounter).Stress = rawData(:, colMap('Stress'));
            allData(fileCounter).Strain = rawData(:, colMap('Strain'));
            % Add other fields as necessary...

        catch ME
            warning('Error processing file %s: %s. Skipping.', fileName, ME.message);
            if exist('fid', 'var') && fid ~= -1
                fclose(fid);
            end
        end
    end % End file loop
end % End test type loop

fprintf('Finished loading and parsing %d files.\n', fileCounter);

if fileCounter == 0
    error('No data files were successfully processed. Check paths and file formats.');
end

%% --- Plotting Section ---

disp('Starting plotting...');

% --- Helper Function for Averaging and Interpolation ---
function [x_common, y_mean, y_se, n_samples] = averageData(dataStructs, x_field, y_field, n_points)
    if isempty(dataStructs)
        x_common = []; y_mean = []; y_se = []; n_samples = 0;
        return;
    end

    n_samples = length(dataStructs);
    all_x = cell(1, n_samples);
    all_y = cell(1, n_samples);
    min_x_ends = zeros(1, n_samples);
    max_x_starts = zeros(1, n_samples);

    for k = 1:n_samples
        x_data = dataStructs(k).(x_field);
        y_data = dataStructs(k).(y_field);

        % Basic cleaning: Remove NaN rows if any exist
        nan_rows = isnan(x_data) | isnan(y_data);
        x_data(nan_rows) = [];
        y_data(nan_rows) = [];

        % Ensure x is monotonically increasing for interpolation
        [x_data_sorted, sort_idx] = sort(x_data);
        y_data_sorted = y_data(sort_idx);
        [x_unique, unique_idx] = unique(x_data_sorted);
        y_unique = y_data_sorted(unique_idx);

        if isempty(x_unique)
             warning('Sample %s has no valid data for %s vs %s.', dataStructs(k).Sample, y_field, x_field);
             all_x{k} = [];
             all_y{k} = [];
             min_x_ends(k) = NaN;
             max_x_starts(k) = NaN;
        else
            all_x{k} = x_unique;
            all_y{k} = y_unique;
            min_x_ends(k) = x_unique(end);
            max_x_starts(k) = x_unique(1);
        end
    end

    % Determine common interpolation range (maximum common range)
    common_start = max(max_x_starts(~isnan(max_x_starts)));
    common_end = min(min_x_ends(~isnan(min_x_ends)));

    if isempty(common_start) || isempty(common_end) || common_start >= common_end
        warning('Cannot determine a valid common interpolation range for the group.');
        x_common = []; y_mean = []; y_se = [];
        n_samples = length(dataStructs); % Return original count even if averaging fails
        return;
    end

    x_common = linspace(common_start, common_end, n_points);
    y_interp = zeros(n_points, n_samples);

    valid_sample_count = 0;
    for k = 1:n_samples
        if ~isempty(all_x{k})
             % Use 'linear' interpolation, handle edges if needed
             y_interp(:, k) = interp1(all_x{k}, all_y{k}, x_common, 'linear', NaN);
             if ~all(isnan(y_interp(:, k))) % Check if interpolation was successful
                 valid_sample_count = valid_sample_count + 1;
             else
                 y_interp(:, k) = NaN; % Ensure failed interpolations are NaN
             end
        else
             y_interp(:, k) = NaN; % Assign NaN if sample had no data
        end
    end

    % Filter out columns (samples) that are all NaN after interpolation
    valid_cols = ~all(isnan(y_interp), 1);
    y_interp_valid = y_interp(:, valid_cols);
    n_samples_valid = sum(valid_cols); % Update n_samples to only count valid ones for mean/SE

    if n_samples_valid == 0
        warning('No samples had valid data in the common range.');
        x_common = []; y_mean = []; y_se = [];
        n_samples = length(dataStructs);
        return;
    end

     % Calculate mean and standard error (ignoring NaNs across samples for each x point)
    y_mean = mean(y_interp_valid, 2, 'omitnan');

    if n_samples_valid > 1
        y_std = std(y_interp_valid, 0, 2, 'omitnan'); % Sample std dev (0 flag), ignore NaNs
        y_se = y_std ./ sqrt(sum(~isnan(y_interp_valid), 2)); % SE = std / sqrt(N), where N varies per x point
        y_se(sum(~isnan(y_interp_valid), 2) <= 1) = NaN; % SE not defined for 1 or 0 samples
    else
        y_se = nan(size(y_mean)); % Standard error is not defined for a single sample
    end
     n_samples = n_samples_valid; % Return the number of samples actually used in avg
end


% --- Task 3: Individual Plots (Optional, uncomment if needed) ---
% disp('Generating individual plots...');
% for i = 1:length(allData)
%     data = allData(i);
%     fig = figure('Visible', 'off'); % Create figure but don't show it
%     hold on;
%     grid on;
%     color = [0 0 0]; % Default color
%     plotTitle = sprintf('%s %s %s (Sample %s)', data.Material, data.Concentration, data.TestType, data.Sample);
%
%     if contains(data.Material, 'cerr')
%         cmap = colorMaps(data.Material);
%         idx = concColorIdx(data.Concentration);
%         color = cmap(idx, :);
%     elseif strcmp(data.Material, 'ecoflex_50')
%         color = colorMaps('ecoflex_50');
%     end
%
%     try
%         if contains(data.TestType, 'ss') % ss0 or ss80
%             plot(data.Strain, data.Stress, 'o-', 'Color', color, 'MarkerSize', 3);
%             xlabel('Strain (%)');
%             ylabel('Stress (MPa)');
%             title(plotTitle);
%         elseif strcmp(data.TestType, 'ts')
%             plot(data.Temperature, data.StorageModulus, 'o-', 'Color', color, 'MarkerSize', 3);
%             xlabel('Temperature (°C)');
%             ylabel('Storage Modulus (MPa)');
%             title(plotTitle);
%         end
%
%         hold off;
%         filename = sprintf('%s_%s_%s_%s_individual.png', data.Material, data.Concentration, data.TestType, data.Sample);
%         saveas(fig, fullfile(outputDir, filename));
%         close(fig);
%
%     catch ME_plot
%         warning('Failed to plot individual file %s: %s', data.FilePath, ME_plot.message);
%         if exist('fig', 'var') && ishandle(fig)
%             close(fig);
%         end
%     end
% end
% disp('Finished individual plots.');


% --- Task 6 & 7: Combined SS Plots (Cerr 117 & 158 + Ecoflex) ---
disp('Generating combined Stress-Strain plots...');
nInterpPoints = 100; % Number of points for interpolation

for iMat = 1:2 % Loop through cerr_117 and cerr_158
    materialName = materials{iMat};
    figure('Name', ['SS Comparison: ', materialName]);
    hold on;
    grid on;
    legendEntries = {};
    plotHandles = [];

    % Plot Cerr Samples
    cmap = colorMaps(materialName);
    for iConc = 1:length(concentrations)
        conc = concentrations{iConc};
        color = cmap(concColorIdx(conc), :);

        % SS0 Data
        idx_ss0 = find(strcmp({allData.Material}, materialName) & ...
                       strcmp({allData.Concentration}, conc) & ...
                       strcmp({allData.TestType}, 'ss0'));
        if ~isempty(idx_ss0)
            [x_ss0, y_mean_ss0, y_se_ss0, n_ss0] = averageData(allData(idx_ss0), 'Strain', 'Stress', nInterpPoints);
            if ~isempty(x_ss0) && n_ss0 > 0
                % Plot mean line
                h_mean = plot(x_ss0, y_mean_ss0, '-', 'Color', color, 'LineWidth', 1.5);
                plotHandles(end+1) = h_mean; % Store handle for legend
                legendEntries{end+1} = sprintf('%s Room Temp (N=%d)', conc, n_ss0);
                % Plot Standard Error Fill
                if n_ss0 > 1 && ~all(isnan(y_se_ss0))
                   fill([x_ss0; flipud(x_ss0)], [y_mean_ss0 - y_se_ss0; flipud(y_mean_ss0 + y_se_ss0)], ...
                        color, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
                   % Optional: Use shadedErrorBar if available
                   % shadedErrorBar(x_ss0, y_mean_ss0, y_se_ss0, {'-', 'Color', color, 'LineWidth', 1.5}, 0.2);
                end
            else
                 warning('No valid SS0 data to plot for %s %s', materialName, conc);
            end
        end

        % SS80 Data
        idx_ss80 = find(strcmp({allData.Material}, materialName) & ...
                        strcmp({allData.Concentration}, conc) & ...
                        strcmp({allData.TestType}, 'ss80'));
        if ~isempty(idx_ss80)
            [x_ss80, y_mean_ss80, y_se_ss80, n_ss80] = averageData(allData(idx_ss80), 'Strain', 'Stress', nInterpPoints);
             if ~isempty(x_ss80) && n_ss80 > 0
                % Plot mean line
                 h_mean_80 = plot(x_ss80, y_mean_ss80, '--', 'Color', color, 'LineWidth', 1.5);
                 % Only add legend entry if we haven't added the concentration yet
                 if isempty(find(strcmp(legendEntries, sprintf('%s 80C (N=%d)', conc, n_ss80)), 1)) && n_ss0 == 0 % Add if ss0 didn't exist
                    plotHandles(end+1) = h_mean_80; % Add handle if ss0 didn't plot for this conc
                    legendEntries{end+1} = sprintf('%s 80C (N=%d)', conc, n_ss80);
                 elseif isempty(find(contains(legendEntries, [conc,' ']), 1)) % Check if conc has any entry yet
                     plotHandles(end+1) = h_mean_80; % Add dummy handle if needed for combined legend later
                     legendEntries{end+1} = sprintf('%s 80C (N=%d)', conc, n_ss80);
                 end
                % Plot Standard Error Fill
                if n_ss80 > 1 && ~all(isnan(y_se_ss80))
                    fill([x_ss80; flipud(x_ss80)], [y_mean_ss80 - y_se_ss80; flipud(y_mean_ss80 + y_se_ss80)], ...
                         color, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'LineStyle', '--'); % Indicate dashed nature
                    % Optional: Use shadedErrorBar if available
                    % shadedErrorBar(x_ss80, y_mean_ss80, y_se_ss80, {'--', 'Color', color, 'LineWidth', 1.5}, 0.2);
                 end
             else
                 warning('No valid SS80 data to plot for %s %s', materialName, conc);
            end
        end
    end % End concentration loop

    % Plot Ecoflex Control
    ecoColor = colorMaps('ecoflex_50');
    % Ecoflex SS0
    idx_eco_ss0 = find(strcmp({allData.Material}, 'ecoflex_50') & strcmp({allData.TestType}, 'ss0'));
    if ~isempty(idx_eco_ss0)
        [x_eco_ss0, y_mean_eco_ss0, y_se_eco_ss0, n_eco_ss0] = averageData(allData(idx_eco_ss0), 'Strain', 'Stress', nInterpPoints);
        if ~isempty(x_eco_ss0) && n_eco_ss0 > 0
            h_eco_0 = plot(x_eco_ss0, y_mean_eco_ss0, '-', 'Color', ecoColor, 'LineWidth', 1.5);
            plotHandles(end+1) = h_eco_0;
            legendEntries{end+1} = sprintf('Ecoflex 50 Room Temp (N=%d)', n_eco_ss0);
            if n_eco_ss0 > 1 && ~all(isnan(y_se_eco_ss0))
                fill([x_eco_ss0; flipud(x_eco_ss0)], [y_mean_eco_ss0 - y_se_eco_ss0; flipud(y_mean_eco_ss0 + y_se_eco_ss0)], ...
                     ecoColor, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            end
        end
    end
    % Ecoflex SS80
    idx_eco_ss80 = find(strcmp({allData.Material}, 'ecoflex_50') & strcmp({allData.TestType}, 'ss80'));
     if ~isempty(idx_eco_ss80)
        [x_eco_ss80, y_mean_eco_ss80, y_se_eco_ss80, n_eco_ss80] = averageData(allData(idx_eco_ss80), 'Strain', 'Stress', nInterpPoints);
        if ~isempty(x_eco_ss80) && n_eco_ss80 > 0
            h_eco_80 = plot(x_eco_ss80, y_mean_eco_ss80, '--', 'Color', ecoColor, 'LineWidth', 1.5);
             % Add legend entry if SS0 didn't exist or if needed for combined legend
            if isempty(find(contains(legendEntries, 'Ecoflex 50'), 1))
                plotHandles(end+1) = h_eco_80;
                legendEntries{end+1} = sprintf('Ecoflex 50 80C (N=%d)', n_eco_ss80);
            elseif isempty(find(strcmp(legendEntries, sprintf('Ecoflex 50 80C (N=%d)', n_eco_ss80)), 1)) && n_eco_ss0 == 0
                 plotHandles(end+1) = h_eco_80;
                 legendEntries{end+1} = sprintf('Ecoflex 50 80C (N=%d)', n_eco_ss80);
            end

            if n_eco_ss80 > 1 && ~all(isnan(y_se_eco_ss80))
                fill([x_eco_ss80; flipud(x_eco_ss80)], [y_mean_eco_ss80 - y_se_eco_ss80; flipud(y_mean_eco_ss80 + y_se_eco_ss80)], ...
                     ecoColor, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'LineStyle', '--');
            end
        end
    end

    % Finalize Plot
    xlabel('Strain (%)');
    ylabel('Stress (MPa)');
    title(sprintf('DMA Stress Strain Curve %s', strrep(materialName, '_', ' '))); % Replace underscore for title
    legend(plotHandles, legendEntries, 'Location', 'best'); % Use handles and entries collected
    hold off;

    % Save Plot
    filename = sprintf('%s_SS_Comparison.png', materialName);
    saveas(gcf, fullfile(outputDir, filename));
    fprintf('Saved plot: %s\n', filename);

end % End material loop for SS plots

% --- Task 8 & 9: Combined TS Plots (Cerr 117 & 158 + Ecoflex) ---
disp('Generating combined Temperature Sweep plots...');

for iMat = 1:2 % Loop through cerr_117 and cerr_158
    materialName = materials{iMat};
    figure('Name', ['TS Comparison: ', materialName]);
    hold on;
    grid on;
    legendEntries_ts = {};
    plotHandles_ts = [];

    % Plot Cerr Samples
    cmap = colorMaps(materialName);
    for iConc = 1:length(concentrations)
        conc = concentrations{iConc};
        color = cmap(concColorIdx(conc), :);

        % TS Data
        idx_ts = find(strcmp({allData.Material}, materialName) & ...
                      strcmp({allData.Concentration}, conc) & ...
                      strcmp({allData.TestType}, 'ts'));
        if ~isempty(idx_ts)
            [x_ts, y_mean_ts, y_se_ts, n_ts] = averageData(allData(idx_ts), 'Temperature', 'StorageModulus', nInterpPoints);
            if ~isempty(x_ts) && n_ts > 0
                % Plot mean line
                h_mean = plot(x_ts, y_mean_ts, '-', 'Color', color, 'LineWidth', 1.5);
                plotHandles_ts(end+1) = h_mean; % Store handle for legend
                legendEntries_ts{end+1} = sprintf('%s (N=%d)', conc, n_ts);
                % Plot Standard Error Fill
                if n_ts > 1 && ~all(isnan(y_se_ts))
                    fill([x_ts; flipud(x_ts)], [y_mean_ts - y_se_ts; flipud(y_mean_ts + y_se_ts)], ...
                         color, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
                    % Optional: Use shadedErrorBar if available
                    % shadedErrorBar(x_ts, y_mean_ts, y_se_ts, {'-', 'Color', color, 'LineWidth', 1.5}, 0.2);
                end
            else
                warning('No valid TS data to plot for %s %s', materialName, conc);
            end
        end
    end % End concentration loop

    % Plot Ecoflex Control
    ecoColor = colorMaps('ecoflex_50');
    idx_eco_ts = find(strcmp({allData.Material}, 'ecoflex_50') & strcmp({allData.TestType}, 'ts'));
    if ~isempty(idx_eco_ts)
        [x_eco_ts, y_mean_eco_ts, y_se_eco_ts, n_eco_ts] = averageData(allData(idx_eco_ts), 'Temperature', 'StorageModulus', nInterpPoints);
         if ~isempty(x_eco_ts) && n_eco_ts > 0
            h_eco = plot(x_eco_ts, y_mean_eco_ts, '-', 'Color', ecoColor, 'LineWidth', 1.5);
            plotHandles_ts(end+1) = h_eco;
            legendEntries_ts{end+1} = sprintf('Ecoflex 50 (N=%d)', n_eco_ts);
            if n_eco_ts > 1 && ~all(isnan(y_se_eco_ts))
                fill([x_eco_ts; flipud(x_eco_ts)], [y_mean_eco_ts - y_se_eco_ts; flipud(y_mean_eco_ts + y_se_eco_ts)], ...
                     ecoColor, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            end
         end
    end

    % Finalize Plot
    xlabel('Temperature (°C)');
    ylabel('Storage Modulus (MPa)');
    title(sprintf('DMA Temperature Sweep %s', strrep(materialName, '_', ' '))); % Replace underscore
    legend(plotHandles_ts, legendEntries_ts, 'Location', 'best');
    hold off;

    % Save Plot
    filename = sprintf('%s_TS_Comparison.png', materialName);
    saveas(gcf, fullfile(outputDir, filename));
    fprintf('Saved plot: %s\n', filename);

end % End material loop for TS plots

disp('--- All plotting finished ---');