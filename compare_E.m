clear; clc; close all;


%AspectRatio (AR)

%Guth Model
l = 0.8508;
d = 0.2;
FM_AR = l/d; 
E50 = 82000; %Pa
% 
Vf_1 = 0.1;
E_guth_FM10 =  E50*(1+(0.67*FM_AR*Vf_1)+(1.62*FM_AR*FM_AR*Vf_1*Vf_1));

Vf_1 = 0.2;
E_guth_FM20 =  E50*(1+(0.67*FM_AR*Vf_1)+(1.62*FM_AR*FM_AR*Vf_1*Vf_1));

Vf_2 = 0.3;
E_guth_FM30 =  E50*(1+(0.67*FM_AR*Vf_2)+(1.62*FM_AR*FM_AR*Vf_2*Vf_2));

Vf_3 = 0.4;
E_guth_FM40 =  E50*(1+(0.67*FM_AR*Vf_3)+(1.62*FM_AR*FM_AR*Vf_3*Vf_3));

Vf_1 = 0.5;
E_guth_FM50 =  E50*(1+(0.67*FM_AR*Vf_1)+(1.62*FM_AR*FM_AR*Vf_1*Vf_1));


%Tsai Model
EFM = 9250000000;
sigma = (2*l)/d;

nL = ((EFM/E50)-1)/((EFM/E50)+sigma);

nT = ((EFM/E50)-1)/((EFM/E50)+2);

Vf= 0.1;
E_tsai_L = (3/8)*((1+(sigma*nL*Vf))/(1-nL*Vf));
E_tsai_R = (5/8)*((1+(2*nT*Vf))/(1-nT*Vf));
E_tsai_FM10 = E50*(E_tsai_L+E_tsai_R);


Vf= 0.2;
E_tsai_L = (3/8)*((1+(sigma*nL*Vf))/(1-nL*Vf));
E_tsai_R = (5/8)*((1+(2*nT*Vf))/(1-nT*Vf));
E_tsai_FM20 = E50*(E_tsai_L+E_tsai_R);

Vf= 0.3;
E_tsai_L = (3/8)*((1+(sigma*nL*Vf))/(1-nL*Vf));
E_tsai_R = (5/8)*((1+(2*nT*Vf))/(1-nT*Vf));
E_tsai_FM30 = E50*(E_tsai_L+E_tsai_R);

Vf= 0.4;
E_tsai_L = (3/8)*((1+(sigma*nL*Vf))/(1-nL*Vf));
E_tsai_R = (5/8)*((1+(2*nT*Vf))/(1-nT*Vf));
E_tsai_FM40 = E50*(E_tsai_L+E_tsai_R);

Vf= 0.5;
E_tsai_L = (3/8)*((1+(sigma*nL*Vf))/(1-nL*Vf));
E_tsai_R = (5/8)*((1+(2*nT*Vf))/(1-nT*Vf));
E_tsai_FM50 = E50*(E_tsai_L+E_tsai_R);



% --- Configuration ---
fmFile = 'output_matlab/fm_dma.csv'; % UPDATED PATH
ss0File = 'output_matlab/ss0_young_modulus_results.csv'; % UPDATED PATH
outputFileName = 'Combined_Material_Modulus_Comparison.png'; % Optional: Save plot

% Define colors
colorEcoflex = [0.4 0.4 0.4];      
colorCerr117 = [0 0 1];       
colorCerr158 = [1 0 0];      
colorFM = [0 0.7 0];      
colorGuth = [0 0 0];
colorTsai = [0.5 0.5 0.5];

% --- Load Data ---
try
    opts = detectImportOptions(fmFile);
    opts = setvartype(opts, 'Concentration', 'string'); % Read conc as string first
    dataFM = readtable(fmFile, opts);

    opts = detectImportOptions(ss0File);
    opts = setvartype(opts, 'Concentration', 'string'); % Read conc as string first
    dataSS0 = readtable(ss0File, opts);

    % Combine tables
    allData = [dataFM; dataSS0];
catch ME
    error('Failed to read CSV files. Ensure "%s" and "%s" exist at the specified paths.\nError: %s', ...
        fmFile, ss0File, ME.message);
end

% --- Preprocessing ---

