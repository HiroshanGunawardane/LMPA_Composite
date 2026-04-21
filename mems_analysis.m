% MATLAB script to process and plot DMA data
clear; close all; clc; % Start fresh

% --- Configuration ---
base_dir = 'C:\Users\12369\Sync\UoW\Paper9 RAL ThemoE\2025_05_DMA_Final\finalCode\new_method'; % Base directory <<--- CHECK THIS PATH
output_dir = fullfile(base_dir, 'output_matlab'); % Separate output dir
test_types = {'ss0', 'ss80', 'ts'}; % Types needed for loading structure
materials = {'cerr_117', 'cerr_158', 'ecoflex_50'};
concentrations = {'10v', '20v', '30v', '40v', '50v'}; % For 'cerr' types

% --- <<< Young's Modulus Calculation Configuration (for ss0) >>> ---
YOUNG_MOD_STRAIN_LIMIT_PERCENT = 6.0; % Max strain (%) from AVG curve for linear fit
YOUNG_MOD_MIN_POINTS_FOR_FIT = 5;     % Min number of AVG points required in range for fit
YOUNG_MOD_MIN_R_SQUARED = 0.98;       % Minimum R-squared value to accept the fit
N_INTERP_POINTS_FOR_MODULUS = 200; % Use more points for smoother avg curve for fit % <- Note: This is NOT used in the current Modulus calc method (uses individual fits)

% --- <<< Temperature Offset Configuration >>> ---
temperature_offsets = containers.Map('KeyType', 'char', 'ValueType', 'double');
temperature_offsets('cerr_117_10v') = -3;
temperature_offsets('cerr_117_20v') = -3;
temperature_offsets('cerr_117_30v') = -3;
temperature_offsets('cerr_117_40v') = -3;
temperature_offsets('cerr_117_50v') = -3;
temperature_offsets('cerr_158_10v') = -6;
temperature_offsets('cerr_158_20v') = -6;
temperature_offsets('cerr_158_30v') = -6;
temperature_offsets('cerr_158_40v') = -6;
temperature_offsets('cerr_158_50v') = -6;
% --- End of Offset Configuration ---


% Create output directory
if ~isfolder(output_dir)
    mkdir(output_dir);
    fprintf('Created output directory: %s\n', output_dir);
else
    fprintf('Output directory exists: %s\n', output_dir);
end

% Define Colormaps
n_concentrations = numel(concentrations);
cmap_117_base = copper(n_concentrations);
cmap_158_base = lines(n_concentrations);

colors_117 = containers.Map('KeyType', 'char', 'ValueType', 'any');
colors_158 = containers.Map('KeyType', 'char', 'ValueType', 'any');
if n_concentrations > 0
    for i = 1:n_concentrations
        colors_117(concentrations{i}) = cmap_117_base(i, :);
        colors_158(concentrations{i}) = cmap_158_base(i, :);
    end
else
    warning('No concentrations defined.');
end
color_ecoflex = [0.4 0.4 0.4]; % Grey

% Columns mapping (Using struct for easy access)
col_map = struct(...
    'Time', 1, 'Temperature', 2, 'StorageModulus', 3, 'LossModulus', 4, ...
    'Stress', 5, 'TanDelta', 6, 'Frequency', 7, 'DriveForce', 8, ...
    'Amplitude', 9, 'Strain', 10, 'Displacement', 11, 'StaticForce', 12, ...
    'Position', 13, 'Length', 14, 'Force', 15, 'Stiffness', 16, ...
    'GCAPressure', 17 ...
);

% --- Data Loading and Parsing ---
all_data = struct();
file_counter = 0;
fprintf('Starting data loading and parsing...\n');

for i_test = 1:numel(test_types)
    test_folder_name = test_types{i_test};
    export_dir = fullfile(base_dir, test_folder_name, 'export');

    if ~isfolder(export_dir)
        warning('Directory not found: %s. Skipping.', export_dir);
        continue;
    end

    fprintf('Processing directory: %s\n', export_dir);
    files = dir(fullfile(export_dir, '*.txt'));

    for i_file = 1:numel(files)
        filepath = fullfile(export_dir, files(i_file).name);
        filename = files(i_file).name;

        % Parse Filename
        [material, concentration, file_test_type, sample] = parseFilenameMATLAB(filename);
        if isempty(material), continue; end % Skip if parsing failed

        % Use the folder name as the definitive test type
        current_test_type = test_folder_name;
        if ~strcmp(file_test_type, current_test_type) && ~startsWith(file_test_type, current_test_type)
            warning('Filename test type "%s" inconsistent with folder "%s" for file: %s. Using folder type "%s".', ...
                    file_test_type, current_test_type, filename, current_test_type);
        end

        % Read Data File
        [raw_data, ~] = readDataFileMATLAB(filepath, col_map);
        if isempty(raw_data), continue; end

        % Ensure enough columns for required data
        required_cols = [col_map.Strain, col_map.Stress, col_map.Temperature, col_map.StorageModulus];
        max_required_index = max(required_cols);
        if size(raw_data, 2) < max_required_index
             warning('Skipping file %s: Not enough columns (%d < %d).', ...
                     filepath, size(raw_data, 2), max_required_index);
             continue;
        end

        % Store relevant columns and info
        data_struct = struct();
        data_struct.filepath = filepath;
        data_struct.sample = sample;
        data_struct.original_material = material; % Store for offset lookup & results
        data_struct.original_concentration = concentration; % Store for offset lookup & results

        try
            data_struct.Strain = raw_data(:, col_map.Strain);
            data_struct.Stress = raw_data(:, col_map.Stress);
            data_struct.Temperature = raw_data(:, col_map.Temperature);
            data_struct.StorageModulus = raw_data(:, col_map.StorageModulus);
        catch ME
            warning('Error extracting columns from %s: %s. Skipping file.', filepath, ME.message);
            continue;
        end

        % Sanitize field names for struct storage
        material_field = matlab.lang.makeValidName(material);
        conc_field = '';
        if strcmp(concentration, 'N/A')
            conc_field = 'NA';
        elseif endsWith(concentration, 'v') && length(concentration) > 1
            conc_field = matlab.lang.makeValidName(['v' concentration(1:end-1)]); % '10v' -> 'v10'
        else
            warning('Concentration format unexpected for sanitization: %s. Using raw.', concentration);
            conc_field = matlab.lang.makeValidName(concentration); % Fallback
        end
        test_type_field = matlab.lang.makeValidName(current_test_type); % Use folder name 'ss0', 'ss80', 'ts'

        % Store data in nested struct
        if ~isfield(all_data, material_field), all_data.(material_field) = struct(); end
        if ~isfield(all_data.(material_field), conc_field), all_data.(material_field).(conc_field) = struct(); end
        if ~isfield(all_data.(material_field).(conc_field), test_type_field), all_data.(material_field).(conc_field).(test_type_field) = {}; end

        all_data.(material_field).(conc_field).(test_type_field){end+1} = data_struct;
        file_counter = file_counter + 1;
    end
end

fprintf('Finished loading and parsing data from %d files.\n', file_counter);
if file_counter == 0
    error('No data files were successfully processed. Check paths, file formats, and encoding.');
end

