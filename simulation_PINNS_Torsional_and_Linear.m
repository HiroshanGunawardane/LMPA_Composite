%% Physics-Informed Neural Network (PINN) for Bending Actuator with SPA Dynamics Regularization
clear; clc;

%% --- Generate Synthetic Bending Data ---
n = 100;
P = linspace(0, 400, n)';              % Pressure in kPa
theta_max_deg = 100; L = 1.0;          % Arc length (m)

% Generate nonlinear angle with noise
theta_rad = deg2rad(theta_max_deg) * (1 - exp(-0.02 * P));
noise = deg2rad(2) * randn(n,1);
theta_rad_noisy = theta_rad + noise;
theta_deg_noisy = rad2deg(theta_rad_noisy);

% Compute tip displacement (x, y)
x = zeros(n,1); y = zeros(n,1);
for i = 1:n
    th = theta_rad_noisy(i);
    if abs(th) < 1e-6
        x(i) = 0; y(i) = L;
    else
        R = L / th;
        x(i) = R * sin(th);
        y(i) = R * (1 - cos(th));
    end
end

% Save data
data = [P, theta_deg_noisy, x, y];
writematrix(data, 'bending_actuator_synthetic_with_tip.csv');

% Plot synthetic data
figure;
subplot(1,2,1);
plot(P, theta_deg_noisy, 'bo-', 'DisplayName', 'Noisy Bending');
hold on;
plot(P, rad2deg(theta_rad), 'r--', 'DisplayName', 'Ideal');
xlabel('Pressure (kPa)');
ylabel('Bending Angle (deg)');
title('Bending Angle vs Pressure');
legend; grid on;

subplot(1,2,2);
plot(x, y, 'g-', 'LineWidth', 2);
xlabel('X (m)'); ylabel('Y (m)');
title('Tip Displacement');
axis equal; grid on;

%% --- Define PINN ---
% Normalize pressure input between 0 and 1
P_norm = (P - min(P)) / (max(P) - min(P));

% Convert to dlarray for training (1 x batch)
tTrain = dlarray(P_norm','CB');          % Input: normalized pressure
YTrain = dlarray(theta_rad_noisy','CB'); % Target: bending angle in rad

% Define network layers
layers = [
    featureInputLayer(1)
    fullyConnectedLayer(20)
    tanhLayer
    fullyConnectedLayer(20)
    tanhLayer
    fullyConnectedLayer(1)
];

net = dlnetwork(layers);

%% --- Define Physics Parameters ---
params.n = 1;          % Single DOF
params.m = 0.5;        % Mass (kg)
params.l = 1.0;        % Length (m)
params.g = 9.81;       % Gravity (m/s^2)
params.k_theta = 5;    % Stiffness (Nm/rad) - example
params.tau_func = @(t) 1e-3 * t * 400; % Torque function proportional to pressure (scaled)

%% --- Training Setup ---
numEpochs = 1000;
learnRate = 1e-2;
trailingAvg = [];
trailingAvgSq = [];

lossHistory = zeros(numEpochs,1);

%% --- Training Loop ---
for epoch = 1:numEpochs
    [loss, gradients] = dlfeval(@modelLoss, net, tTrain, YTrain, params);
    [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, ...
        trailingAvg, trailingAvgSq, epoch, learnRate);

    lossHistory(epoch) = extractdata(loss);

    if mod(epoch, 100) == 0
        fprintf('Epoch %d: Loss = %.4e\n', epoch, lossHistory(epoch));
    end
end

%% --- Plot Training Loss ---
figure;
plot(lossHistory);
xlabel('Epoch');
ylabel('Loss');
title('PINN Training Loss');

%% --- Plot Model Prediction ---
YPred = predict(net, tTrain);
theta_pred = extractdata(YPred)';

figure;
plot(P, rad2deg(theta_rad_noisy), 'bo-', 'DisplayName', 'Measured');
hold on;
plot(P, rad2deg(theta_pred), 'r--', 'LineWidth', 1.5, 'DisplayName', 'PINN Prediction');
xlabel('Pressure (kPa)');
ylabel('Bending Angle (deg)');
title('PINN Prediction vs Ground Truth');
legend; grid on;

%% --- Model Loss Function ---
function [loss, gradients] = modelLoss(net, t, YTrue, params)
    % Forward pass
    q = forward(net, t);  % predicted bending angle (1 x batch)

    % First derivative dq/dt (1 x batch)
    dq = dlgradient(sum(q), t, 'RetainData', true);

    % Second derivative ddq/dt^2 (1 x batch)
    ddq = dlgradient(sum(dq), t);

    % Physics residual
    [residual, ~, ~, ~, ~] = spa_dynamics(t, q, dq, ddq, params);

    % Data loss: MSE between predicted and true bending angles
    mse_data = mse(q, YTrue);

    % Physics loss: MSE of residuals (should be close to zero)
    mse_phys = mse(residual, zeros(size(residual), 'like', residual));

    % Total loss
    loss = mse_data + mse_phys;

    % Compute gradients for backpropagation
    gradients = dlgradient(loss, net.Learnables);
end

%% --- SPA Dynamics Function ---
function [residual, M, C, G, tau] = spa_dynamics(~, q, dq, ddq, params)
    % Extract params
    m = params.m;
    l = params.l;
    g = params.g;
    k_theta = params.k_theta;

    % Scalar inertia
    I = (1/3) * m * l^2;

    % Mass matrix (scalar)
    M = I;

    % Coriolis matrix zero (single DOF)
    C = 0;

    % Gravity term (1 x batch)
    G = m * g * l/2 * sin(extractdata(q));

    % Input torque (1 x batch)
    tau_val = params.tau_func(extractdata(q));
    tau = tau_val;

    % Residual of dynamics (1 x batch)
    residual_val = M * extractdata(ddq) + C * extractdata(dq) + G - tau;

    residual = dlarray(residual_val);
end
