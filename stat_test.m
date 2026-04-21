% Script for Statistical Analysis of Young's Modulus Data
% Includes saving results to CSV and generating box plots.

clear; clc; close all;

% --- Configuration ---
outputDir = 'D:\Guien MEMS Lab Final\new_method\output_matlab'; % Directory containing the CSVs
statsOutputDir = fullfile(outputDir, 'statistical_analysis'); % Subdir for stats results/plots
plotOutputDir = fullfile(statsOutputDir, 'plots'); % Subdir for plots

% Input filenames for INDIVIDUAL sample results
ss0IndividualFile = fullfile(outputDir, 'ss0_individual_modulus_data.csv');
fmIndividualFile = fullfile(outputDir, 'fm_dma_individual_modulus_data.csv');

% Output filenames for statistical results
statsCsvFile_MatWithinConc = fullfile(statsOutputDir, 'stats_materials_within_concentration.csv');
statsCsvFile_ConcWithinMat = fullfile(statsOutputDir, 'stats_concentrations_within_material.csv');

alpha = 0.05; % Significance level for tests

fprintf('--- Starting Statistical Analysis (alpha = %.3f) ---\n', alpha);

% --- Create Output Directories ---
if ~isfolder(statsOutputDir), mkdir(statsOutputDir); fprintf('Created directory: %s\n', statsOutputDir); end
if ~isfolder(plotOutputDir), mkdir(plotOutputDir); fprintf('Created directory: %s\n', plotOutputDir); end

% --- Load Data ---
% (Loading code remains the same as previous version)
try
    opts_ss0 = detectImportOptions(ss0IndividualFile);
    opts_ss0 = setvartype(opts_ss0, {'Material', 'Concentration', 'SampleID'}, 'string');
    opts_ss0 = setvartype(opts_ss0, {'Individual_YoungModulus_MPa', 'R_Squared'}, 'double');
    dataSS0 = readtable(ss0IndividualFile, opts_ss0);
    fprintf('Loaded %d rows from %s\n', height(dataSS0), ss0IndividualFile);
catch ME_ss0, error('Failed to load SS0 individual data: %s\n%s', ss0IndividualFile, ME_ss0.message); end
try
    opts_fm = detectImportOptions(fmIndividualFile);
    opts_fm = setvartype(opts_fm, {'Material', 'Concentration', 'SampleFileName'}, 'string');
    opts_fm = setvartype(opts_fm, {'Individual_YoungModulus_MPa'}, 'double');
    dataFM = readtable(fmIndividualFile, opts_fm);
    fprintf('Loaded %d rows from %s\n', height(dataFM), fmIndividualFile);
    if ismember('SampleFileName', dataFM.Properties.VariableNames) && ~ismember('SampleID', dataFM.Properties.VariableNames)
        dataFM = renamevars(dataFM, 'SampleFileName', 'SampleID'); end
    if ~ismember('R_Squared', dataFM.Properties.VariableNames), dataFM.R_Squared = NaN(height(dataFM), 1); end
catch ME_fm, error('Failed to load FM individual data: %s\n%s', fmIndividualFile, ME_fm.message); end

% --- Combine and Preprocess Data ---
% (Combine and Preprocessing code remains the same)
commonCols = {'Material', 'Concentration', 'SampleID', 'Individual_YoungModulus_MPa'};
dataSS0_subset = dataSS0(:, intersect(commonCols, dataSS0.Properties.VariableNames, 'stable')); % Use intersect for safety
dataFM_subset = dataFM(:, intersect(commonCols, dataFM.Properties.VariableNames, 'stable'));
allIndividualData = [dataSS0_subset; dataFM_subset];
fprintf('Combined data: %d total rows.\n', height(allIndividualData));
nanModulusRows = isnan(allIndividualData.Individual_YoungModulus_MPa);
if any(nanModulusRows), fprintf('Removing %d rows with NaN Modulus values.\n', sum(nanModulusRows)); allIndividualData = allIndividualData(~nanModulusRows, :); end
if height(allIndividualData) < 2, error('Insufficient non-NaN data after combining.'); end
allIndividualData.Material = categorical(allIndividualData.Material); materialNames = categories(allIndividualData.Material);
for i = 1:length(materialNames)
    if strcmpi(materialNames{i}, 'fm'), allIndividualData.Material(allIndividualData.Material == materialNames{i}) = 'FM';
    elseif strcmpi(materialNames{i}, 'cerr_117'), allIndividualData.Material(allIndividualData.Material == materialNames{i}) = 'Cerr 117';
    elseif strcmpi(materialNames{i}, 'cerr_158'), allIndividualData.Material(allIndividualData.Material == materialNames{i}) = 'Cerr 158';
    elseif contains(materialNames{i}, 'ecoflex', 'IgnoreCase', true), allIndividualData.Material(allIndividualData.Material == materialNames{i}) = 'Ecoflex 50'; end
