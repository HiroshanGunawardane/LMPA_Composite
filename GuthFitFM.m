clear; clc; close all;

% --- Load Experimental FM Data ---
fmFile = 'output_matlab/fm_dma.csv';
try
    dataFM = readtable(fmFile);
catch ME
    error('Failed to read FM file: %s', ME.message);
end

% --- Extract and Clean Data ---
dataFM.Material = categorical(dataFM.Material);
dataFM = dataFM(dataFM.Material == 'fm', :);

% Parse concentration values safely
concentrationStr = dataFM.Concentration;
numericConc = zeros(height(dataFM), 1);

for i = 1:height(dataFM)
    strVal = lower(strtrim(concentrationStr{i}));
    val = sscanf(strVal, '%f');
    if ~isempty(val)
        numericConc(i) = val(1);  % Use first value if multiple exist
    else
        warning('Could not parse concentration value: "%s"', strVal);
        numericConc(i) = NaN;  % Assign NaN for unparseable values
    end
end

% Remove rows with NaN concentrations
validRows = ~isnan(numericConc);
dataFM = dataFM(validRows, :);
numericConc = numericConc(validRows);

% Convert to volume fraction and Young's modulus in Pa
Vf = numericConc / 100;
E_exp = dataFM.YoungModulus_MPa * 1e6;  % MPa to Pa

% --- Guth Model Setup ---
l = 2.5;   % Fiber length (m)
d = 0.2;      % Fiber diameter (m)
AR = l / d;   % Aspect ratio
E0 = 82000;   % Matrix modulus (Pa)

% --- Define Guth Model and Error Function ---
% Guth: E = E0 * (1 + A * AR * Vf + B * AR^2 * Vf.^2)
guth_model = @(params, Vf) E0 * (1 + params(1) * AR * Vf + params(2) * AR^2 * Vf.^2);
error_func = @(params) guth_model(params, Vf) - E_exp;

% --- Optimize Guth Parameters ---
initialGuess = [2.0, 0.5];
opts = optimoptions('lsqnonlin', 'Display', 'iter');
[paramFit, resnorm] = lsqnonlin(error_func, initialGuess, [], [], opts);

% --- Output Results ---
A_fit = paramFit(1);
B_fit = paramFit(2);
fprintf('Optimized Guth parameters:\n');
fprintf('  A = %.4f\n', A_fit);
fprintf('  B = %.4f\n', B_fit);

% --- Predict and Plot ---
E_guth_fit = guth_model(paramFit, Vf) / 1e6;  % Pa to MPa
E_exp_mpa = E_exp / 1e6;

figure('Position', [100, 100, 800, 500]);
hold on;
plot(numericConc, E_exp_mpa, 'ko-', 'LineWidth', 2, 'DisplayName', 'Experimental');
plot(numericConc, E_guth_fit, 'r*-', 'LineWidth', 2, 'DisplayName', 'Fitted Guth Model');
xlabel('Filler Concentration (%)');
ylabel("Young's Modulus (MPa)");
title('Fitting Guth Model to FM Data');
legend('Location', 'northwest');
grid on;
