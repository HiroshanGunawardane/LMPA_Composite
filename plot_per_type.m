% MATLAB script to plot raw DMA data for files matching a specific prefix
clear; close all; clc;

% === Configuration ===
% <<< --- EDIT THIS LINE to change which files are plotted --- >>>
file_prefix = 'cerr_158_50v_ts'; % Example: Plot all samples for cerr_158 50v ts
% file_prefix = 'ecoflex_50_ts';      % Example: Plot all samples for ecoflex_50 ts
% file_prefix = 'cerr_117_10v_ss0'; % Example: Plot all samples for cerr_117 10v ss0
% <<< --------------------------------------------------------- >>>

% IMPORTANT: Set the base directory where ss0, ss80, ts folders reside
BASE_DIR = 'C:\Users\12369\Sync\UoW\Paper9 RAL ThemoE\2025_05_DMA_Final\finalCode\new_method'; % Base directory

% Define the column indices (adjust if your format differs)
COL_MAP = struct(...
    'Strain', 10, ... % Adjusted index based on python code (9 -> 10 for 1-based)
    'Stress', 5, ...  % Adjusted index (4 -> 5)
    'Temperature', 2, ... % Adjusted index (1 -> 2)
    'StorageModulus', 3 ... % Adjusted index (2 -> 3)
);
VALID_TEST_TYPES = {'ss0', 'ss80', 'ts'}; % Cell array of valid test type strings

% === Main Plotting Logic ===
fprintf("Attempting to plot files starting with: '%s'\n", file_prefix);

% 1. Infer Test Type and Validate Input
test_type = []; % Initialize as empty
try
    prefix_parts = strsplit(file_prefix, '_');
    if isempty(prefix_parts) || isempty(prefix_parts{1})
        error('File prefix cannot be empty.');
    end
    potential_test_type = lower(prefix_parts{end});

    if ismember(potential_test_type, VALID_TEST_TYPES)
        test_type = potential_test_type;
    else
        error('Inferred test type ''%s'' from end of prefix is not valid.', potential_test_type);
    end
catch ME
    fprintf(2, 'Error: Could not determine a valid test type (''ss0'', ''ss80'', ''ts'') from the end of the prefix ''%s''.\n', file_prefix);
    fprintf(2, 'Details: %s\n', ME.message);
    fprintf(2, 'Please ensure the prefix ends with one of: %s\n', strjoin(VALID_TEST_TYPES, ', '));
    error('Stopping due to invalid prefix.'); % Stop execution
end

% 2. Determine Target Directory and Plot Parameters
target_dir = fullfile(BASE_DIR, test_type, 'export');
if ~isfolder(target_dir)
    error('Stopping. Directory not found based on inferred test type ''%s'': %s', test_type, target_dir);
end

% Determine plot labels and column names based on test type
x_col_name = ''; y_col_name = ''; x_label = ''; y_label = '';
if ismember(test_type, {'ss0', 'ss80'})
    x_col_name = 'Strain'; y_col_name = 'Stress';
    x_label = 'Strain (%)'; y_label = 'Stress (MPa)';
else % test_type == 'ts'
    x_col_name = 'Temperature'; y_col_name = 'StorageModulus'; % Use struct field names
    x_label = 'Temperature (°C)'; y_label = 'Storage Modulus (MPa)';
end

% Get column indices from COL_MAP
try
    x_col_idx = COL_MAP.(x_col_name);
    y_col_idx = COL_MAP.(y_col_name);
catch ME
    error('Stopping. Column name ''%s'' or ''%s'' not found in COL_MAP configuration. Error: %s', x_col_name, y_col_name, ME.identifier);
end


% 3. Find Matching Files and Plot
fprintf("Searching for files starting with '%s' in '%s'...\n", file_prefix, target_dir);

% Find files matching the pattern
file_pattern = sprintf('%s*.txt', file_prefix);
files = dir(fullfile(target_dir, file_pattern));

% Prepare figure and axes
fig = figure; % Create a visible figure
ax = axes(fig);
hold(ax, 'on'); % Hold on to plot multiple lines
colors = lines(numel(files)); % Generate distinct colors for lines
files_found = numel(files);
files_plotted = 0;
plot_handles = []; % Store handles for the legend