% --- <<< Apply Temperature Offsets >>> ---
fprintf('\nApplying configured temperature offsets...\n');
offset_applied_count = 0;
material_fields = fieldnames(all_data);
for i_mat_f = 1:numel(material_fields)
    mat_f = material_fields{i_mat_f};
    concentration_fields = fieldnames(all_data.(mat_f));
    for i_conc_f = 1:numel(concentration_fields)
        conc_f = concentration_fields{i_conc_f};
        test_type_fields = fieldnames(all_data.(mat_f).(conc_f));
        for i_test_f = 1:numel(test_type_fields)
            test_f = test_type_fields{i_test_f};
            data_list = all_data.(mat_f).(conc_f).(test_f);

            if isempty(data_list) || ~iscell(data_list) || ~isfield(data_list{1}, 'original_material') || ~isfield(data_list{1}, 'original_concentration')
                continue; % Skip if no data or missing original info
            end

            original_mat = data_list{1}.original_material;
            original_conc = data_list{1}.original_concentration;

            if strcmp(original_mat, 'ecoflex_50') || strcmp(original_conc, 'N/A'), continue; end % Skip offset for these

            offset_key = sprintf('%s_%s', original_mat, original_conc);
            if isKey(temperature_offsets, offset_key)
                offset_value = temperature_offsets(offset_key);
                if offset_value ~= 0 % Only report/count non-zero offsets
                    fprintf('  Applying offset %.2f C to %s (Test Type: %s)\n', offset_value, offset_key, test_f);
                    for i_sample = 1:numel(data_list)
                        if isfield(all_data.(mat_f).(conc_f).(test_f){i_sample}, 'Temperature')
                            all_data.(mat_f).(conc_f).(test_f){i_sample}.Temperature = ...
                                all_data.(mat_f).(conc_f).(test_f){i_sample}.Temperature + offset_value;
                            offset_applied_count = offset_applied_count + 1;
                        else
                             warning('Temperature field missing for offset: sample %d, %s/%s/%s.', i_sample, mat_f, conc_f, test_f);
                        end
                    end
                end
            end
        end
    end
end
if offset_applied_count > 0
    fprintf('Finished applying temperature offsets to %d data entries.\n', offset_applied_count);
else
    fprintf('No non-zero temperature offsets were applied.\n');
end
% --- <<< End Apply Temperature Offsets >>> ---


% --- <<< Generate Individual RAW Data Plots >>> ---
fprintf('\nGenerating individual raw data plots (cerr materials only)...\n');
individual_plot_dir = fullfile(output_dir, 'individual_raw_plots');
if ~isfolder(individual_plot_dir), mkdir(individual_plot_dir); end
fprintf('Individual raw plots will be saved in: %s\n', individual_plot_dir);

cerr_materials_plot = {'cerr_117', 'cerr_158'};

for i_mat = 1:numel(cerr_materials_plot)
    mat = cerr_materials_plot{i_mat};
    material_field = matlab.lang.makeValidName(mat);
    fprintf('  Processing individual raw plots for: %s\n', mat);
    if ~isfield(all_data, material_field), fprintf('    Skipping %s: No data loaded.\n', mat); continue; end

    colors_mat = [];
    if strcmp(mat, 'cerr_117'), colors_mat = colors_117;
    elseif strcmp(mat, 'cerr_158'), colors_mat = colors_158;
    else continue; end

    for i_conc = 1:numel(concentrations)
        conc = concentrations{i_conc}; % Original name '10v'
        conc_field = ''; % Init
        if endsWith(conc, 'v') && length(conc)>1, conc_field = matlab.lang.makeValidName(['v' conc(1:end-1)]);
        else conc_field = matlab.lang.makeValidName(conc); end

        if ~isfield(all_data.(material_field), conc_field), continue; end

        original_conc_for_plot = conc; % Use original name for color/title
        if ~isKey(colors_mat, original_conc_for_plot)
             warning('Could not find color for: %s', original_conc_for_plot); color = [0.5 0.5 0.5];
         else color = colors_mat(original_conc_for_plot); end

        for i_test = 1:numel(test_types)
            test_t = test_types{i_test};
            test_type_field = matlab.lang.makeValidName(test_t);

            if ~isfield(all_data.(material_field).(conc_field), test_type_field), continue; end
            data_list = all_data.(material_field).(conc_field).(test_type_field);
            if isempty(data_list) || ~iscell(data_list), continue; end % Check if cell array

            x_col_name = ''; y_col_name = ''; x_label = ''; y_label = ''; plot_type_str = ''; is_ts_plot = false;
            if ismember(test_t, {'ss0', 'ss80'})
                x_col_name = 'Strain'; y_col_name = 'Stress'; x_label = 'Strain (%)'; y_label = 'Stress (MPa)'; plot_type_str = 'Stress-Strain (Raw Samples)';
            elseif strcmp(test_t, 'ts')
                x_col_name = 'Temperature'; y_col_name = 'StorageModulus'; x_label = 'Temperature (°C) [Offset Applied]'; y_label = 'Storage Modulus (MPa)'; plot_type_str = 'Temp Sweep (Raw Samples)'; is_ts_plot = true;
            else continue; end

            fig = figure('Visible', 'off'); ax = axes(fig); hold(ax, 'on');
            n_samples_plotted = 0; legend_handles = [];

            for i_sample = 1:numel(data_list)
                sample_data = data_list{i_sample};
                if ~isstruct(sample_data) || ~isfield(sample_data, x_col_name) || ~isfield(sample_data, y_col_name), continue; end % Check if struct and has fields
                x_raw = sample_data.(x_col_name); y_raw = sample_data.(y_col_name);
                is_valid = ~isnan(x_raw) & ~isnan(y_raw); x = x_raw(is_valid); y = y_raw(is_valid);

                % --- Plot Raw Data (without (0,0) offset) ---
                if isempty(x), continue; end
                h_plot = plot(ax, x, y, '-', 'Color', color, 'LineWidth', 1);
                if n_samples_plotted == 0, legend_handles = h_plot; end
                n_samples_plotted = n_samples_plotted + 1;
            end

            if n_samples_plotted == 0, close(fig); continue; end

            hold(ax, 'off');
            title_mat_disp = strrep(strrep(mat, '_', ' '), 'cerr ', 'Cerrolow ');
            title(ax, {sprintf('%s - %s - %s (N=%d)', title_mat_disp, original_conc_for_plot, upper(test_t), n_samples_plotted), sprintf('(%s)', plot_type_str)});
            xlabel(ax, x_label); ylabel(ax, y_label); grid(ax, 'off'); ax.GridLineStyle = ':'; ax.GridAlpha = 0.6;
            if is_ts_plot, xlim(ax, [40, inf]); end % Apply 40C limit only to TS plots
            legend(ax, legend_handles, {sprintf('%s', original_conc_for_plot)}, 'Location', 'eastoutside');

            plot_filename = fullfile(individual_plot_dir, sprintf('%s_%s_%s_individual_raw.png', mat, original_conc_for_plot, test_t));
            try print(fig, plot_filename, '-dpng', '-r150');
            catch ME_save, fprintf('Error saving plot %s: %s\n', plot_filename, ME_save.message); end
            close(fig);
        end
    end
end
fprintf('Finished generating individual raw data plots.\n');


% --- Plotting Section (Combined Plots) ---
fprintf('\nStarting combined comparison plotting...\n');
n_interp_points_plots = 100; % Interpolation points for plots only

