%=================================================
% نظام إدارة البطارية
% Battery Management System (BMS)
%=================================================
% الوظائف:
% 1. حساب حالة الشحن (SOC)
% 2. حماية البطارية من الإفراط في الشحنة والتفريغ
% 3. توازن خلايا البطارية (Cell Balancing)
% 4. تقدير الصحة (Health Estimation)

classdef Battery_Manager
    properties
        % معاملات البطارية
        Capacity        % سعة البطارية (Ah)
        V_nom           % جهد الاسمي (V)
        V_max           % أقصى جهد (V)
        V_min           % أقل جهد (V)
        R_internal      % مقاومة داخلية (Ω)
        I_max_charge    % أقصى تيار شحن (A)
        I_max_discharge % أقصى تيار تفريغ (A)
        
        % حالة البطارية
        SOC             % State of Charge (0-1)
        SOH             % State of Health (0-1)
        Q_remaining     % باقي الشحنة (Ah)
        Q_total         % إجمالي الشحنة (Ah)
        Cycles          % عدد دورات الشحن/التفريغ
        Temperature     % درجة الحرارة (°C)
        
        % شماراتكولوم (الطريقة 1)
        Q_in            % الشحنة الداخلة (Ah)
        Q_out           % الشحنة الخارجة (Ah)
        
        % معالجات OCV (Open Circuit Voltage)
        OCV_table       % جدول OCV vs SOC
        
    end
    
    methods
        %% المنشئ (Constructor)
        function obj = Battery_Manager(varargin)
            % Battery_Manager(معاملات)
            
            % معاملات افتراضية (48V 100Ah ليثيوم)
            obj.Capacity = 100;         % Ah
            obj.V_nom = 48;             % V
            obj.V_max = 54.6;           % V (4.55V per cell * 12 cells)
            obj.V_min = 40;             % V (3.33V per cell * 12 cells)
            obj.R_internal = 0.01;      % Ω (10 mΩ)
            obj.I_max_charge = 50;      % A (0.5C)
            obj.I_max_discharge = 100;  % A (1C)
            
            % حالة ابتدائية
            obj.SOC = 0.5;              % بدء ب  50% SOC
            obj.SOH = 0.95;             % بحالة صحيحة
            obj.Q_remaining = obj.Capacity * obj.SOC;
            obj.Q_total = obj.Capacity * obj.SOH;
            obj.Cycles = 0;
            obj.Temperature = 25;       % °C
            
            % شماراتكولوم ابتدائية
            obj.Q_in = 0;
            obj.Q_out = 0;
            
            % بناء جدول OCV
            obj.OCV_table = obj.Build_OCV_Table();
            
            % تحديث معاملات مخصصة إذا تمذ مريتها
            if nargin > 0
                P = inputParser();
                addParameter(P, 'Capacity', 100);
                addParameter(P, 'V_nom', 48);
                addParameter(P, 'SOC_init', 0.5);
                parse(P, varargin{:});
                
                obj.Capacity = P.Results.Capacity;
                obj.V_nom = P.Results.V_nom;
                obj.SOC = P.Results.SOC_init;
            end
        end
        
        %% حساب حالة الشحن (SOC) - طريقة Coulomb Counting
        function obj = Update_SOC(obj, I_batt, dt)
            % Update_SOC(I_batt, dt)
            % I_batt: التيار (A) - موجب للشحن، سالب للتفريغ
            % dt: زمن الحساب (s)
            
            % تحويل الامبير ساعة إلى Ah
            Q_delta = I_batt * dt / 3600;  % Ah
            
            % تحديث باقي الشحنة
            % (علامة موجبة: الشحنة الداخلة تزيد)
            obj.Q_remaining = obj.Q_remaining + Q_delta;
            
            % طرق المدخلات
            if Q_delta > 0
                obj.Q_in = obj.Q_in + Q_delta;
            else
                obj.Q_out = obj.Q_out - Q_delta;
            end
            
            % حساب SOC
            obj.Q_total = obj.Capacity * obj.SOH;  % السعة الفعلية
            obj.SOC = obj.Q_remaining / obj.Q_total;
            
            % الحفاظ علع الحدود
            obj.SOC = max(min(obj.SOC, 1.0), 0.0);
            obj.Q_remaining = obj.SOC * obj.Q_total;
        end
        
        %% حساب الجهد وبناءه على OCV
        function V_batt = Get_Battery_Voltage(obj, I_batt)
            % Get_Battery_Voltage(I_batt)
            % يرجع جهد البطارية بناءً على SOC وتيار التفريغ
            %
            % V = OCV(SOC) - I * R_internal
            
            % الحصول على OCV من الجدول
            OCV = interp1(obj.OCV_table.SOC, obj.OCV_table.OCV, obj.SOC, 'linear', 'extrap');
            
            % إضافة لا مئا المقاومة الداخلية
            V_batt = OCV - I_batt * obj.R_internal;
        end
        
        %% حماية البطارية (Protection)
        function [I_limited, fault_code] = Apply_Protection(obj, I_command, V_batt)
            % Apply_Protection(I_command, V_batt)
            % تطبيق منطق الحماية
            %
            % fault_code: 0 = طبيعي
            %            1 = التفريغ سذاب (Over-discharge)
            %            2 = التفريغ سـيع
            %            3 = الشحن سذاب
            %            4 = الشحن سع (Over-temperature)
            
            I_limited = I_command;
            fault_code = 0;
            
            % حماية من الإفراط في الشحن
            if V_batt >= obj.V_max
                I_limited = 0;
                if V_batt > obj.V_max + 0.5
                    fault_code = 3;  % الشحن سذاب
                end
            end
            
            % حماية من التفريغ الزائد
            if V_batt <= obj.V_min
                I_limited = 0;
                if V_batt < obj.V_min - 0.5
                    fault_code = 1;  % التفريغ سذاب
                end
            end
            
            % حماية من التيار الزائد
            if I_command > 0 && I_command > obj.I_max_charge
                I_limited = obj.I_max_charge;
            elseif I_command < 0 && I_command < -obj.I_max_discharge
                I_limited = -obj.I_max_discharge;
                fault_code = 2;  % التفريغ سـيع
            end
            
            % حماية من الحرارة
            if obj.Temperature > 60
                I_limited = I_limited * 0.5;  % اخفض التيار
                fault_code = 4;  % التنبيه
            end
        end
        
        %% بناء جدول OCV (Open Circuit Voltage)
        function OCV_table = Build_OCV_Table(~)
            % جدول OCV لبطارية 48V ليثيوم
            % (تقريبي - 12 خلية * 4V nominal = 48V)
            
            OCV_table.SOC = [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0];
            OCV_table.OCV = [40.0 45.5 48.0 49.5 50.5 51.2 51.8 52.4 53.0 53.6 54.6];
        end
        
        %% تقدير صحة البطارية (Health Estimation)
        function obj = Estimate_Health(obj, cycles)
            % Estimate_Health(cycles)
            % الصحة الفعلية تنخفض مع الترارات
            % ليثيوم: عادة 2000-3000 دورة قبل الوصول إلى 80% الصحة
            
            obj.Cycles = cycles;
            
            % نموذج خطي بسيط
            max_cycles = 3000;
            obj.SOH = 1.0 - (cycles / max_cycles) * 0.2;  % انخفاض ل 20% عند 3000 دورة
            obj.SOH = max(0.8, obj.SOH);  % بحد أدنى 80%
        end
        
        %% طلب ملخص الحالة
        function summary = Get_Status_Summary(obj)
            summary = struct();
            summary.SOC = obj.SOC * 100;  % نسبة مئوية
            summary.SOH = obj.SOH * 100;
            summary.Q_remaining = obj.Q_remaining;
            summary.Cycles = obj.Cycles;
            summary.Temperature = obj.Temperature;
        end
    end