for i = 1:files_found
    current_filename = files(i).name;
    filepath = fullfile(target_dir, current_filename);

    fprintf("  Processing: %s\n", current_filename);

    sample_id = parseSampleIdMATLAB(current_filename);
    if isempty(sample_id)
        plot_label = strrep(current_filename, '_', '\_'); % Use filename, escape underscores for display
    else
        plot_label = sample_id;
    end

    % Read data using the simplified reader for this script
    raw_data = readDataFileMATLAB_Simple(filepath);
    if isempty(raw_data) || size(raw_data, 1) == 0
        warning('    Skipping %s (label: %s): No data read.', current_filename, plot_label);
        continue;
    end

    % --- Process and Plot Data ---
    try
        % Check if enough columns exist
        max_req_col = max(x_col_idx, y_col_idx);
        if size(raw_data, 2) < max_req_col
             error('Not enough columns (Needed max index %d, Found: %d)', max_req_col, size(raw_data, 2));
        end

        % Extract raw data columns
        x_raw = raw_data(:, x_col_idx);
        y_raw = raw_data(:, y_col_idx);

        % Filter out non-finite values (NaN, Inf)
        is_finite_pair = isfinite(x_raw) & isfinite(y_raw);
        x = x_raw(is_finite_pair);
        y = y_raw(is_finite_pair);

        % Check if enough valid points remain
        if numel(x) < 2
            warning('    Skipping %s (label: %s): Not enough valid data points (< 2).', current_filename, plot_label);
            continue;
        end

        % Sort data by x-values for plotting lines correctly
        [x_plot, sort_idx] = sort(x);
        y_plot = y(sort_idx);

        % Plot the data
        h = plot(ax, x_plot, y_plot, '-', 'DisplayName', plot_label, 'LineWidth', 1.2, 'Color', colors(i,:));
        plot_handles(end+1) = h; % Store handle for legend
        files_plotted = files_plotted + 1;

    catch ME_plot
         warning('    Skipping %s (label: %s): Error processing/plotting data - %s.', current_filename, plot_label, ME_plot.message);
         continue;
    end
    % --- End Process and Plot ---

end % End loop through files

hold(ax, 'off'); % Release hold

% 4. Finalize and Show Plot
fprintf("\nFound %d files potentially matching prefix.\n", files_found);
if files_plotted > 0
    fprintf("Plotting data for %d samples.\n", files_plotted);

    % Set plot title and labels
    title(ax, sprintf('Raw Samples Matching Prefix: ''%s''', strrep(file_prefix, '_', '\_')), 'Interpreter', 'tex');
    xlabel(ax, x_label);
    ylabel(ax, y_label);
    grid(ax, 'on');
    ax.GridLineStyle = ':';
    ax.GridAlpha = 0.6;

    % Add legend outside the plot area
    lgd = legend(ax, plot_handles, 'Location', 'eastoutside', 'FontSize', 8);
    title(lgd, 'Sample ID / Filename');

    % Optional: Apply log scale for TS plots if Y data is positive
    if strcmp(test_type, 'ts')
        try
            all_y_data = [];
            plotted_lines = findobj(ax, 'Type', 'line'); % Get handles to plotted lines
            for k = 1:numel(plotted_lines)
                ydata = plotted_lines(k).YData;
                finite_y = ydata(isfinite(ydata)); % Only consider finite values
                if ~isempty(finite_y)
                   all_y_data = [all_y_data; finite_y(:)]; % Append as column vector
                end
            end

            if ~isempty(all_y_data) && all(all_y_data > 1e-9) % Check if all finite values are positive
                set(ax, 'YScale', 'log');
                ylabel(ax, sprintf('%s (log scale)', y_label)); % Update label
                fprintf('Applied log scale to Y-axis.\n');
            elseif ~isempty(all_y_data)
                 fprintf('Did not apply log scale: Some Y-values are non-positive.\n');
            end
        catch ME_log
             warning('Could not evaluate data or set log scale: %s', ME_log.message);
        end
    end

    % Adjust figure position slightly if needed for legend (often handled well by 'eastoutside')
    % Example: fig.Position = fig.Position + [0 0 50 0]; % Make figure wider

else
    fprintf("No valid data found to plot for files starting with '%s' in %s.\n", file_prefix, target_dir);
    close(fig); % Close the empty figure
end

% === Helper Functions ===

function sample_id = parseSampleIdMATLAB(filename_str)
    % Extracts sample ID (e.g., 's1', 's2') from the filename.
    sample_id = []; % Default return empty
    try
        [~, base_name, ~] = fileparts(filename_str); % Removes extension
        parts = strsplit(base_name, '_');
        if isempty(parts) || isempty(parts{1})
            return; % Invalid name
        end

        % Iterate backwards through parts to find the sample ID
        for i = numel(parts):-1:1
            part = parts{i};
            if startsWith(part, 's') && length(part) > 1
                num_part_str = part(2:end);
                % Check if the rest are digits
                if all(isstrprop(num_part_str, 'digit'))
                    sample_id = part;
                    return; % Found it
                end
            end
        end
        % If loop finishes without returning, ID was not found
        warning('Could not find standard sample ID (''s#'') in %s. No label assigned.', filename_str);

    catch ME
        warning('Error parsing sample ID from %s: %s', filename_str, ME.message);
        sample_id = []; % Ensure empty on error
    end
end