% --- Combined SS Plots (Cerr vs Ecoflex) ---
for i_mat = 1:numel(cerr_materials_plot)
    material_to_plot = cerr_materials_plot{i_mat};
    material_field = matlab.lang.makeValidName(material_to_plot);

    fig_ss = figure('Visible', 'off'); ax_ss = axes(fig_ss); hold(ax_ss, 'on');
    legend_handles_ss = []; legend_labels_ss = {}; colors_ss = [];
    if strcmp(material_to_plot, 'cerr_117'), colors_ss = colors_117;
    elseif strcmp(material_to_plot, 'cerr_158'), colors_ss = colors_158;
    else close(fig_ss); continue; end

    % Plot Cerr Samples
    for i_conc = 1:numel(concentrations)
        conc = concentrations{i_conc}; % Original name '10v'
        conc_field = ''; % Init
        if endsWith(conc, 'v') && length(conc)>1, conc_field = matlab.lang.makeValidName(['v' conc(1:end-1)]);
        else conc_field = matlab.lang.makeValidName(conc); end

        if ~isKey(colors_ss, conc), continue; end; color = colors_ss(conc);
        if ~isfield(all_data, material_field) || ~isfield(all_data.(material_field), conc_field), continue; end

        % SS0 Data
        test_type_field_ss0 = matlab.lang.makeValidName('ss0');
        if isfield(all_data.(material_field).(conc_field), test_type_field_ss0)
            ss0_list = all_data.(material_field).(conc_field).(test_type_field_ss0);
            if ~isempty(ss0_list) && iscell(ss0_list)
                % <<< APPLY ZERO OFFSET FOR SS0 >>>
                [x_ss0, mean_ss0, se_ss0, n_ss0] = averageInterpolateDataMATLAB(ss0_list, 'Strain', 'Stress', n_interp_points_plots, true);
                if ~isempty(x_ss0) && ~isempty(mean_ss0) && ~all(isnan(mean_ss0))
                    h = plot(ax_ss, x_ss0, mean_ss0, '-', 'Color', color, 'LineWidth', 1.5);
                    legend_handles_ss(end+1) = h; legend_labels_ss{end+1} = sprintf('%s Room Temp.', conc);
                    if ~isempty(se_ss0) && n_ss0 > 1 && ~all(isnan(se_ss0))
                        valid_se = ~isnan(se_ss0) & ~isnan(mean_ss0);
                        if any(valid_se), fill(ax_ss, [x_ss0(valid_se); flipud(x_ss0(valid_se))], [(mean_ss0(valid_se) - se_ss0(valid_se)); flipud(mean_ss0(valid_se) + se_ss0(valid_se))], color, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); end
                    end
                end
            end
        end

        % SS80 Data
        test_type_field_ss80 = matlab.lang.makeValidName('ss80');
        if isfield(all_data.(material_field).(conc_field), test_type_field_ss80)
            ss80_list = all_data.(material_field).(conc_field).(test_type_field_ss80);
            if ~isempty(ss80_list) && iscell(ss80_list)
                % <<< APPLY ZERO OFFSET FOR SS80 >>>
                [x_ss80, mean_ss80, se_ss80, n_ss80] = averageInterpolateDataMATLAB(ss80_list, 'Strain', 'Stress', n_interp_points_plots, true);
                 if ~isempty(x_ss80) && ~isempty(mean_ss80) && ~all(isnan(mean_ss80))
                    h = plot(ax_ss, x_ss80, mean_ss80, '--', 'Color', color, 'LineWidth', 1.5);
                    legend_handles_ss(end+1) = h; legend_labels_ss{end+1} = sprintf('%s 80C', conc);
                    if ~isempty(se_ss80) && n_ss80 > 1 && ~all(isnan(se_ss80))
                         valid_se = ~isnan(se_ss80) & ~isnan(mean_ss80);
                         if any(valid_se), fill(ax_ss, [x_ss80(valid_se); flipud(x_ss80(valid_se))], [(mean_ss80(valid_se) - se_ss80(valid_se)); flipud(mean_ss80(valid_se) + se_ss80(valid_se))], color, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'LineStyle', '--'); end % Note: fill linestyle ignored
                    end
                end
            end
        end
    end

    % Plot Ecoflex Control
    material_eco = 'ecoflex_50'; material_eco_field = matlab.lang.makeValidName(material_eco); conc_eco_field = 'NA';
    if isfield(all_data, material_eco_field) && isfield(all_data.(material_eco_field), conc_eco_field)
        eco_data = all_data.(material_eco_field).(conc_eco_field);
        % Ecoflex SS0
        test_type_field_ss0 = matlab.lang.makeValidName('ss0');
        if isfield(eco_data, test_type_field_ss0)
            eco_ss0_list = eco_data.(test_type_field_ss0);
            if ~isempty(eco_ss0_list) && iscell(eco_ss0_list)
                 % <<< APPLY ZERO OFFSET FOR SS0 >>>
                [x_eco_ss0, mean_eco_ss0, se_eco_ss0, n_eco_ss0] = averageInterpolateDataMATLAB(eco_ss0_list, 'Strain', 'Stress', n_interp_points_plots, true);
                if ~isempty(x_eco_ss0) && ~isempty(mean_eco_ss0) && ~all(isnan(mean_eco_ss0))
                    h = plot(ax_ss, x_eco_ss0, mean_eco_ss0, '-', 'Color', color_ecoflex, 'LineWidth', 1.5);
                    legend_handles_ss(end+1) = h; legend_labels_ss{end+1} = 'Ecoflex 50 Room Temp.';
                     if ~isempty(se_eco_ss0) && n_eco_ss0 > 1 && ~all(isnan(se_eco_ss0))
                         valid_se = ~isnan(se_eco_ss0) & ~isnan(mean_eco_ss0);
                         if any(valid_se), fill(ax_ss, [x_eco_ss0(valid_se); flipud(x_eco_ss0(valid_se))], [(mean_eco_ss0(valid_se) - se_eco_ss0(valid_se)); flipud(mean_eco_ss0(valid_se) + se_eco_ss0(valid_se))], color_ecoflex, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); end
                     end
                end
            end
        end
        % Ecoflex SS80
        test_type_field_ss80 = matlab.lang.makeValidName('ss80');
        if isfield(eco_data, test_type_field_ss80)
            eco_ss80_list = eco_data.(test_type_field_ss80);
             if ~isempty(eco_ss80_list) && iscell(eco_ss80_list)
                 % <<< APPLY ZERO OFFSET FOR SS80 >>>
                [x_eco_ss80, mean_eco_ss80, se_eco_ss80, n_eco_ss80] = averageInterpolateDataMATLAB(eco_ss80_list, 'Strain', 'Stress', n_interp_points_plots, true);
                 if ~isempty(x_eco_ss80) && ~isempty(mean_eco_ss80) && ~all(isnan(mean_eco_ss80))
                    h = plot(ax_ss, x_eco_ss80, mean_eco_ss80, '--', 'Color', color_ecoflex, 'LineWidth', 1.5);
                    legend_handles_ss(end+1) = h; legend_labels_ss{end+1} = 'Ecoflex 50 80C';
                     if ~isempty(se_eco_ss80) && n_eco_ss80 > 1 && ~all(isnan(se_eco_ss80))
                         valid_se = ~isnan(se_eco_ss80) & ~isnan(mean_eco_ss80);
                         if any(valid_se), fill(ax_ss, [x_eco_ss80(valid_se); flipud(x_eco_ss80(valid_se))], [(mean_eco_ss80(valid_se) - se_eco_ss80(valid_se)); flipud(mean_eco_ss80(valid_se) + se_eco_ss80(valid_se))], color_ecoflex, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'LineStyle', '--'); end % Note: fill linestyle ignored
                     end
                end
            end
        end
    end

    % Finalize SS Plot
    hold(ax_ss, 'off');
    if isempty(legend_handles_ss)
        fprintf('No data plotted for SS comparison: %s. Skipping plot save.\n', material_to_plot);
        close(fig_ss);
    else
        xlabel(ax_ss, 'Strain (%)'); ylabel(ax_ss, 'Stress (MPa)');
        title_material_ss = strrep(strrep(material_to_plot, '_', ' '), 'cerr ', 'Cerrolow ');
        title(ax_ss, sprintf('Stress Strain Curve %s', title_material_ss));
        grid(ax_ss, 'off'); ax_ss.GridLineStyle = ':'; ax_ss.GridAlpha = 0.7;
        legend(ax_ss, legend_handles_ss, legend_labels_ss, 'Location', 'eastoutside');
        set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
        xlim(ax_ss, [0, 8.7]); % Ensure x-axis starts at 0 after offset
        ylim(ax_ss, [0, inf]); % Ensure y-axis starts at 0 after offset
        filename_ss = fullfile(output_dir, sprintf('%s_SS_Comparison_Offset.png', material_to_plot)); % Added _Offset to name
        try print(fig_ss, filename_ss, '-dpng', '-r300'); fprintf('Saved Offset SS plot: %s\n', filename_ss);
        catch ME_save_ss, fprintf('Error saving plot %s: %s\n', filename_ss, ME_save_ss.message); end
        close(fig_ss);
    end