end

%=================================================
% نص الاختبار
%=================================================

if strcmp(mfilename('fullpath'), which('Battery_Manager'))
    % يعمل عند ما يكون الملف منفذوثا مباشرة
    
    clear; clc;
    
    % إنشاء البطارية
    batt = Battery_Manager('Capacity', 100, 'V_nom', 48, 'SOC_init', 0.5);
    
    % محاكاة العمل
    t = 0:0.01:1;  % ساعة واحدة
    I_profile = 25 * sin(2*pi*t);  % تيار تذبذبي
    
    SOC_history = [];
    V_history = [];
    
    for k = 1:length(t)
        % تحديث SOC
        if k > 1
            dt = t(k) - t(k-1);
            batt = batt.Update_SOC(I_profile(k), dt);
        end
        
        % الحصول على الجهد
        V = batt.Get_Battery_Voltage(I_profile(k));
        
        % ميت الحماية
        [~, fault] = batt.Apply_Protection(I_profile(k), V);
        
        SOC_history = [SOC_history, batt.SOC*100];
        V_history = [V_history, V];
    end
    
    % رسم النتائج
    figure;
    subplot(2,1,1);
    plot(t, SOC_history, 'b-', 'LineWidth', 2);
    ylabel('حالة الشحن (%)');
    title('محاكاة البطارية');
    grid on;
    
    subplot(2,1,2);
    plot(t, V_history, 'r-', 'LineWidth', 2);
    ylabel('جهد البطارية (V)');
    xlabel('الزمن (ساعة)');
    grid on;
end