function data = readDataFileMATLAB_Simple(filepath)
    % Reads DMA data file (simplified version for this script).
    % Tries common encodings, skips header, extracts numeric data after 'StartOfData'.
    data = []; % Initialize output
    encodings_to_try = {'UTF-16LE', 'UTF-8', 'ISO-8859-1'}; % ISO-8859-1 is similar to latin-1
    success = false;
    fid = -1;

    for i_enc = 1:numel(encodings_to_try)
        current_encoding = encodings_to_try{i_enc};
        data_lines_temp = {}; % Reset temporary storage for each encoding try
        in_data_section = false;
        line_num = 0;

        try
            fid = fopen(filepath, 'rt', 'n', current_encoding);
            if fid == -1
                error('fopen failed'); % Will be caught by catch block
            end

            while ~feof(fid)
                line = fgetl(fid);
                line_num = line_num + 1;
                if line == -1, break; end
                stripped_line = strtrim(line);

                if isempty(stripped_line), continue; end

                if strcmp(stripped_line, 'StartOfData')
                    in_data_section = true;
                    continue; % Move to next line
                end

                if in_data_section
                    try
                        % Split by whitespace and convert to double
                        num_vals = str2double(strsplit(stripped_line));
                        % Check if any conversion failed (resulted in NaN)
                        if any(isnan(num_vals))
                            warning('MATLAB:readDataFile:NonNumericRow', ...
                                '[%s] Skipping non-numeric data in row %d of %s: ''%s''', ...
                                current_encoding, line_num, filepath, stripped_line);
                            continue; % Skip this row
                        end
                        data_lines_temp{end+1, 1} = num_vals; % Store row vector
                    catch ME_convert
                        warning('MATLAB:readDataFile:ConversionError', ...
                            '[%s] Error converting row %d in %s: ''%s''. Error: %s', ...
                             current_encoding, line_num, filepath, stripped_line, ME_convert.message);
                        continue; % Skip this row
                    end
                end
            end
            fclose(fid);
            fid = -1; % Reset fid

            % Check if any data was actually read
            if ~isempty(data_lines_temp)
                 % Check for consistent column counts before converting to matrix
                num_cols = cellfun(@numel, data_lines_temp);
                if ~all(num_cols == num_cols(1))
                     warning('MATLAB:readDataFile:InconsistentColumns', ...
                         '[%s] Inconsistent column counts in data section of %s. Using rows with %d columns.', ...
                         current_encoding, filepath, num_cols(1));
                     % Filter rows with the first row's column count
                     consistent_rows_idx = (num_cols == num_cols(1));
                     data_lines_temp = data_lines_temp(consistent_rows_idx);
                     if isempty(data_lines_temp)
                         warning('MATLAB:readDataFile:NoConsistentRows', '[%s] No consistent data rows found after filtering in %s.', current_encoding, filepath);
                         continue; % Try next encoding if filtering removed everything
                     end
                end

                % Convert cell array of row vectors to a numeric matrix
                data = vertcat(data_lines_temp{:});
                success = true;
                break; % Exit encoding loop on success
            elseif ~in_data_section && line_num > 0 % File read but no 'StartOfData'
                warning('MATLAB:readDataFile:NoStartOfData', '''StartOfData'' marker not found in %s using encoding %s.', filepath, current_encoding);
                % Continue to try next encoding
            elseif in_data_section && isempty(data_lines_temp) % 'StartOfData' found but no data rows followed
                 warning('MATLAB:readDataFile:NoDataAfterStart', 'No valid data rows found after ''StartOfData'' in %s using encoding %s.', filepath, current_encoding);
                 % Continue to try next encoding
            end

        catch ME_read
            if fid ~= -1, try fclose(fid); catch, end; fid = -1; end % Ensure file closure
            % Optional: Display specific warning for file not found vs other errors
            if strcmp(ME_read.identifier, 'MATLAB:FileIO:InvalidFid') || contains(ME_read.message, 'fopen failed') || contains(ME_read.message, 'Cannot open file')
                 % This might indicate permission issue or file truly gone between dir() and fopen()
                 warning('MATLAB:readDataFile:FileOpenError', 'Could not open file %s with encoding %s. Check path and permissions.', filepath, current_encoding);
                 % If fopen fails, maybe don't try other encodings? depends. Let's break.
                 % break; % Stop trying encodings if file can't be opened at all
                 % Or let it try other encodings just in case? Let's continue for now.
            else
                 % General read error (e.g., decoding issue not caught by fopen encoding)
                 fprintf('Debug: Error reading %s with %s: %s\n', filepath, current_encoding, ME_read.message); % More detailed debug info
            end
             % Continue to next encoding
        end
    end % End encoding loop

    if ~success
         warning('MATLAB:readDataFile:ReadFailed', 'Could not successfully read data from %s with any attempted encoding.', filepath);
         data = []; % Ensure empty return on total failure
    end
end