% Standardize Material Names (case-insensitive search, then assign standard name)
allData.Material = categorical(allData.Material); % Convert to categorical for easier handling
materialNames = categories(allData.Material);
for i = 1:length(materialNames)
    if strcmpi(materialNames{i}, 'fm')
        allData.Material(allData.Material == materialNames{i}) = 'FM';
    elseif strcmpi(materialNames{i}, 'cerr_117')
        allData.Material(allData.Material == materialNames{i}) = 'Cerr 117';
    elseif strcmpi(materialNames{i}, 'cerr_158')
        allData.Material(allData.Material == materialNames{i}) = 'Cerr 158';
    elseif contains(materialNames{i}, 'ecoflex', 'IgnoreCase', true) % Handle variations
         allData.Material(allData.Material == materialNames{i}) = 'Ecoflex 50';
    end
end
allData.Material = removecats(allData.Material); % Clean up unused categories

% Handle Ecoflex 50 averaging
ecoRows = find(allData.Material == 'Ecoflex 50');
if length(ecoRows) > 1
    fprintf('Found %d Ecoflex 50 entries. Averaging...\n', length(ecoRows));
    ecoData = allData(ecoRows,:);

    % Weighted average for Mean YM
    totalN = sum(ecoData.N_Samples);
    pooledYM = sum(ecoData.YoungModulus_MPa .* ecoData.N_Samples) / totalN;

    % Pooled Standard Error calculation
    sumSqErrWeighted = 0;
    sumDF = 0;
    validGroups = 0;
    for k = 1:height(ecoData)
        N_k = ecoData.N_Samples(k);
        SE_k = ecoData.YoungModulus_SE(k);
        if N_k > 1
           s_k_sq = (SE_k^2) * N_k; % Sample variance estimate
           sumSqErrWeighted = sumSqErrWeighted + (N_k - 1) * s_k_sq;
           sumDF = sumDF + (N_k - 1);
           validGroups = validGroups + 1;
        elseif N_k == 1
            warning('Sample size N=1 found for Ecoflex 50. Standard error pooling might be less accurate.');
        end
    end

    if sumDF > 0 % Only if we have degrees of freedom > 0
        pooledVar = sumSqErrWeighted / sumDF;
        pooledSE = sqrt(pooledVar / totalN);
        fprintf(' Pooled Ecoflex 50: YM = %.4f MPa, SE = %.4f, Total N = %d\n', pooledYM, pooledSE, totalN);
    elseif any(ecoData.N_Samples == 1) && all(ecoData.N_Samples == 1)
        warning('All Ecoflex 50 samples have N=1. Cannot calculate pooled SE reliably. Using average SE as estimate.');
        pooledSE = mean(ecoData.YoungModulus_SE, 'omitnan'); % Use average SE as a fallback estimate
         fprintf(' Pooled Ecoflex 50: YM = %.4f MPa, SE = %.4f (Avg), Total N = %d\n', pooledYM, pooledSE, totalN);
    else % Only one row to begin with or unexpected case
         if ~isempty(ecoData)
             pooledSE = ecoData.YoungModulus_SE(1); % Take SE from the first (only) row
             fprintf(' Pooled Ecoflex 50: YM = %.4f MPa, SE = %.4f, Total N = %d\n', pooledYM, pooledSE, totalN);
         else
             pooledSE = NaN; % Should not happen if length(ecoRows)>1 but defensive coding
             warning('Inconsistent state during Ecoflex pooling.');
         end
    end

    % Create the new combined row
    newEcoRow = table({'Ecoflex 50'}, {"0"}, pooledYM, pooledSE, totalN, ... % Assign concentration 0
        'VariableNames', {'Material', 'Concentration', 'YoungModulus_MPa', 'YoungModulus_SE', 'N_Samples'});
    newEcoRow.Material = categorical(newEcoRow.Material); % Ensure type consistency

    % Remove old Ecoflex rows and add the new one
    allData(ecoRows,:) = [];
    allData = [allData; newEcoRow];
else
    fprintf('Found %d Ecoflex 50 entry/entries. Not pooling or already pooled.\n', length(ecoRows));
    % If one entry exists, make sure its concentration is 0
    ecoRows = find(allData.Material == 'Ecoflex 50');
    if ~isempty(ecoRows)
        allData.Concentration(ecoRows) = "0"; % Assign concentration 0
    end
end


