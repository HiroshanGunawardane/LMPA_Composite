clear; clc; close all;

% --- Load Experimental Data ---
ss0File = 'output_matlab/ss0_young_modulus_results.csv';
try
    data = readtable(ss0File);
catch ME
    error('Failed to read experimental data: %s', ME.message);
end

% --- Normalize material names safely ---
data.Material = categorical(data.Material);
origCats = categories(data.Material);

for i = 1:length(origCats)
    oldCat = origCats{i};
    switch lower(oldCat)
        case 'fm'
            data.Material(data.Material == oldCat) = 'FM';
        case 'cerr_117'
            data.Material(data.Material == oldCat) = 'Cerr 117';
        case 'cerr_158'
            data.Material(data.Material == oldCat) = 'Cerr 158';
    end
end

data.Material = removecats(data.Material);

% Filter only desired materials
materialNames = {'FM', 'Cerr 117', 'Cerr 158'};
data = data(ismember(data.Material, materialNames), :);

% --- Parse concentration values ---
concentrationStr = data.Concentration;
numericConc = zeros(height(data), 1);

for i = 1:height(data)
    strVal = lower(strtrim(concentrationStr{i}));
    val = sscanf(strVal, '%f');
    if ~isempty(val)
        numericConc(i) = val(1);  % Use first value if multiple exist
    else
        warning('Could not parse concentration value: "%s"', strVal);
        numericConc(i) = NaN;
    end
end

% Remove invalid rows
validRows = ~isnan(numericConc);
data = data(validRows, :);
numericConc = numericConc(validRows);
data.ConcentrationNumeric = numericConc;

% --- Convert to volume fraction and Young's modulus in Pa ---
data.Vf = data.ConcentrationNumeric / 100;
data.E_Young_Pa = data.YoungModulus_MPa * 1e6;

% --- Guth Model Setup ---
l = 2.5;    % Fiber length (m)
d = 0.2;       % Fiber diameter (m)
AR = l / d;    % Aspect ratio
E0 = 82000;    % Matrix modulus (Pa)

% --- Combine all data into one array for fitting ---
Vf_all = data.Vf;
E_exp_all = data.E_Young_Pa;

% --- Guth Model Function and Error Function ---
guth_model = @(params, Vf) E0 * (1 + params(1) * AR * Vf + params(2) * AR^2 * Vf.^2);
error_func = @(params) guth_model(params, Vf_all) - E_exp_all;

% --- Fit Parameters A and B Across All Materials ---
initialGuess = [2.0, 0.5];
opts = optimoptions('lsqnonlin', 'Display', 'iter');
[paramFit, resnorm] = lsqnonlin(error_func, initialGuess, [], [], opts);

% --- Output Optimized Parameters ---
A_fit = paramFit(1);
B_fit = paramFit(2);
fprintf('Optimized Guth parameters (averaged across FM, Cerr 117, Cerr 158):\n');
fprintf('  A = %.4f\n', A_fit);
fprintf('  B = %.4f\n', B_fit);

% --- Predict for Each Material ---
figure('Position', [100, 100, 900, 600]);
hold on;

colors = lines(length(materialNames));

for i = 1:length(materialNames)
    mat = materialNames{i};
    matData = data(data.Material == mat, :);
    Vf = matData.Vf;
    E_exp = matData.E_Young_Pa / 1e6;  % MPa
    E_pred = guth_model(paramFit, Vf) / 1e6;  % MPa

    plot(matData.ConcentrationNumeric, E_exp, 'o-', 'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s Experimental', mat));
    plot(matData.ConcentrationNumeric, E_pred, '*--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s Guth Fit', mat));
end

xlabel('Filler Concentration (%)');
ylabel("Young's Modulus (MPa)");
title('Guth Model Fit Averaged Over FM, Cerr 117, Cerr 158');
legend('Location', 'northwest');
grid on;
