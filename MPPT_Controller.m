%=================================================
% خوارزمية MPPT - Perturb & Observe
% MPPT Algorithm - Perturb & Observe Method
%=================================================
% الاستخدام: V_ref_new = MPPT_PO(V, I, P_prev, V_prev)

function V_ref = MPPT_PO(V_pv, I_pv, P_prev, V_prev, varargin)
    % MPPT_PO Perturb & Observe MPPT Algorithm
    % 
    % Inputs:
    %   V_pv   - Current PV voltage (V)
    %   I_pv   - Current PV current (A)
    %   P_prev - Previous power reading (W)
    %   V_prev - Previous voltage setting (V)
    %   varargin - Optional parameters (step_size, limits)
    %
    % Output:
    %   V_ref  - New voltage reference for Boost converter
    
    % Default parameters
    if nargin < 5
        step_size = 0.5;  % Voltage step (V)
    else
        step_size = varargin{1};
    end
    
    if nargin < 6
        V_min = 20;       % Minimum voltage limit
        V_max = 48;       % Maximum voltage limit
    else
        V_min = varargin{2};
        V_max = varargin{3};
    end
    
    % Calculate current power
    P = V_pv * I_pv;
    
    % Calculate changes
    dP = P - P_prev;      % Power change
    dV = V_pv - V_prev;   % Voltage change
    
    % Perturb & Observe Logic
    %
    %       dP
    %       /\
    %      /  \
    %   +/    \-
    %  /        \
    % -------- dV
    %
    % If dP > 0: we moved towards MPP
    % If dP < 0: we moved away from MPP
    %
    
    if dP >= 0
        if dV >= 0
            % Power increased, voltage increased
            % We're moving right towards MPP
            V_ref = V_pv + step_size;
        else
            % Power increased, voltage decreased
            % We're moving left towards MPP
            V_ref = V_pv - step_size;
        end
    else  % dP < 0
        if dV >= 0
            % Power decreased, voltage increased
            % We're moving right away from MPP
            V_ref = V_pv - step_size;
        else
            % Power decreased, voltage decreased
            % We're moving left away from MPP
            V_ref = V_pv + step_size;
        end
    end
    
    % Apply voltage limits for safety
    V_ref = max(min(V_ref, V_max), V_min);
    
end

%=================================================
% Incremental Conductance Algorithm (Alternative)
%=================================================

function V_ref = MPPT_InCond(V_pv, I_pv, V_prev, I_prev, varargin)
    % MPPT_InCond Incremental Conductance MPPT Algorithm
    % More accurate than P&O, faster convergence
    %
    % Theory:
    % dP/dV = d(V*I)/dV = I + V*dI/dV = 0 at MPP
    % I/V + dI/dV = 0 at MPP
    
    % Default parameters
    if nargin < 5
        step_size = 0.5;
    else
        step_size = varargin{1};
    end
    
    if nargin < 6
        V_min = 20;
        V_max = 48;
    else
        V_min = varargin{2};
        V_max = varargin{3};
    end
    
    % Calculate changes
    dV = V_pv - V_prev;
    dI = I_pv - I_prev;
    
    % Avoid division by zero
    if abs(dV) < 1e-6
        dV = 1e-6;
    end
    
    % Incremental conductance
    incond = dI / dV;           % Incremental conductance
    instcond = I_pv / V_pv;     % Instantaneous conductance
    
    % Decision logic
    if abs(incond + instcond) < 0.001
        % dP/dV = 0, at MPP
        V_ref = V_pv;          % Stay
    elseif (incond + instcond) > 0
        % dP/dV > 0, left of MPP
        V_ref = V_pv + step_size;  % Move right
    else
        % dP/dV < 0, right of MPP
        V_ref = V_pv - step_size;  % Move left
    end
    
    % Apply limits
    V_ref = max(min(V_ref, V_max), V_min);
    
end