% Convert Concentration string to numeric, handling 'v' and 'N/A'/'0'
numericConcentration = zeros(height(allData), 1);
for i = 1:height(allData)
    concStr = lower(strtrim(allData.Concentration{i}));
    if strcmp(concStr, 'ecoflex 50') || strcmp(concStr, 'n/a') || strcmp(concStr, '0') || isempty(concStr) || allData.Material(i)=='Ecoflex 50'
         numericConcentration(i) = 0;
    elseif contains(concStr, 'v')
        numericConcentration(i) = sscanf(concStr, '%fv'); % Extract numeric part
    else
        % Try direct numeric conversion if possible
        numVal = str2double(concStr);
        if ~isnan(numVal)
            numericConcentration(i) = numVal;
        else
            warning('Could not parse concentration: %s for material %s. Setting to NaN.', allData.Concentration{i}, char(allData.Material(i)));
            numericConcentration(i) = NaN;
        end
    end
end
allData.ConcentrationNumeric = numericConcentration;

% --- Prepare Data for Grouped Bar Chart ---

% Define order
concentrations = [0, 10, 20, 30, 40, 50];
materialsOrder = {'Cerr 117', 'Cerr 158', 'FM'}; % Order within groups

% Create matrices for YM and SE (Rows: Concentration, Cols: Material)
numConcentrations = length(concentrations);
numMaterialsGrouped = length(materialsOrder);

YM_matrix = NaN(numConcentrations, numMaterialsGrouped);
SE_matrix = NaN(numConcentrations, numMaterialsGrouped);

% Populate matrices for grouped materials (Concentrations > 0)
for i = 2:numConcentrations % Start from 10%
    conc = concentrations(i);
    for j = 1:numMaterialsGrouped
        mat = materialsOrder{j};
        rowData = allData(allData.ConcentrationNumeric == conc & allData.Material == mat, :);
        if ~isempty(rowData)
            if height(rowData) > 1
                 warning('Multiple entries found for %s at %d%%. Using the first one.', mat, conc);
                 rowData = rowData(1,:); % Take the first one if duplicates somehow exist
            end
            YM_matrix(i, j) = rowData.YoungModulus_MPa;
            SE_matrix(i, j) = rowData.YoungModulus_SE;
        % else: leaves NaN, bar/errorbar will skip it
        end
    end
end

% Extract Ecoflex 50 data (Concentration 0)
ecoDataZero = allData(allData.ConcentrationNumeric == 0 & allData.Material == 'Ecoflex 50', :);
if isempty(ecoDataZero)
    warning('No data found for Ecoflex 50 at 0%% concentration after processing.');
    eco_ym = NaN;
    eco_se = NaN;
else
    if height(ecoDataZero) > 1
        warning('Multiple entries for Ecoflex 50 at 0%% found unexpectedly. Using the first.');
        ecoDataZero = ecoDataZero(1,:);
    end
    eco_ym = ecoDataZero.YoungModulus_MPa;
    eco_se = ecoDataZero.YoungModulus_SE;
end

% --- Plotting ---
figure('Position', [100, 100, 900, 600]); % Create a figure window
hold on;

% --- Add Math Models --- %%%%%%%%% Hiroshan  ###############
% Define Guth values
guth_conc = [0, 10, 20, 30, 40, 50]; % Concentrations to match existing ones
guth_ym = [0, E_guth_FM10, E_guth_FM20, E_guth_FM30, E_guth_FM40, E_guth_FM50]/1000000; % Young's Modulus values
guth_se = zeros(size(guth_ym)); % If you don’t have SE values, assume zero

% Append "Guth" to materials order
materialsOrder{end+1} = 'Guth'; % Update to include 4th column

% Expand YM_matrix and SE_matrix to include Guth
YM_matrix(:, end+1) = NaN;
SE_matrix(:, end+1) = NaN;

% Fill Guth values into new column
for i = 1:length(guth_conc)
    concIdx = find(concentrations == guth_conc(i), 1);
    if ~isempty(concIdx)
        YM_matrix(concIdx, end) = guth_ym(i);
        SE_matrix(concIdx, end) = guth_se(i);
    end
end



% Define Tsai values
tsai_conc = [0, 10, 20, 30, 40, 50]; % Concentrations to match existing ones
tsai_ym = [0, E_tsai_FM10, E_tsai_FM20, E_tsai_FM30, E_tsai_FM40, E_tsai_FM50]/1000000; % Young's Modulus values
tsai_se = zeros(size(tsai_ym)); % If you don’t have SE values, assume zero