end
fprintf('Finished generating combined SS plots.\n');

% --- Combined TS Plots (Cerr vs Ecoflex) ---
fprintf('\nGenerating combined TS plots...\n');
for i_mat = 1:numel(cerr_materials_plot)
    material_to_plot = cerr_materials_plot{i_mat};
    material_field = matlab.lang.makeValidName(material_to_plot);

    fig_ts = figure('Visible','off'); ax_ts = axes(fig_ts); hold(ax_ts,'on');
    legend_handles_ts = []; legend_labels_ts = {}; colors_ts = [];
    if strcmp(material_to_plot, 'cerr_117'), colors_ts = colors_117;
    elseif strcmp(material_to_plot, 'cerr_158'), colors_ts = colors_158;
    else close(fig_ts); continue; end

    % Plot Cerr TS
    test_type_field_ts = matlab.lang.makeValidName('ts');
    for i_conc = 1:numel(concentrations)
        conc = concentrations{i_conc};
        conc_field = ''; % Init
        if endsWith(conc, 'v') && length(conc)>1, conc_field = matlab.lang.makeValidName(['v' conc(1:end-1)]);
        else conc_field = matlab.lang.makeValidName(conc); end

        if ~isKey(colors_ts, conc), continue; end; color = colors_ts(conc);
        if ~isfield(all_data, material_field) || ~isfield(all_data.(material_field), conc_field) ...
                || ~isfield(all_data.(material_field).(conc_field), test_type_field_ts), continue; end

        ts_list = all_data.(material_field).(conc_field).(test_type_field_ts);
        if ~isempty(ts_list) && iscell(ts_list)
            % <<< NO ZERO OFFSET FOR TS >>>
            [x_ts, mean_ts, se_ts, n_ts] = averageInterpolateDataMATLAB(ts_list, 'Temperature', 'StorageModulus', n_interp_points_plots, false);
            if ~isempty(x_ts) && ~isempty(mean_ts) && ~all(isnan(mean_ts))
                h = plot(ax_ts, x_ts, mean_ts, '-', 'Color', color, 'LineWidth', 1.5);
                legend_handles_ts(end+1) = h; legend_labels_ts{end+1} = sprintf('%s', conc);
                if ~isempty(se_ts) && n_ts > 1 && ~all(isnan(se_ts))
                    valid_se = ~isnan(se_ts) & ~isnan(mean_ts);
                    if any(valid_se), fill(ax_ts, [x_ts(valid_se); flipud(x_ts(valid_se))], [(mean_ts(valid_se) - se_ts(valid_se)); flipud(mean_ts(valid_se) + se_ts(valid_se))], color, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); end
                end
            end
        end
    end

     % Plot Ecoflex TS Control
    material_eco = 'ecoflex_50'; material_eco_field = matlab.lang.makeValidName(material_eco); conc_eco_field = 'NA';
    if isfield(all_data, material_eco_field) && isfield(all_data.(material_eco_field), conc_eco_field) ...
            && isfield(all_data.(material_eco_field).(conc_eco_field), test_type_field_ts)
        eco_ts_list = all_data.(material_eco_field).(conc_eco_field).(test_type_field_ts);
        if ~isempty(eco_ts_list) && iscell(eco_ts_list)
            % <<< NO ZERO OFFSET FOR TS >>>
            [x_eco_ts, mean_eco_ts, se_eco_ts, n_eco_ts] = averageInterpolateDataMATLAB(eco_ts_list, 'Temperature', 'StorageModulus', n_interp_points_plots, false);
            if ~isempty(x_eco_ts) && ~isempty(mean_eco_ts) && ~all(isnan(mean_eco_ts))
                h = plot(ax_ts, x_eco_ts, mean_eco_ts, '-', 'Color', color_ecoflex, 'LineWidth', 1.5);
                legend_handles_ts(end+1) = h; legend_labels_ts{end+1} = 'Ecoflex 50';
                 if ~isempty(se_eco_ts) && n_eco_ts > 1 && ~all(isnan(se_eco_ts))
                     valid_se = ~isnan(se_eco_ts) & ~isnan(mean_eco_ts);
                     if any(valid_se), fill(ax_ts, [x_eco_ts(valid_se); flipud(x_eco_ts(valid_se))], [(mean_eco_ts(valid_se) - se_eco_ts(valid_se)); flipud(mean_eco_ts(valid_se) + se_eco_ts(valid_se))], color_ecoflex, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); end
                 end
            end
        end
    end

    % Finalize TS plot
    hold(ax_ts,'off');
    if isempty(legend_handles_ts)
        fprintf('No data plotted for TS comparison: %s. Skipping plot save.\n', material_to_plot);
        close(fig_ts);
    else
        xlabel(ax_ts, 'Temperature (°C)'); ylabel(ax_ts, 'Storage Modulus (MPa)');
        title_material_ts = strrep(strrep(material_to_plot, '_', ' '), 'cerr ', 'Cerrolow ');
        title(ax_ts, sprintf('Temperature Sweep %s', title_material_ts));
        grid(ax_ts, 'off'); ax_ts.GridLineStyle = ':'; ax_ts.GridAlpha = 0.7;
        set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
        legend(ax_ts, legend_handles_ts, legend_labels_ts, 'Location', 'eastoutside');
        xlim(ax_ts, [40, 100]); % Apply 40 deg C limit
        filename_ts = fullfile(output_dir, sprintf('%s_TS_Comparison.png', material_to_plot));
        try print(fig_ts, filename_ts, '-dpng', '-r300'); fprintf('Saved TS plot: %s\n', filename_ts);
        catch ME_save_ts, fprintf('Error saving plot %s: %s\n', filename_ts, ME_save_ts.message); end
        close(fig_ts);
    end
end
fprintf('Finished generating combined TS plots.\n');


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- <<< Calculate Young's Modulus (ss0 only) - Method 2: Avg of Individual Fits >>> ---
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\nCalculating Young''s Modulus from individual ss0 fits...\n');
fprintf('NOTE: Modulus calculation uses ORIGINAL (non-offset) ss0 data.\n'); % Clarification

% --- Initialize storage for BOTH summary (mean/sem) and individual results ---
modulus_results_list = {}; % For Mean/SEM summary per group
individual_modulus_data = {}; % For individual sample results

all_materials_for_modulus = {materials{:}}; % Include all defined materials