%=================================================
% Fractional Short Circuit Current (FSCC) - Advanced
%=================================================

function V_ref = MPPT_FSCC(I_pv, I_sc, varargin)
    % MPPT_FSCC Fractional Short Circuit Current Method
    % Vmpp ≈ k * Voc
    % Since measuring Voc is impractical, use:
    % Vmpp ≈ k * (Isc/Iph) where k ≈ 0.76 for most panels
    
    if nargin < 3
        k = 0.76;  % Fraction factor
    else
        k = varargin{1};
    end
    
    % Approximate Vmpp
    V_ref = k * (I_sc / I_pv) * 35;  % Assuming Voc ≈ 42V
    
end

%=================================================
% Test Script for MPPT Algorithms
%=================================================

if strcmp(mfilename('fullpath'), which('MPPT_Controller'))
    % This runs when file is executed directly
    
    clear; clc;
    
    % Test conditions
    V_pv = linspace(20, 45, 100);
    I_pv = 7.5 * (1 - ((V_pv - 35)/35).^2);  % Simplified I-V curve
    P_pv = V_pv .* I_pv;
    
    % Find true MPP
    [P_max, idx_mpp] = max(P_pv);
    V_mpp_true = V_pv(idx_mpp);
    
    % Simulate MPPT
    V_ref = 25;  % Starting point
    P_prev = 0;
    V_track = [];
    
    for k = 2:length(V_pv)
        V_track = [V_track, V_ref];
        I_current = 7.5 * (1 - ((V_ref - 35)/35)^2);
        P_current = V_ref * I_current;
        V_ref = MPPT_PO(V_ref, I_current, P_prev, V_ref, 0.5);
        P_prev = P_current;
    end
    
    % Plot results
    figure('Position', [100 100 1200 400]);
    
    % P-V curve
    subplot(1, 3, 1);
    plot(V_pv, P_pv, 'b-', 'LineWidth', 2); hold on;
    plot(V_track, 7.5 * (1 - ((V_track - 35)/35).^2) .* V_track, 'r*-', 'LineWidth', 1.5);
    plot(V_mpp_true, P_max, 'go', 'MarkerSize', 10, 'LineWidth', 2);
    xlabel('جهد PV (V)', 'FontSize', 11);
    ylabel('قوة PV (W)', 'FontSize', 11);
    title('منحنى P-V وتتبع MPPT', 'FontSize', 12);
    legend('منحنا P-V النظري', 'تتبع MPPT', 'نقطة القوة العظمى');
    grid on;
    
    % Voltage tracking
    subplot(1, 3, 2);
    plot(1:length(V_track), V_track, 'r-', 'LineWidth', 2); hold on;
    plot(1:length(V_track), V_mpp_true * ones(1, length(V_track)), 'g--', 'LineWidth', 2);
    xlabel('عدد التكرارات', 'FontSize', 11);
    ylabel('جهد PV (V)', 'FontSize', 11);
    title('التقب بالجهد', 'FontSize', 12);
    legend('مرجع ملي القابلية', 'القيمة الحقيقية');
    grid on;
    
    % Efficiency
    P_track = 7.5 * (1 - ((V_track - 35)/35).^2) .* V_track;
    efficiency = (P_track / P_max) * 100;
    subplot(1, 3, 3);
    plot(1:length(efficiency), efficiency, 'b-', 'LineWidth', 2);
    ylim([90, 102]);
    xlabel('عدد التكرارات', 'FontSize', 11);
    ylabel('كفاءة MPPT (%)', 'FontSize', 11);
    title('كفاءة MPPT', 'FontSize', 12);
    grid on;
    hold on; plot([1, length(efficiency)], [95, 95], 'r--', 'LineWidth', 1.5);
    legend('الكفاءة', 'الحد الأدنى (95%)');
    
    sgtitle('مبادلة MPPT - Perturb & Observe', 'FontSize', 14, 'FontWeight', 'bold');
    
end