% Append "Tsai" to materials order
materialsOrder{end+1} = 'Tsai'; % Update to include new material

% Expand YM_matrix and SE_matrix to include Tsai
YM_matrix(:, end+1) = NaN;
SE_matrix(:, end+1) = NaN;

% Fill Tsai values into new column
for i = 1:length(tsai_conc)
    concIdx = find(concentrations == tsai_conc(i), 1);
    if ~isempty(concIdx)
        YM_matrix(concIdx, end) = tsai_ym(i);
        SE_matrix(concIdx, end) = tsai_se(i);
    end
end



% Plot the grouped bars for concentrations > 0
conc_groups = concentrations(2:end); % 10, 20, 30, 40, 50
if ~isempty(conc_groups) && any(~isnan(YM_matrix(2:end, :)), 'all') % Check if there's any non-NaN data to plot
    b_groups = bar(conc_groups, YM_matrix(2:end, :), 'grouped'); % Use only rows for 10-50%

    % Assign colors to grouped bars
    if length(b_groups) >= 1, b_groups(1).FaceColor = colorCerr117; end % Cerr 117
    if length(b_groups) >= 2, b_groups(2).FaceColor = colorCerr158; end % Cerr 158
    if length(b_groups) >= 3, b_groups(3).FaceColor = colorFM;      end % FM
    if length(b_groups) >= 4, b_groups(4).FaceColor = colorGuth;    end % Guth
    if length(b_groups) >= 5, b_groups(5).FaceColor = colorTsai;      end % Tsai
else
    b_groups = []; % No grouped bars plotted
    warning('No data found for grouped bars (Concentrations > 0).');
end

% Plot the single bar for Ecoflex 50 at concentration 0
if ~isnan(eco_ym)
    groupWidth = 0.8; % Default group width for 'grouped' bars
    numBarsInGroup = numMaterialsGrouped;
     % Adjust width - make it comparable to *one* bar in the group, not the whole group
    singleBarWidth = groupWidth / numBarsInGroup * 3;
    b_eco = bar(0, eco_ym, singleBarWidth * 5, 'FaceColor', colorEcoflex);
else
    b_eco = []; % Handle for legend if no eco data
    warning('No valid data found for Ecoflex 50 at 0% concentration.');
end

% --- Add Error Bars ---

% Calculate x coordinates for grouped error bars IF bars were plotted
if ~isempty(b_groups)
    x_coords_grouped = nan(size(YM_matrix(2:end, :))); % Should be 5x3
    numConcGroupsToPlot = size(YM_matrix(2:end,:), 1); % Number of concentration groups (e.g., 5)
    numMaterialsInGroup = size(YM_matrix(2:end,:), 2); % Number of materials (e.g., 3)

    if length(b_groups) ~= numMaterialsInGroup
         warning('Mismatch between expected number of materials (%d) and plotted bar groups (%d).', numMaterialsInGroup, length(b_groups));
    else
        valid_coords_found = false; % Flag to track if any valid coords are found
        for j = 1:numMaterialsInGroup
            % Check if XEndPoints has the expected number of elements
            if isprop(b_groups(j), 'XEndPoints') && length(b_groups(j).XEndPoints) == numConcGroupsToPlot
                 % XEndPoints should be a row vector, needs transposing for matrix assignment
                 x_coords_grouped(:, j) = b_groups(j).XEndPoints';
                 valid_coords_found = true; % Mark that we got some coordinates
            else
                 warning('Could not get expected number of XEndPoints for bar group %d.', j);
                 % Fill with NaN if structure is unexpected
                 x_coords_grouped(:, j) = NaN;
            end
        end

        % Plot error bars for grouped data if valid coordinates were found
        if valid_coords_found && ~all(isnan(x_coords_grouped(:)))
             % *** CORRECTED/SIMPLIFIED ERROR BAR CALL ***
             % Pass the full matrices; errorbar handles NaNs internally.
             errorbar(x_coords_grouped, YM_matrix(2:end, :), SE_matrix(2:end, :), ...
                  'k.', 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 4);
             % *** END CORRECTION ***
        else
            warning('Failed to determine valid x-coordinates for grouped error bars or no valid data points.');
        end
    end
else
     x_coords_grouped = []; % No grouped bars, no coordinates
     warning('Skipping grouped error bars as no grouped bars were plotted.');
end