end
allIndividualData.Material = removecats(allIndividualData.Material);
numericConcentration = NaN(height(allIndividualData), 1);
for i = 1:height(allIndividualData)
    concStr = lower(strtrim(allIndividualData.Concentration{i}));
    if strcmp(concStr, 'n/a') || strcmp(concStr, 'ecoflex 50'), numericConcentration(i) = 0;
    elseif endsWith(concStr, 'v'), numPart = sscanf(concStr, '%fv'); if ~isempty(numPart), numericConcentration(i) = numPart; end
    else, numVal = str2double(concStr); if ~isnan(numVal), numericConcentration(i) = numVal; end; end
end
allIndividualData.ConcentrationNumeric = numericConcentration;
nanConcRows = isnan(allIndividualData.ConcentrationNumeric);
if any(nanConcRows), fprintf('Removing %d rows where Concentration could not be parsed.\n', sum(nanConcRows)); allIndividualData = allIndividualData(~nanConcRows, :); end
if height(allIndividualData) < 2, error('Insufficient data remaining after concentration parsing.'); end
fprintf('Standardized Material names and Parsed Concentrations.\n');
disp('Sample of combined and preprocessed data:'); disp(head(allIndividualData));
uniqueMaterials = categories(removecats(allIndividualData.Material));
allIndividualData.ConcentrationNumeric(allIndividualData.Material == 'Ecoflex 50') = 0;
uniqueConcentrations = unique(allIndividualData.ConcentrationNumeric); uniqueConcentrations = sort(uniqueConcentrations(uniqueConcentrations >= 0));
fprintf('\nUnique Materials Found: %s\n', strjoin(uniqueMaterials, ', ')); fprintf('Unique Numeric Concentrations Found: %s\n', num2str(uniqueConcentrations'));

% --- Initialize Results Tables ---
resultsTableAnalysis1 = table('Size',[0 10], 'VariableTypes', ...
    {'double', 'string', 'string', 'string', 'uint32', 'uint32', 'double', 'double', 'double', 'logical'}, ...
    'VariableNames', ...
    {'Concentration', 'ComparisonType', 'Group1', 'Group2', 'N1', 'N2', 'Statistic_H', 'P_Value_Raw', 'Alpha_Bonferroni', 'Is_Significant_Bonf'});

resultsTableAnalysis2 = table('Size',[0 10], 'VariableTypes', ...
    {'string', 'string', 'string', 'string', 'uint32', 'uint32', 'double', 'double', 'double', 'logical'}, ...
    'VariableNames', ...
    {'Material', 'ComparisonType', 'Group1', 'Group2', 'N1', 'N2', 'Statistic_H', 'P_Value_Raw', 'Alpha_Bonferroni', 'Is_Significant_Bonf'});


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Analysis 1: Compare Materials WITHIN Each Concentration Level ---
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n\n--- Analysis 1: Comparing Materials within Concentration Levels ---\n');
concentrationsToCompare = uniqueConcentrations(uniqueConcentrations > 0);
plotCounter1 = 0; % Counter for plot figures

if isempty(concentrationsToCompare)
    fprintf('No concentration levels > 0 found to compare materials within.\n');
else
    for conc = concentrationsToCompare'
        fprintf('\n-- Concentration Level: %d%% --\n', conc);
        dataCurrentConc = allIndividualData(allIndividualData.ConcentrationNumeric == conc, :);
        materialsAtConc = categories(removecats(dataCurrentConc.Material));
        numMaterialsAtConc = length(materialsAtConc);

        if numMaterialsAtConc < 2
            fprintf('   Only one material type (%s) found. No comparison needed.\n', strjoin(materialsAtConc, ', ')); continue;
        end
        if height(dataCurrentConc) < numMaterialsAtConc
            fprintf('   WARNING: Less data points (%d) than groups (%d). Skipping analysis.\n', height(dataCurrentConc), numMaterialsAtConc); continue;
        end
        fprintf('   Materials present: %s\n', strjoin(materialsAtConc, ', '));

        % Kruskal-Wallis Test
        p_kw_mat = NaN; H_kw_mat = NaN; perform_pairwise_mat = false; % Defaults
        try
            [p_kw_mat, tbl_kw_mat, stats_kw_mat] = kruskalwallis(dataCurrentConc.Individual_YoungModulus_MPa, dataCurrentConc.Material, 'off');
            H_kw_mat = tbl_kw_mat{2,5}; % Chi-sq stat
            fprintf('   Kruskal-Wallis Test: H = %.4f, p = %.5f\n', H_kw_mat, p_kw_mat);
            perform_pairwise_mat = p_kw_mat < alpha;
            fprintf('   -> Overall difference %sdetected (p=%.4f).\n', iif(perform_pairwise_mat,'','NOT '), p_kw_mat);
            % Add KW result to table
            kwRow = {conc, "KruskalWallis", "Overall", strjoin(materialsAtConc, ' vs '), stats_kw_mat.n(1), sum(stats_kw_mat.n(2:end)), H_kw_mat, p_kw_mat, NaN, perform_pairwise_mat};
            resultsTableAnalysis1 = [resultsTableAnalysis1; kwRow];
        catch ME_kw_mat
            warning('Kruskal-Wallis test failed for concentration %d%%: %s', conc, ME_kw_mat.message);
            % Add placeholder row
             resultsTableAnalysis1 = [resultsTableAnalysis1; {conc, "KruskalWallis", "Overall", strjoin(materialsAtConc, ' vs '), NaN, NaN, NaN, NaN, NaN, false}];
        end

        % Pairwise Mann-Whitney U Tests
        alpha_bonf_mat = NaN; % Default
        if perform_pairwise_mat
            num_comparisons_mat = nchoosek(numMaterialsAtConc, 2);
            alpha_bonf_mat = alpha / num_comparisons_mat;
            fprintf('   Performing %d pairwise Mann-Whitney tests (alpha_adj = %.6f)...\n', num_comparisons_mat, alpha_bonf_mat);
            comparison_count = 0;
            for i = 1:(numMaterialsAtConc - 1)
                for j = (i + 1):numMaterialsAtConc
                    comparison_count = comparison_count + 1;
                    mat1_name = materialsAtConc{i}; mat2_name = materialsAtConc{j};
                    data1 = dataCurrentConc.Individual_YoungModulus_MPa(dataCurrentConc.Material == mat1_name); n1 = numel(data1);
                    data2 = dataCurrentConc.Individual_YoungModulus_MPa(dataCurrentConc.Material == mat2_name); n2 = numel(data2);
                    p_mw = NaN; significant = false; % Defaults

                    if n1 > 0 && n2 > 0
                       try
                           p_mw = ranksum(data1, data2); significant = p_mw < alpha_bonf_mat;
                       catch ME_mw, warning('MW test failed: %s vs %s @ %d%%: %s', mat1_name, mat2_name, conc, ME_mw.message); end
                    end
                    fprintf('      %d. %s(N=%d) vs %s(N=%d): p=%.5f %s\n', comparison_count, mat1_name, n1, mat2_name, n2, p_mw, iif(significant, '(SIGNIFICANT)', '(ns)'));
                    % Add pairwise result to table
                    mwRow = {conc, "Pairwise_MW", mat1_name, mat2_name, n1, n2, NaN, p_mw, alpha_bonf_mat, significant};
                    resultsTableAnalysis1 = [resultsTableAnalysis1; mwRow];
                end
            end
        end % End pairwise for materials

        % Generate Box Plot for this concentration
        plotCounter1 = plotCounter1 + 1;
        hFig1 = figure('Name', sprintf('Analysis 1: Modulus Distribution at %d%% Conc', conc), 'Visible', 'off'); % Create figure but keep hidden for now
        ax1 = axes('Parent', hFig1);
        try
             boxplot(ax1, dataCurrentConc.Individual_YoungModulus_MPa, dataCurrentConc.Material, 'Notch', 'on', 'Labels', materialsAtConc);
             ylabel(ax1, 'Young''s Modulus (MPa)');
             title(ax1, sprintf('Material Comparison at %d%% Concentration', conc));
             grid(ax1, 'on');
             plotFilename1 = fullfile(plotOutputDir, sprintf('boxplot_materials_at_%d_percent.png', conc));
             saveas(hFig1, plotFilename1);
             fprintf('   Saved box plot: %s\n', plotFilename1);
        catch ME_plot1
             warning('Failed to generate or save box plot for %d%% concentration: %s', conc, ME_plot1.message);
        end
        close(hFig1); % Close the figure after saving

    end % End loop through concentrations > 0

    % Save Analysis 1 Results Table
    try
        writetable(resultsTableAnalysis1, statsCsvFile_MatWithinConc);
        fprintf('\nSaved Analysis 1 results to: %s\n', statsCsvFile_MatWithinConc);
    catch ME_write1
        warning('Failed to write Analysis 1 results to CSV: %s', ME_write1.message);
    end
end % End check if concentrationsToCompare is empty


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Analysis 2: Compare Concentration Levels WITHIN Each Material Type ---
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n\n--- Analysis 2: Comparing Concentration Levels within Materials ---\n');
baseMaterials = {'Cerr 117', 'Cerr 158', 'FM'};
plotCounter2 = 0; % Counter for plot figures

for i_mat = 1:length(baseMaterials)
    currentMaterial = baseMaterials{i_mat};
    fprintf('\n-- Material Type: %s --\n', currentMaterial);
    includeEcoflex = ~strcmp(currentMaterial, 'FM'); % Only include Ecoflex for Cerr materials

    if includeEcoflex
        dataCurrentMat = allIndividualData(allIndividualData.Material == currentMaterial | allIndividualData.Material == 'Ecoflex 50', :);
        fprintf('   (Including Ecoflex 50 as 0%% baseline)\n');
    else
        dataCurrentMat = allIndividualData(allIndividualData.Material == currentMaterial, :);
        fprintf('   (FM material only)\n');
    end

    concentrationsForMat = unique(dataCurrentMat.ConcentrationNumeric);
    numConcentrationsForMat = length(concentrationsForMat);

    if numConcentrationsForMat < 2
        fprintf('   Only one concentration level (%s%%) found. No comparison needed.\n', num2str(concentrationsForMat')); continue;
    end
    if height(dataCurrentMat) < numConcentrationsForMat
         fprintf('   WARNING: Less data points (%d) than groups (%d). Skipping analysis.\n', height(dataCurrentMat), numConcentrationsForMat); continue;
    end
    fprintf('   Concentration levels present: %s\n', num2str(concentrationsForMat'));

    % Kruskal-Wallis Test
    p_kw_conc = NaN; H_kw_conc = NaN; perform_pairwise_conc = false; % Defaults
    try
        % Need group labels that handle Ecoflex correctly for KW grouping
        kwGroups = string(dataCurrentMat.ConcentrationNumeric);
        if includeEcoflex, kwGroups(dataCurrentMat.Material == 'Ecoflex 50') = "0 (Ecoflex)"; end

        [p_kw_conc, tbl_kw_conc, stats_kw_conc] = kruskalwallis(dataCurrentMat.Individual_YoungModulus_MPa, kwGroups, 'off');
        H_kw_conc = tbl_kw_conc{2,5}; % Chi-sq stat
        fprintf('   Kruskal-Wallis Test: H = %.4f, p = %.5f\n', H_kw_conc, p_kw_conc);
        perform_pairwise_conc = p_kw_conc < alpha;
        fprintf('   -> Overall difference %sdetected (p=%.4f).\n', iif(perform_pairwise_conc,'','NOT '), p_kw_conc);
        % Add KW result to table
        kwRow2 = {currentMaterial, "KruskalWallis", "Overall", strjoin(arrayfun(@(c) sprintf('%d%%', c), concentrationsForMat, 'UniformOutput', false), ' vs '), stats_kw_conc.n(1), sum(stats_kw_conc.n(2:end)), H_kw_conc, p_kw_conc, NaN, perform_pairwise_conc};
        resultsTableAnalysis2 = [resultsTableAnalysis2; kwRow2];
    catch ME_kw_conc
        warning('Kruskal-Wallis test failed for material %s: %s', currentMaterial, ME_kw_conc.message);
        resultsTableAnalysis2 = [resultsTableAnalysis2; {currentMaterial, "KruskalWallis", "Overall", strjoin(arrayfun(@(c) sprintf('%d%%', c), concentrationsForMat, 'UniformOutput', false), ' vs '), NaN, NaN, NaN, NaN, NaN, false}];
    end

    % Pairwise Mann-Whitney U Tests
    alpha_bonf_conc = NaN; % Default
    if perform_pairwise_conc
        num_comparisons_conc = nchoosek(numConcentrationsForMat, 2);
        alpha_bonf_conc = alpha / num_comparisons_conc;
        fprintf('   Performing %d pairwise Mann-Whitney tests (alpha_adj = %.6f)...\n', num_comparisons_conc, alpha_bonf_conc);
        comparison_count = 0;
        for i = 1:(numConcentrationsForMat - 1)
            for j = (i + 1):numConcentrationsForMat
                comparison_count = comparison_count + 1;
                conc1 = concentrationsForMat(i); conc2 = concentrationsForMat(j);
                label1 = sprintf('%d%%', conc1); label2 = sprintf('%d%%', conc2);
                p_mw = NaN; significant = false; % Defaults

                if conc1 == 0 && includeEcoflex, data1 = dataCurrentMat.Individual_YoungModulus_MPa(dataCurrentMat.Material == 'Ecoflex 50'); label1 = '0% (Ecoflex)';
                else, data1 = dataCurrentMat.Individual_YoungModulus_MPa(dataCurrentMat.ConcentrationNumeric == conc1 & dataCurrentMat.Material == currentMaterial); end
                n1 = numel(data1);

                if conc2 == 0 && includeEcoflex, data2 = dataCurrentMat.Individual_YoungModulus_MPa(dataCurrentMat.Material == 'Ecoflex 50'); label2 = '0% (Ecoflex)';
                else, data2 = dataCurrentMat.Individual_YoungModulus_MPa(dataCurrentMat.ConcentrationNumeric == conc2 & dataCurrentMat.Material == currentMaterial); end
                n2 = numel(data2);

                if n1 > 0 && n2 > 0
                   try
                       p_mw = ranksum(data1, data2); significant = p_mw < alpha_bonf_conc;
                   catch ME_mw, warning('MW test failed: %s vs %s for %s: %s', label1, label2, currentMaterial, ME_mw.message); end
                end
                fprintf('      %d. %s(N=%d) vs %s(N=%d): p=%.5f %s\n', comparison_count, label1, n1, label2, n2, p_mw, iif(significant, '(SIGNIFICANT)', '(ns)'));
                 % Add pairwise result to table
                 mwRow2 = {currentMaterial, "Pairwise_MW", label1, label2, n1, n2, NaN, p_mw, alpha_bonf_conc, significant};
                 resultsTableAnalysis2 = [resultsTableAnalysis2; mwRow2];
            end
        end
    end % End pairwise for concentrations

    % Generate Box Plot for this material
    plotCounter2 = plotCounter2 + 1;
    hFig2 = figure('Name', sprintf('Analysis 2: Modulus Distribution for %s', currentMaterial), 'Visible', 'off');
    ax2 = axes('Parent', hFig2);
    try
        % Create labels for boxplot, handling Ecoflex inclusion
        boxLabels = cellstr(num2str(concentrationsForMat', '%d%%'));
        boxData = dataCurrentMat.Individual_YoungModulus_MPa;
        boxGroups = dataCurrentMat.ConcentrationNumeric; % Use numeric for grouping
        if includeEcoflex, boxLabels(concentrationsForMat == 0) = {'0% (Ecoflex)'}; end

        boxplot(ax2, boxData, boxGroups, 'Notch', 'on', 'Labels', boxLabels);
        ylabel(ax2, 'Young''s Modulus (MPa)');
        title(ax2, sprintf('Concentration Comparison for %s', currentMaterial));
        grid(ax2, 'on');
        plotFilename2 = fullfile(plotOutputDir, sprintf('boxplot_concentrations_for_%s.png', strrep(currentMaterial,' ','_')));
        saveas(hFig2, plotFilename2);
        fprintf('   Saved box plot: %s\n', plotFilename2);
    catch ME_plot2
        warning('Failed to generate or save box plot for material %s: %s', currentMaterial, ME_plot2.message);
    end
    close(hFig2); % Close the figure after saving

end % End loop through base materials

% Save Analysis 2 Results Table
try
    writetable(resultsTableAnalysis2, statsCsvFile_ConcWithinMat);
    fprintf('\nSaved Analysis 2 results to: %s\n', statsCsvFile_ConcWithinMat);
catch ME_write2
    warning('Failed to write Analysis 2 results to CSV: %s', ME_write2.message);
end

fprintf('\n\n--- Statistical Analysis and Plotting Complete ---\n');

% Helper function for inline if/else text (requires R2016b or later)
function result = iif(condition, trueText, falseText)
    if condition, result = trueText; else, result = falseText; end
end