for i_mat_mod = 1:numel(all_materials_for_modulus)
    mat_mod = all_materials_for_modulus{i_mat_mod};
    mat_mod_field = matlab.lang.makeValidName(mat_mod);

    current_concentrations = {};
    if startsWith(mat_mod, 'cerr')
        current_concentrations = concentrations; % {'10v', '20v', ...}
    elseif strcmp(mat_mod, 'ecoflex_50')
        current_concentrations = {'N/A'}; % Special case for ecoflex
    else
        continue; % Skip if material type isn't recognized for modulus calc
    end

    for i_conc_mod = 1:numel(current_concentrations)
        conc_mod = current_concentrations{i_conc_mod}; % Original name ('10v' or 'N/A')

        % Get sanitized concentration field name for accessing data
        conc_mod_field = '';
        if strcmp(conc_mod, 'N/A')
            conc_mod_field = 'NA';
        elseif endsWith(conc_mod, 'v') && length(conc_mod) > 1
            conc_mod_field = matlab.lang.makeValidName(['v' conc_mod(1:end-1)]);
        else
            conc_mod_field = matlab.lang.makeValidName(conc_mod);
            warning('Modulus Calc: Unexpected concentration format %s for %s', conc_mod, mat_mod);
        end

        % Check if data exists
         if ~isfield(all_data, mat_mod_field) || ~isfield(all_data.(mat_mod_field), conc_mod_field)
             fprintf('  Skipping %s %s: No data structure field found.\n', mat_mod, conc_mod);
            continue;
         end

        % Get ss0 data list specifically
        test_type_field_ss0 = matlab.lang.makeValidName('ss0');
         if ~isfield(all_data.(mat_mod_field).(conc_mod_field), test_type_field_ss0)
             fprintf('  Skipping %s %s: No ss0 test type field found.\n', mat_mod, conc_mod);
             continue; % Skip if no ss0 data for this group
         end
         ss0_list = all_data.(mat_mod_field).(conc_mod_field).(test_type_field_ss0);

         if isempty(ss0_list) || ~iscell(ss0_list) % Check if cell array
             fprintf('  Skipping %s %s: ss0 data list is empty or not a cell array.\n', mat_mod, conc_mod);
             continue;
         end

         % --- Calculate Modulus for Each Sample ---
         individual_moduli_temp = NaN(1, numel(ss0_list)); % Temp storage for mean/SEM calculation

         for i_sample = 1:numel(ss0_list)
             sample_data = ss0_list{i_sample};
             if ~isstruct(sample_data) || ~isfield(sample_data, 'Strain') || ~isfield(sample_data, 'Stress') || ~isfield(sample_data, 'sample') % Check if struct
                 warning('Modulus Calc [%s %s Sample index %d]: Invalid sample data or Missing Strain, Stress, or SampleID. Skipping sample.', mat_mod, conc_mod, i_sample);
                 continue;
             end

             current_sample_id = sample_data.sample; % Get sample ID (e.g., 's1')

             % --- IMPORTANT: Use ORIGINAL Strain and Stress for Modulus ---
             x_raw_percent = sample_data.Strain;
             y_raw_MPa = sample_data.Stress;

             % Basic data cleaning for this sample
             is_valid_data = isfinite(x_raw_percent) & isfinite(y_raw_MPa);
             x_perc = x_raw_percent(is_valid_data);
             y_MPa = y_raw_MPa(is_valid_data);

             if numel(x_perc) < YOUNG_MOD_MIN_POINTS_FOR_FIT % Check overall points before selecting range
                 warning('Modulus Calc [%s %s Sample %s]: Too few valid data points (%d < %d). Skipping sample.', ...
                         mat_mod, conc_mod, current_sample_id, numel(x_perc), YOUNG_MOD_MIN_POINTS_FOR_FIT);
                 continue;
             end

             % --- Find the actual index of the point closest to 0% strain for the FIT START ---
             % We still need to define the fit range, but the *absolute* values are used.
             % Let's fit from the start of the available data up to the limit.
             fit_indices = (x_perc <= YOUNG_MOD_STRAIN_LIMIT_PERCENT);
             % Ensure we are not fitting below the first recorded point if it's > 0
             min_recorded_strain = min(x_perc);
             if min_recorded_strain > 0
                 fit_indices = fit_indices & (x_perc >= min_recorded_strain);
             end

             x_fit_percent = x_perc(fit_indices);
             y_fit_MPa = y_MPa(fit_indices);

             % Perform the fit if enough points in the range
             if sum(fit_indices) >= YOUNG_MOD_MIN_POINTS_FOR_FIT
                 x_fit_unitless = x_fit_percent / 100.0;
                 try
                     tbl = table(x_fit_unitless, y_fit_MPa, 'VariableNames', {'Strain_unitless', 'Stress_MPa'});
                     % Fit intercept+slope (Original)
                     % Using the non-offset data means the intercept might not be zero.
                     % The slope (Young's Modulus) is the primary interest.
                     mdl = fitlm(tbl, 'Stress_MPa ~ Strain_unitless');

                     if mdl.NumCoefficients == 2 % Standard fit with intercept
                         E_sample = mdl.Coefficients.Estimate(2); % Slope for THIS sample
                         R2_sample = mdl.Rsquared.Ordinary;
                     else
                         warning('Modulus Calc [%s %s Sample %s]: Unexpected number of coefficients in fitlm model.',...
                                 mat_mod, conc_mod, current_sample_id);
                         E_sample = NaN; R2_sample = NaN;
                     end


                     if ~isnan(E_sample) && R2_sample >= YOUNG_MOD_MIN_R_SQUARED
                         % Store for Mean/SEM calculation
                         individual_moduli_temp(i_sample) = E_sample;

                         % --- Store individual result for separate CSV output ---
                         individual_modulus_data{end+1} = struct(...
                             'Material', mat_mod, ...
                             'Concentration', conc_mod, ...
                             'SampleID', current_sample_id, ...
                             'Individual_YoungModulus_MPa', E_sample, ...
                             'R_Squared', R2_sample);
                         % --- End storing individual result ---

                     else % Fit was successful but R2 too low, or E_sample was NaN
                         if isnan(E_sample)
                              warning('Modulus Calc [%s %s Sample %s]: Fit resulted in NaN modulus value. Ignoring sample.', ...
                                 mat_mod, conc_mod, current_sample_id);
                         else
                              warning('Modulus Calc [%s %s Sample %s]: Fit R2 (%.4f) < %.2f. Ignoring sample modulus.', ...
                                     mat_mod, conc_mod, current_sample_id, R2_sample, YOUNG_MOD_MIN_R_SQUARED);
                         end
                         % Keep individual_moduli_temp(i_sample) as NaN
                     end
                 catch ME_fit
                     warning('Modulus Calc [%s %s Sample %s]: Linear fit failed: %s. Ignoring sample modulus.', ...
                             mat_mod, conc_mod, current_sample_id, ME_fit.message);
                     % Keep individual_moduli_temp(i_sample) as NaN
                 end
             else % Too few points in the specific fit range
                 warning('Modulus Calc [%s %s Sample %s]: Too few points (%d < %d) in fit range [start, %.1f%%]. Ignoring sample modulus.', ...
                         mat_mod, conc_mod, current_sample_id, sum(fit_indices), YOUNG_MOD_MIN_POINTS_FOR_FIT, YOUNG_MOD_STRAIN_LIMIT_PERCENT);
                 % Keep individual_moduli_temp(i_sample) as NaN
             end
         end % End loop through individual samples

         % --- Calculate Mean and SEM from valid individual moduli (for summary table) ---
         valid_moduli_group = individual_moduli_temp(~isnan(individual_moduli_temp));
         n_valid_samples_group = numel(valid_moduli_group);
         E_Mean_MPa = NaN;
         E_SEM_MPa = NaN;

         if n_valid_samples_group > 0
             E_Mean_MPa = mean(valid_moduli_group);
             if n_valid_samples_group > 1
                 E_SEM_MPa = std(valid_moduli_group) / sqrt(n_valid_samples_group);
             else
                 E_SEM_MPa = NaN; % SEM not defined for n=1
             end
             fprintf('  Modulus Summary [%s %s]: Mean E = %.3f +/- %.3f MPa (SEM, N_valid=%d from %d total files)\n', ...
                     mat_mod, conc_mod, E_Mean_MPa, E_SEM_MPa, n_valid_samples_group, numel(ss0_list));
         else
             warning('  Modulus Summary [%s %s]: No valid individual moduli calculated from %d files. Results set to NaN.', ...
                     mat_mod, conc_mod, numel(ss0_list));
         end

         % --- Store results for SUMMARY table (Mean E and SEM) ---
         modulus_results_list{end+1} = struct(...
             'Material', mat_mod, ...
             'Concentration', conc_mod, ...
             'YoungModulus_MPa', E_Mean_MPa, ...
             'YoungModulus_SE', E_SEM_MPa, ...
             'N_Samples', n_valid_samples_group); % N used in MEAN/SEM

    end % End loop concentrations
end % End loop materials

fprintf('Finished calculating Young''s Modulus values.\n');


% --- Save Individual Sample Modulus Data ---
fprintf('\nSaving individual sample Young''s Modulus data...\n');
individual_results_filename = fullfile(output_dir, 'ss0_individual_modulus_data.csv'); % New filename

if ~isempty(individual_modulus_data)
    try
        individual_table = struct2table([individual_modulus_data{:}], 'AsArray', true);

        % Optional: Sort individual results if desired
        % Convert Concentration to numeric for sorting
        conc_numeric_indiv = NaN(height(individual_table), 1);
        for i = 1:height(individual_table)
             % Check if Concentration is cell, if so, access element
             conc_val = individual_table.Concentration(i);
             if iscell(conc_val), conc_str = conc_val{1}; else, conc_str = conc_val; end % Handle potential cell

            if endsWith(conc_str, 'v') && ~strcmp(conc_str, 'N/A')
                num_part = str2double(conc_str(1:end-1));
                if ~isnan(num_part), conc_numeric_indiv(i) = num_part; end
            elseif strcmp(conc_str, 'N/A'), conc_numeric_indiv(i) = Inf; end % Sort N/A last
        end
        individual_table.ConcNumericSort = conc_numeric_indiv;
        individual_table = sortrows(individual_table, {'Material', 'ConcNumericSort', 'SampleID'});
        individual_table.ConcNumericSort = []; % Remove helper column

        writetable(individual_table, individual_results_filename);
        fprintf('Saved individual sample modulus data (%d rows) to: %s\n', height(individual_table), individual_results_filename);
        disp('Individual Modulus Data Snippet:');
        disp(head(individual_table)); % Display first few rows
    catch ME_save_individual
        warning('Error saving individual sample modulus data table: %s', ME_save_individual.message);
    end
else
    fprintf('No valid individual sample modulus data was generated to save.\n');
end
% --- End Save Individual Sample Modulus Data ---


% --- Process and Save Modulus Results Table ---
fprintf('\nProcessing and saving Young''s Modulus results table...\n');
results_table = []; % Initialize empty

if ~isempty(modulus_results_list)
    try
        results_table = struct2table([modulus_results_list{:}], 'AsArray', true);
        % Select and Reorder columns
        cols_to_keep = {'Material', 'Concentration', 'YoungModulus_MPa', 'YoungModulus_SE', 'N_Samples'};
        cols_exist = ismember(cols_to_keep, results_table.Properties.VariableNames);
        results_table = results_table(:, cols_to_keep(cols_exist));

        % Sort table
        conc_numeric = NaN(height(results_table), 1);
        for i = 1:height(results_table)
             % Check if Concentration is cell, if so, access element
             conc_val = results_table.Concentration(i);
             if iscell(conc_val), conc_str = conc_val{1}; else, conc_str = conc_val; end % Handle potential cell

            if endsWith(conc_str, 'v') && ~strcmp(conc_str, 'N/A')
                num_part = str2double(conc_str(1:end-1));
                if ~isnan(num_part), conc_numeric(i) = num_part; end
            elseif strcmp(conc_str, 'N/A'), conc_numeric(i) = Inf; end % Sort N/A last
        end
        results_table.ConcNumericSort = conc_numeric;
        results_table = sortrows(results_table, {'Material', 'ConcNumericSort'});
        results_table.ConcNumericSort = []; % Remove helper column

        % Save to CSV
        modulus_results_filename = fullfile(output_dir, 'ss0_young_modulus_results.csv');
        writetable(results_table, modulus_results_filename);
        fprintf('Saved Young''s Modulus results to: %s\n', modulus_results_filename);

        disp('Young''s Modulus Results (ss0):');
        disp(results_table);

    catch ME_table
        warning('Error processing or saving Young''s Modulus results table: %s', ME_table.message);
        results_table = [];
    end
else
    warning('No Young''s Modulus results were calculated to save.');
end


% --- Generate Young's Modulus Bar Charts ---
fprintf('\nGenerating Young''s Modulus bar charts (ss0 only)...\n');
if ~isempty(results_table) && height(results_table) > 0
    % Extract Ecoflex data
    eco_row = results_table(strcmp(results_table.Material, 'ecoflex_50'), :);
    eco_modulus = NaN; eco_se = NaN;
    if height(eco_row) >= 1
        if height(eco_row) > 1, warning('Multiple Ecoflex results found, using first one.'); end
        eco_modulus = eco_row.YoungModulus_MPa(1);
        eco_se = eco_row.YoungModulus_SE(1);
        if isnan(eco_modulus), eco_se = 0; elseif isnan(eco_se), eco_se = 0; end % Handle NaN for errorbar
    else
        warning('No Ecoflex modulus result found for bar chart comparison.');
    end

    % Loop through Cerro materials
    for i_mat_bar = 1:numel(cerr_materials_plot) % Use cerr_materials_plot = {'cerr_117', 'cerr_158'}
        mat_bar = cerr_materials_plot{i_mat_bar};
        mat_bar_disp = strrep(strrep(mat_bar, '_', ' '), 'cerr ', 'Cerrolow ');

        mat_results = results_table(strcmp(results_table.Material, mat_bar), :);
        if height(mat_results) == 0, fprintf('  Skipping bar chart for %s: No modulus results.\n', mat_bar); continue; end

        % Prepare data
        concentrations_plot = mat_results.Concentration;
        moduli_plot = mat_results.YoungModulus_MPa; % Use original values (with potential NaNs) for bar heights
        se_plot = mat_results.YoungModulus_SE;

        % Prepare versions for plotting (NaN -> 0 for bar height, 0 for SE if Mod or SE is NaN)
        moduli_plot_disp = moduli_plot;
        moduli_plot_disp(isnan(moduli_plot_disp)) = 0; % Plot NaN as zero height
        se_plot_disp = se_plot;
        se_plot_disp(isnan(se_plot)) = 0; % No error bar if SE is NaN
        se_plot_disp(isnan(moduli_plot)) = 0; % Also no error bar if modulus itself is NaN

        % Get colors
        colors_bar_map = [];
        if strcmp(mat_bar, 'cerr_117'), colors_bar_map = colors_117;
        elseif strcmp(mat_bar, 'cerr_158'), colors_bar_map = colors_158;
        else continue; end

        bar_colors_cell = cell(height(mat_results), 1); % Column cell array
        for k=1:height(mat_results)
             % Check if Concentration is cell, if so, access element
             conc_val = concentrations_plot(k);
             if iscell(conc_val), conc_str_bar = conc_val{1}; else, conc_str_bar = conc_val; end

             if isKey(colors_bar_map, conc_str_bar)
                 bar_colors_cell{k} = colors_bar_map(conc_str_bar);
             else
                 bar_colors_cell{k} = [0.5 0.5 0.5]; % Default grey
             end
        end

        % Include Ecoflex data
        plot_labels = ['Ecoflex 50'; concentrations_plot]; % Should handle cell/non-cell display
        plot_moduli_for_bar = [eco_modulus; moduli_plot]; % Use original moduli (with NaNs) for errorbar y position
        plot_se_for_bar = [eco_se; se_plot_disp]; % Use version with NaNs->0 for error bar size
        plot_colors = [{color_ecoflex}; bar_colors_cell]; % Correct concatenation
        
        % Create figure
        fig_bar = figure('Visible', 'off'); ax_bar = axes(fig_bar); hold(ax_bar, 'on');

        % Plot bars individually using display heights (NaN->0)
        num_bars = numel(plot_labels);
        x_coords = 1:num_bars;
        for b = 1:num_bars
            current_mod_disp = plot_moduli_for_bar(b); % Get original modulus (can be NaN)
            if isnan(current_mod_disp)
                current_mod_disp = 0; % Set display height to 0 if NaN
            end
            bar(ax_bar, x_coords(b), current_mod_disp, 'FaceColor', plot_colors{b});
        end

        % Add error bars using original modulus values for position
        errorbar(ax_bar, x_coords, plot_moduli_for_bar, plot_se_for_bar, ...
                 'k.', 'LineWidth', 1, 'CapSize', 6, 'LineStyle', 'none');

        hold(ax_bar, 'off');

        % Customize plot
        ylabel(ax_bar, 'Young''s Modulus (MPa)');
        title(ax_bar, sprintf('Room Temperature Young''s Modulus', mat_bar_disp));
        xticks(ax_bar, x_coords);
        xticklabels(ax_bar, plot_labels); % MATLAB should handle cell array labels correctly
        xtickangle(ax_bar, 30);
        set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
        grid(ax_bar, 'off'); ax_bar.YGrid = 'off'; ax_bar.XGrid = 'off';
        ax_bar.GridLineStyle = ':'; ax_bar.YMinorGrid = 'off';
        % Adjust Y limits, handle case where all might be NaN/zero
        max_y_val = max(plot_moduli_for_bar + plot_se_for_bar); % Use original values for limit calc
        if isempty(max_y_val) || isnan(max_y_val) || max_y_val <= 0, max_y_val = 1; end % Default limit if no data
        ylim(ax_bar, [0, max_y_val * 1.15]);

        % Save plot
        bar_filename = fullfile(output_dir, sprintf('%s_ss0_Modulus_BarChart.png', mat_bar)); % Added ss0 to filename
        try
            print(fig_bar, bar_filename, '-dpng', '-r200');
            fprintf('  Saved ss0 bar chart: %s\n', bar_filename);
        catch ME_save_bar
            fprintf('  Error saving ss0 bar chart %s: %s\n', bar_filename, ME_save_bar.message);
        end
        close(fig_bar);
    end
else
    fprintf('Skipping ss0 bar chart generation: No valid modulus results table available.\n');
end


fprintf('\n--- MATLAB processing complete ---\n');


% #########################################################################
% ###################### HELPER FUNCTIONS BELOW ###########################
% #########################################################################

% --- Helper Function: Parse Filename ---
function [material, concentration, file_test_type, sample] = parseFilenameMATLAB(filename)
    material = []; concentration = []; file_test_type = []; sample = []; % Default return
    try
        [~, base_name, ~] = fileparts(filename); % Removes extension
        parts = strsplit(base_name, '_');
        if isempty(parts) || isempty(parts{1}), error('Filename empty or invalid'); end

        if startsWith(parts{1}, 'cerr') && numel(parts) >= 5
            material = strjoin({parts{1}, parts{2}}, '_'); % cerr_117 or cerr_158
            concentration = parts{3}; % e.g., 10v
            file_test_type = parts{4}; % e.g., ss0
            sample_part = parts{5}; % e.g., s1
            if ~startsWith(material, 'cerr_117') && ~startsWith(material, 'cerr_158')
                 error('Invalid material prefix: %s', material);
            end
            if ~endsWith(concentration, 'v')
                 warning('Concentration "%s" in filename "%s" does not end with "v".', concentration, filename);
            end
             if ~startsWith(sample_part, 's') || isnan(str2double(sample_part(2:end))) % check format s<number>
                 warning('Invalid sample format: "%s" in filename "%s". Expected "s" followed by a number.', sample_part, filename);
                 sample_part = 'sNaN'; % Assign a default invalid sample
             end
            sample = sample_part;
        elseif startsWith(parts{1}, 'ecoflex') && numel(parts) >= 4
            material = strjoin({parts{1}, parts{2}}, '_'); % ecoflex_50
            concentration = 'N/A'; % Assign N/A for ecoflex
            file_test_type = parts{3}; % e.g., ss0
            sample_part = parts{4}; % e.g., s1
            if ~strcmp(material, 'ecoflex_50')
                 error('Invalid material prefix: %s', material);
            end
            if ~startsWith(sample_part, 's') || isnan(str2double(sample_part(2:end))) % check format s<number>
                 warning('Invalid sample format: "%s" in filename "%s". Expected "s" followed by a number.', sample_part, filename);
                 sample_part = 'sNaN'; % Assign a default invalid sample
            end
            sample = sample_part;
        else
            error('Filename structure not recognized: %s', base_name);
        end

    catch ME
        warning('Could not parse filename: %s. Error: %s. Skipping.', filename, ME.message);
        material = []; concentration = []; file_test_type = []; sample = [];
    end
end

% --- Helper Function: Read Data File ---
function [data, header_info] = readDataFileMATLAB(filepath, col_map)
    data = []; header_info = {}; % Initialize outputs
    fid = -1; % File ID
    encodings_to_try = {'UTF-16LE', 'UTF-8', 'Windows-1252'};
    success = false;

    for i_enc = 1:numel(encodings_to_try)
        current_encoding = encodings_to_try{i_enc};
        try
            fid = fopen(filepath, 'rt', 'n', current_encoding);
            if fid == -1, continue; end

            header_info_temp = {}; data_lines_temp = {}; in_data_section = false; line_num = 0;

            while ~feof(fid)
                line = fgetl(fid); line_num = line_num + 1;
                if line == -1, break; end
                stripped_line = strtrim(line);

                if ~in_data_section
                    header_info_temp{end+1, 1} = stripped_line;
                    % Case-insensitive check for StartOfData
                    if strcmpi(stripped_line, 'StartOfData'), in_data_section = true; end
                elseif ~isempty(stripped_line) && ~startsWith(stripped_line, '#') % Added check for # comment lines
                    try
                        % Split by whitespace (tab or space)
                        num_vals = str2double(regexp(stripped_line, '\s+', 'split'));
                        if all(isnan(num_vals)) && ~isempty(stripped_line)
                             error('Row conversion resulted entirely in NaN.');
                        end
                        data_lines_temp{end+1, 1} = num_vals;
                    catch ME_convert
                         warning('Skipping row %d in %s: Conversion error: %s. Line content: "%s"', line_num, filepath, ME_convert.message, stripped_line);
                         continue;
                    end
                end
            end
            fclose(fid); fid = -1;

            if ~in_data_section, warning('''StartOfData'' not found in %s (%s). Attempting to read all numeric lines.', filepath, current_encoding);
                 % Fallback: Try reading all lines again as data if StartOfData missing
                 fid = fopen(filepath, 'rt', 'n', current_encoding); if fid == -1, continue; end
                 data_lines_temp = {}; line_num = 0;
                 while ~feof(fid)
                     line = fgetl(fid); line_num = line_num + 1; if line == -1, break; end
                     stripped_line = strtrim(line);
                     if ~isempty(stripped_line) && ~startsWith(stripped_line, '#')
                         try num_vals = str2double(regexp(stripped_line, '\s+', 'split'));
                             if ~all(isnan(num_vals)), data_lines_temp{end+1, 1} = num_vals; end % Only add if *not* all NaN
                         catch, continue; end % Ignore conversion errors in this fallback
                     end
                 end
                 fclose(fid); fid = -1;
                 if isempty(data_lines_temp), warning('No numeric data found in fallback read of %s.', filepath); continue; end
            end

            if isempty(data_lines_temp), warning('No valid data rows found in %s (%s).', filepath, current_encoding); continue; end

            % Check for consistent number of columns before vertcat
            num_cols = cellfun(@numel, data_lines_temp);
            if isempty(num_cols), warning('Cannot determine column count in %s.', filepath); continue; end
            first_num_cols = num_cols(1);
            if ~all(num_cols == first_num_cols)
                 inconsistent_indices = find(num_cols ~= first_num_cols);
                 warning('Inconsistent column count in %s. Expected %d, found %d columns at line indices (approx): %s. Skipping file.', ...
                         filepath, first_num_cols, num_cols(inconsistent_indices(1)), num2str(inconsistent_indices(:)')); % Report inconsistent counts/lines
                 continue; % Skip this file due to inconsistency
            end

            try data = vertcat(data_lines_temp{:});
            catch ME_vertcat, warning('Matrix conversion error in %s: %s.', filepath, ME_vertcat.message); data = []; continue; end

            max_col_needed = 0; fields = fieldnames(col_map);
            for k=1:length(fields), max_col_needed = max(max_col_needed, col_map.(fields{k})); end

            if size(data, 2) < max_col_needed
                warning('Insufficient columns (%d < %d) in %s.', size(data, 2), max_col_needed, filepath); data = []; continue;
            end

            header_info = header_info_temp; success = true;
            break; % Exit encoding loop

        catch ME_read
            if fid ~= -1, fclose(fid); fid = -1; end
            warning('Error processing %s (%s): %s.', filepath, current_encoding, ME_read.message);
            data = []; header_info = {};
        end
    end % End encoding loop

    if ~success
         warning('Failed to read %s with all attempted encodings.', filepath);
         data = []; header_info = {};
    end
end


% --- Helper Function: Average and Interpolate Data ---
% <<< MODIFIED FUNCTION >>>
function [x_common, y_mean, y_se, n_samples_valid] = averageInterpolateDataMATLAB(data_list, x_col_name, y_col_name, n_points, apply_zero_offset)
    % Added 'apply_zero_offset' flag (boolean)
    % If true AND columns are Strain/Stress, shift each sample curve to start at (0,0) before averaging.

    x_common = []; y_mean = []; y_se = []; n_samples_valid = 0; % Defaults
    valid_samples_data = {}; all_x_mins = []; all_x_maxs = [];
    n_samples_in_list = numel(data_list);

    % Default value for apply_zero_offset if not provided
    if nargin < 5
        apply_zero_offset = false;
    end

    for i_sample = 1:n_samples_in_list
        sample_data = data_list{i_sample};
        % Add check for struct type
        if ~isstruct(sample_data) || ~isfield(sample_data, x_col_name) || ~isfield(sample_data, y_col_name)
             continue;
        end
        x_raw = sample_data.(x_col_name)(:); y_raw = sample_data.(y_col_name)(:);
        is_finite = isfinite(x_raw) & isfinite(y_raw);
        x = x_raw(is_finite); y = y_raw(is_finite);
        if numel(x) < 2, continue; end % Need at least 2 points

        % Sort by x and handle duplicates
        [x_sorted, sort_idx] = sort(x); y_sorted = y(sort_idx);
        [x_unique, unique_first_idx, ic] = unique(x_sorted, 'stable');
        % Average y for duplicate x values
        y_unique_avg = accumarray(ic, y_sorted, [], @mean);

        if numel(x_unique) < 2, continue; end % Need at least 2 unique x points

        % --- Apply (0,0) Offset if requested for Strain/Stress ---
        x_to_use = x_unique; % Default
        y_to_use = y_unique_avg; % Default

        if apply_zero_offset && strcmp(x_col_name, 'Strain') && strcmp(y_col_name, 'Stress')
            x_offset = x_unique(1);
            y_offset = y_unique_avg(1);
            x_to_use = x_unique - x_offset;
            y_to_use = y_unique_avg - y_offset;
            % Optional sanity check for offset
            % if abs(x_to_use(1)) > 1e-9 || abs(y_to_use(1)) > 1e-9
            %      warning('AverageInterp: Offset check failed for sample %d. First point: (%.2e, %.2e)', i_sample, x_to_use(1), y_to_use(1));
            % end
        end
        % --- End Offset ---

        % Store the (potentially shifted) data for interpolation
        valid_samples_data{end+1} = {x_to_use, y_to_use};
        all_x_mins(end+1) = x_to_use(1); % Use the first point of the (potentially shifted) data
        all_x_maxs(end+1) = x_to_use(end); % Use the last point
    end

    n_samples_valid = numel(valid_samples_data);
    if n_samples_valid == 0, return; end
    if isempty(all_x_mins) || isempty(all_x_maxs)
       warning('AverageInterp: Min/Max X range calculation failed.'); return;
    end

    % Determine common range based on the (potentially shifted) data
    common_x_min = max(all_x_mins);
    common_x_max = min(all_x_maxs);

    % Ensure valid range (needs at least a small positive width)
    if common_x_min >= common_x_max || (common_x_max - common_x_min) < 1e-9
        warning('AverageInterp: No valid common X-range found after processing %d samples for %s vs %s. Min/Max values: [%s], [%s]', ...
            n_samples_valid, x_col_name, y_col_name, num2str(all_x_mins), num2str(all_x_maxs));
        return;
    end

    x_common = linspace(common_x_min, common_x_max, n_points)';
    y_interp_all = NaN(n_points, n_samples_valid);

    for i = 1:n_samples_valid
        sample_xy = valid_samples_data{i};
        x_sample = sample_xy{1}; y_sample = sample_xy{2}; % These are the (potentially shifted) data
        try
            % Use interp1 - it handles non-monotonicity if it arises, but data should be sorted.
            % 'extrap' is needed if x_common goes slightly outside a sample's range due to linspace precision
            % NaN padding is safer to avoid extrapolation errors.
            y_interp_all(:, i) = interp1(x_sample, y_sample, x_common, 'linear', NaN);
        catch ME_interp
            warning('AverageInterp: Interpolation error sample %d (%s vs %s): %s', i, x_col_name, y_col_name, ME_interp.message);
            % Keep column as NaN
        end
    end

    % Calculate mean and SEM, ignoring NaNs from interpolation mismatches
    y_mean = nanmean(y_interp_all, 2);
    y_std = nanstd(y_interp_all, 0, 2);
    non_nan_counts = sum(~isnan(y_interp_all), 2);
    y_se = NaN(size(y_std));
    valid_se_indices = (non_nan_counts >= 2); % Need at least 2 samples for SEM
    if any(valid_se_indices)
        y_se(valid_se_indices) = y_std(valid_se_indices) ./ sqrt(non_nan_counts(valid_se_indices));
    end

    % Check if the result is usable
    if all(isnan(y_mean))
        warning('AverageInterp: Mean Y result is all NaN for %s vs %s.', x_col_name, y_col_name);
        x_common = []; y_mean = []; y_se = [];
    end
end % End of averageInterpolateDataMATLAB