% Plot error bar for Ecoflex 50
if ~isempty(b_eco) && ~isnan(eco_se) % Check if bar exists and SE is valid
    errorbar(0, eco_ym, eco_se, 'k.', 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 4);
end

% --- Customize Axes ---
% [Rest of the axis customization, title, legend code remains the same as the previous version]
% ... (Keep the axis, title, legend, grid, box, hold off code from the previous correct version) ...

% --- Customize Axes ---
ax = gca; % Get current axes handle

% Set main X ticks and labels for Concentrations
ax.XTick = concentrations;
ax.XTickLabel = arrayfun(@(x) sprintf('%d%%', x), concentrations, 'UniformOutput', false);
ax.XLim = [-4, concentrations(end) + 5]; % Adjust limits for spacing

% REMOVED Secondary X-axis labels code

% Set X-axis label (Standard Single Axis)
xlabel('Volumetric % of Filler Material', 'FontSize', 11, 'FontWeight', 'bold');

% Set Y-axis label
ylabel('Modulus (MPa)', 'FontSize', 11, 'FontWeight', 'bold');

% Adjust Y limits if needed
drawnow; % Ensure limits are updated before querying
yLimCurrent = ax.YLim;
if yLimCurrent(1) > 0
    ax.YLim(1) = 0; % Ensure y starts at 0 if data is positive
end
all_ym = [YM_matrix(:); eco_ym];
all_se = [SE_matrix(:); eco_se];
maxValWithError = max(all_ym + all_se, [], 'omitnan'); % Find max value including error bar height

if ~isempty(maxValWithError) && ~isnan(maxValWithError) && maxValWithError > 0
   ax.YLim(2) = maxValWithError * 1.1; % Add 10% buffer at top based on max error bar point
elseif ~isempty(all_ym) && any(~isnan(all_ym)) && max(all_ym, [], 'omitnan') > 0 % Fallback to max YM if SE causes issues
    ax.YLim(2) = max(all_ym, [], 'omitnan') * 1.1;
else % Default if no valid data
    ax.YLim(2) = 1.0;
end
% Ensure valid limits if calculation failed or resulted in inverted axis
if ax.YLim(1) >= ax.YLim(2) || any(isnan(ax.YLim))
    ax.YLim = [0 1];
end


% --- Add Title and Legend ---
title('Elatsic Modulus', 'FontSize', 14, 'FontWeight', 'bold');

% Create legend with colored rectangles
legendHandles = [];
legendEntries = {};

% 1. Cerr 117 (Red)
if ~isempty(b_groups) && length(b_groups) >= 1 && isgraphics(b_groups(1))
    legendHandles(end+1) = b_groups(1);
    legendEntries{end+1} = 'Cerrelow 117';
end

% 2. Cerr 158 (Blue)
if length(b_groups) >= 2 && isgraphics(b_groups(2))
    legendHandles(end+1) = b_groups(2);
    legendEntries{end+1} = 'Cerrelow 158';
end

% 3. FM (Green)
if length(b_groups) >= 3 && isgraphics(b_groups(3))
    legendHandles(end+1) = b_groups(3);
    legendEntries{end+1} = 'Fields Metal';
end

% 4. Guth (Orange)
if length(b_groups) >= 4 && isgraphics(b_groups(4))
    legendHandles(end+1) = b_groups(4);
    legendEntries{end+1} = 'Guth Model';
end

% 5. Tsai (Orange)
if length(b_groups) >= 5 && isgraphics(b_groups(5))
    legendHandles(end+1) = b_groups(5);
    legendEntries{end+1} = 'Tsai Model';
end


% 6. Ecoflex (Purple)
if length(b_groups) >= 6 && isgraphics(b_groups(6))
    legendHandles(end+1) = b_groups(6);
    legendEntries{end+1} = 'Ecoflex';
end

% Final legend command
legend(legendHandles, legendEntries, 'Location', 'northwest');

% Display legend if entries were created
if ~isempty(legendHandles)
    legend(legendHandles, legendEntries, 'Location', 'northwest', 'FontSize', 10);
else
    warning('No valid graphics handles found for legend creation.');
end

legend(legendEntries, 'Position', [0.15 0.725 0.15 0.1]);

%grid on; % Add grid lines
box on;  % Ensure plot box is drawn






hold off;

% --- Optional: Save the Plot ---
% Uncomment the following line to save the figure
saveas(gcf, outputFileName);
fprintf('output_matlab/Plot saved as %s\n', outputFileName);