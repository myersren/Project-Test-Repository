% Figure Generator script
%       Script to plot simulation results across all VP variants/treatments
%       Allows user to generate custom overlay plots or export all plots as 
%       .fig files to directory folder 
%       Must be used in conjunction with SimulationAnalysisScript
% 
%       Inputs: SimDataStruct, SimulationDir
%
%       Modified by Renee Myers
%       Revised: 11-20-2020

%       See also SimulationAnalysisScript, SaveThisFigure, FormatThisFigure
%
%%  Error Bar Data File Input
% Error bar data: Must be as (.xls) or (.xlsx) only
% Data file format: 
% - Each worksheet must represent a separate experiment
% - Each column must represent a separate species
% - Time values must be in the leftmost column, followed by mean values,
%   followed by standard deviation values
%
% Example: 
% Worksheet Title: Experiment 1
% Time  Species_1  Species_N  Species_1_SD  Species_N_SD  
%  0        319        224         0.3           0.01     
%  24       --          --          --            --
%  ...      --          --          --            --    
%  672      --          --          --            --    
% 
%% Preamble
clear variables; close all; clc;

%% A. VP/Dose Plots
%% User Custom Plot Selection
%----------------------EDIT BELOW-------------------------------%

% Select 1 ('on') or 0 ('off') to select plot types to generate

IndividualVPPlots = 1; % Make individual VP plots for each VP/species
IndividualDosePlots = 0; % Make individual dose plots for each dose/species
AllVPsOnPlot = 1; % One dose per plot, compare across all VPs
AllDosesOnPlot = 0; % One VP per plot, compare across all doses

%----------------------END EDIT---------------------------------%

%% Create Directory to Save Files
% Find the .mat file containing the simulation results
SimulationData_Filename = '';

% Use the UI to find the .mat file 
if ~exist(SimulationData_Filename,'file')
    [filename, pathname, filterindex] = uigetfile('*.mat','Select data file to analyze');
    SimulationData_Filename = [pathname filename];
    fprintf(['To avoid using the GUI again, copy:\n\n', ...
            'SimulationData_Filename = ''%s'' \n\n' ...
            'and paste into line 30\n'],SimulationData_Filename)
end

% Load file(s) into workspace
load(SimulationData_Filename)

% Load experimental data file into workspace (for error bars) if present
ExperimentalData_Filename = '';
expData = questdlg('Would you like to load experimental data into the workspace to generate error bars?','Load experimental data','Yes','No','No');
switch expData
    case 'Yes'
        % Use the UI to find experimental data excel sheets
        if ~exist(ExperimentalData_Filename,'file')
            [expData_filename, expData_pathname, expData_filterindex]= uigetfile({'*.xlsx';'*.xls'},'Select experimental data to analyze');
            ExperimentalData_Filename = [expData_pathname expData_filename];
        end
end

% Set up directories to save figures
FigureSaveDir = [SimulationDir '/Figures/'];
if ~exist(FigureSaveDir,'dir')
    mkdir(FigureSaveDir)
end

% Make subfolders for .fig, .png, and 'All Plots'
FigureSaveDir_figs = [FigureSaveDir '/.fig files/'];
FigureSaveDir_pngs = [FigureSaveDir '/.png files/'];
FigureSaveDir_allfigs = [FigureSaveDir '/All Plots/'];

figure_subfolders = {FigureSaveDir_figs; FigureSaveDir_pngs; FigureSaveDir_allfigs};

for i = 1:length(figure_subfolders)
    if ~exist(figure_subfolders{i},'dir')
        mkdir(figure_subfolders{i});
    end
end

figNum = 1;

%% Manual User Input - VP & Dose Plots
% Manually type plot specs if desired 
% (**PREFERRED TO USE GUI BELOW INSTEAD**)

%----------------------EDIT BELOW-------------------------------%
% VP Plots (All VPs, Single Dose)
VPSpeciestoPlot = {};
Dose = {};
yAxisLabelsVP = {}; % Create y-axis labels for each species plot

% Dose Plots (All Doses, Single VP)
DoseSpeciestoPlot = {};
VP_Variant = {};
yAxisLabelsDose = {}; %Create y-axis labels for each species plot

%----------------------END EDIT -----------------------------------%

%% GUI User Input
% Select plot specs using GUI
guiInput = questdlg('Use GUI to select plot input fields?');

AllDoses = unique({SimDataStruct.Dose});
AllVariants = unique({SimDataStruct.Variant});
AllSpeciesNames = SimDataStruct(1).RunData.DataNames;
    
switch guiInput
    case 'Yes'
    % Set up prompts 
    VPPrompt = sprintf('Select all species for VP plots:\n(Ctrl-Click to select multiple)');
    DosePrompt = sprintf('Select all species for dose plots:\n(Ctrl-Click to select multiple)');
    listSize = [300 300];
    
    % VP Plots (All VPs, Single Dose)
    if IndividualVPPlots || AllVPsOnPlot    
        VPSpeciestoPlot = {AllSpeciesNames{listdlg('ListString', AllSpeciesNames, 'PromptString',VPPrompt,'SelectionMode','multiple', 'ListSize',listSize)}};  
        Dose = AllDoses(listdlg('ListString',AllDoses','PromptString', 'Select single dose for VP plots:', 'SelectionMode','single','ListSize',listSize));
    end
    
    % Dose Plots (All Doses, Single VP)
    if IndividualDosePlots || AllDosesOnPlot 
        DoseSpeciestoPlot = {AllSpeciesNames{listdlg('ListString', AllSpeciesNames,'PromptString', DosePrompt, 'SelectionMode','multiple','ListSize',listSize)}};  
        VP_Variant = AllVariants(listdlg('ListString', AllVariants','PromptString','Select single VP for dose plots:', 'SelectionMode','single','ListSize',listSize));
    end
    
    % Y axis labels
    yAxisSelect = questdlg('Use species names for Y axis labels ("Auto") or input all y axis labels manually ("Manual")?',...
                            'Y Axis Labels', 'Auto', 'Manual', 'Auto');
    switch yAxisSelect
        case 'Auto'
             yAxisLabelsVP = {VPSpeciestoPlot};
             yAxisLabelsDose = {DoseSpeciestoPlot};
        case 'Manual'
             yAxisLabelsVP = {inputdlg(generateYAxisPrompt(VPSpeciestoPlot),'Y Axis')};
             yAxisLabelsDose = {inputdlg(generateYAxisPrompt(DoseSpeciestoPlot),'Y Axis')};
    end
end

%% Get Plot Information from User

%Select time units of existing plot
timesList = {'Months', 'Weeks', 'Days', 'Hours', 'Minutes'};       
timeUnit = timesList{listdlg('PromptString',[{'Select time units of simulation data:'},{''}], 'ListString', timesList, 'SelectionMode', 'single')};

% Set custom legend position if desired
setLegendPosition = questdlg('Set custom legend position for plots? (Default position = "best")');
    switch setLegendPosition
        case 'Yes'
            lgdOptions = {'north','south','east','west','eastoutside','westoutside','best'};
            legendPosition = lgdOptions{listdlg('PromptString','Select location for legend','ListString',lgdOptions)};
        case 'No'
            legendPosition = 'best';
    end
    
%% Set up error bars in data structure
switch expData
    case 'Yes'
        SimDataStruct = ConfigureErrorBars(ExperimentalData_Filename, SimDataStruct);
end

%% Plot across all VPs (Single Dose)
% 1. Make individual plots for each species/VP
if IndividualVPPlots
   for i = 1:length(VPSpeciestoPlot)
        %Extract runs with the desired dose from data structure
        DosesStruct = ExtractfromStruct(SimDataStruct,'Dose', Dose);

        % Make a plot for selected species at each VP
        for VPIdx = 1:length(DosesStruct)
            GeneratePlot(VPSpeciestoPlot{i},DosesStruct(VPIdx),'Variant',figure_subfolders,yAxisLabelsVP{1}{i}, timeUnit, legendPosition, figNum, filename, '');        
            figNum = figNum + 1;
        end
   end
end

% 2. Plot all VPs on one plot for selected species
if AllVPsOnPlot
    for i = 1:length(VPSpeciestoPlot)
        %Extract runs with the desired dose from data structure
        DosesStruct = ExtractfromStruct(SimDataStruct,'Dose', Dose);

        % Make a plot for selected species at each VP
        GeneratePlot(VPSpeciestoPlot(i),DosesStruct,'Variant',figure_subfolders,yAxisLabelsVP{1}{i}, timeUnit,legendPosition, figNum, filename, '');        
        figNum = figNum + 1;
    end
end

%% Plot across doses (Single VP)
% 3. Make individual plots for each species/dose
if IndividualDosePlots
   for i = 1:length(DoseSpeciestoPlot)
        %Extract runs with the desired dose from data structure
        VPStruct = ExtractfromStruct(SimDataStruct,'Variant', VP_Variant);

        % Make a plot for selected species at each VP
        for DoseIdx = 1:length(VPStruct)
            GeneratePlot(DoseSpeciestoPlot{i},VPStruct(DoseIdx),'Dose',figure_subfolders,yAxisLabelsDose{1}{i},timeUnit, legendPosition, figNum, filename, '');        
            figNum = figNum + 1;
        end
   end
end

% 4. Plot all doses on one plot for selected species
if AllDosesOnPlot
    for i = 1:length(DoseSpeciestoPlot)
        %Extract runs with the desired dose from data structure
        VPStruct = ExtractfromStruct(SimDataStruct,'Variant', VP_Variant);

        % Make a plot for selected species at each VP
          GeneratePlot(DoseSpeciestoPlot(i),VPStruct,'Dose',figure_subfolders,yAxisLabelsDose{1}{i},timeUnit, legendPosition, figNum, filename,'');        
          figNum = figNum + 1;
    end
end
%% B. Overlay Plots
%% Make Overlay Plots (Multiple Species for One VP/Dose)

% Make custom overlay plots to co-plot multiple species, doses, or variants
% Use GUI to cycle through desired plot combinations

guiInput = questdlg('Use GUI to make overlay plots (multiple variants/doses/species)?');
switch guiInput
case 'Yes'
    % Loop over the desired number of overlay plots
    numPlots = str2double(inputdlg('How many overlay plots?'));
    for i = 1:numPlots
        featureSelect = questdlg('Overlay multiple species, variants, or doses?', ...
                          'Select feature to overlay', 'Species', 'Variants', 'Doses', 'Species');
        % Clear existing variables
        clear Dose VP_Variant

        % Get lists of all doses, variants, and species
        AllDoses = unique({SimDataStruct.Dose});
        AllVariants = unique({SimDataStruct.Variant});
        AllSpeciesNames = SimDataStruct(1).RunData.DataNames;
        listSize = [300 300];
         
        % Select features to include in plot (species, variants, or doses)
        switch featureSelect
            case 'Species'
                OverlaySpeciestoPlot = {AllSpeciesNames{listdlg('ListString',AllSpeciesNames,'PromptString','Select species (Ctrl-Click):','SelectionMode','multiple', 'ListSize',listSize)}};
                Dose = AllDoses(listdlg('ListString', AllDoses','PromptString', 'Select dose:', 'SelectionMode','single', 'ListSize',listSize));
                VP_Variant = AllVariants(listdlg('ListString', AllVariants','PromptString', 'Select VP:', 'SelectionMode','single', 'ListSize',listSize));
            case 'Variants'
                OverlaySpeciestoPlot = {AllSpeciesNames{listdlg('ListString',AllSpeciesNames,'PromptString','Select single species:','SelectionMode','single', 'ListSize',listSize)}};
                Dose = AllDoses(listdlg('ListString', AllDoses','PromptString', 'Select dose:', 'SelectionMode','single', 'ListSize',listSize));
                VP_Variant = AllVariants(listdlg('ListString', AllVariants','PromptString', 'Select VPs (Ctrl-Click):', 'SelectionMode','multiple', 'ListSize',listSize));
            case 'Doses'
                OverlaySpeciestoPlot = {AllSpeciesNames{listdlg('ListString',AllSpeciesNames,'PromptString','Select species:','SelectionMode','single', 'ListSize',listSize)}};
                Dose = AllDoses(listdlg('ListString', AllDoses','PromptString', 'Select doses (Ctrl-Click):', 'SelectionMode','multiple', 'ListSize',listSize));
                VP_Variant = AllVariants(listdlg('ListString', AllVariants','PromptString', 'Select VP:', 'SelectionMode','single','ListSize',listSize));
        end
        
        % Generate plots
        Struct = ExtractfromStruct_OverlayPlots(SimDataStruct, featureSelect, VP_Variant, Dose);
        yAxisLabel = '';
        GenerateOverlayPlot(OverlaySpeciestoPlot,Struct,featureSelect, timeUnit, legendPosition, figure_subfolders,yAxisLabel,figNum, filename)
        figNum = figNum + 1;
    end
end

%% C. Bulk Plotting
%% Generate all plots (VP, dose) across all species
guiInput = questdlg('Generate all plots?');
switch guiInput
    case 'Yes'
        AllSpecies = SimDataStruct(1).RunData.DataNames;
        for k = 1:length(SimDataStruct)
            parfor i = 1:length(AllSpecies)
                yAxisLabel = AllSpecies{i};
                GeneratePlot(AllSpecies{i},SimDataStruct(k),'',figure_subfolders,yAxisLabel,timeUnit, legendPosition, i+figNum, filename, 'AllPlots');              
            end
            figNum = length(AllSpecies)+figNum;
        end
end

%% Script Functions
%% A. All Dose/All VP Plotting Functions
%% Struct Generation Function
function newStruct = ExtractfromStruct(SimDataStruct,FieldName, DoseOrVPName)   
        newStruct = SimDataStruct(strcmp({SimDataStruct.(FieldName)},DoseOrVPName));     
end

%% Plotting Function 
function GeneratePlot(SpeciestoPlot,Struct,VarOrDosePlot, figure_subfolders,yAxisLabel, timeUnit, legendPosition, figNum, filename, varargin)
    % GeneratePlot - Generates and saves formatted plot for a single
    %                species. Plots for a single VP/dose or across all 
    %                VPs/doses for the selected species. 
    %
    % Naming Conventions 
    %       Figure Name: VPName, DoseName, SpeciesName (individual)
    %                    DoseName_SpeciesName_AllVPs || VPName_SpeciesName_AllDoses
    %       Figure Title:VPName, DoseName (individual) 
    %                    VPName || DoseName 
    %       Legend:      VPName1, VPName2, ... || DoseName1, DoseName2, ...
    
    % Set up figure/axis information
    fig = figure(figNum);
    ax = gca;
    
    % Loop over all VPs or doses 
    for i = 1:length(Struct) 
        time = Struct(i).RunData.selectbyname(SpeciestoPlot).Time; 
        speciesData = Struct(i).RunData.selectbyname(SpeciestoPlot).Data;   
        linehandles(i) = plot(time,speciesData);
        hold on
    end
    
    % Figure Name & Title
    if length(Struct) > 1 % All VPs/all doses
        if strcmp(VarOrDosePlot, 'Variant')
            figName = [Struct(1).Dose '_' char(SpeciestoPlot) '_AllVPs'];
            title = Struct(1).Dose;
        elseif strcmp(VarOrDose, 'Dose')
            figName = [Struct(1).Variant '_' char(SpeciestoPlot) '_AllDoses'];
            title = Struct(1).Variant;
        end
    end
    
    if length(Struct) == 1 % Individual plots
        figName = [Struct(1).Variant ', ' Struct(1).Dose ', ' char(SpeciestoPlot)];
        title = [Struct(1).Dose ', ' Struct(1).Variant];
    end
    
    set(ax.Title, 'String', title,'interpreter','none');
    set(fig, 'name', figName);
    
    % Plot legend
    if length(Struct) > 1
        for i = 1:length(Struct)
            lgdEntry = sprintf([Struct(i).(VarOrDosePlot)]);
            lgd{i} = lgdEntry;
        end
        legend(lgd, 'location',legendPosition,'interpreter','none');
    else
        legend('hide');
    end
    
    % Format Y Axis
    ylabel(yAxisLabel)
    set(ax.YAxis, 'TickLabelFormat', '%0.2g');
    set(ax.YAxis.Label, 'Interpreter', 'none');
 
    % Format X Axis
    scaleXAxis(timeUnit);

    % Apply formatting
    addCaption(Struct, filename)
    FormatThisFigure
    
    % Plot error bars if present
    set(0,'DefaultLegendAutoUpdate','off');
    errorBars = PlotErrorBars(Struct, SpeciestoPlot, linehandles);

    % Save figures to simulation results directory
    if ~isempty(varargin{:}) && strcmpi(varargin{:}, 'AllPlots') % Saves to 'all plots' folder
       savefig([figure_subfolders{3} figName]);
    else
       savefig([figure_subfolders{1} figName]);
       SaveThisFigure(figure_subfolders{2}, figName);
    end

end

%% X Axis Automatic Scaling Function
function scaleXAxis(timeUnit)
    try 
    % Get current axis
    ax = gca; 

    % Automatically scale the x axis 
    timeUnitLabels = {'Months','Weeks','Days','Hours', 'Minutes'};
    timeIndex = find(strcmpi(timeUnitLabels, timeUnit));
    hourScale = [672, 168, 24, 1 (1/60)];

    % Convert units to hours
    SimEndTime = ax.Children(1).XData(end);
    numHours = SimEndTime*hourScale(timeIndex);
    
    % Store times
    numMinutes = numHours*60;
    numDays = numHours/24;
    numWeeks = numDays/7;
    numMonths = numWeeks/4;

    times = [numMonths, numWeeks, numDays, numHours, numMinutes];
    
    % Find the largest appropriate time unit for the x axis
    for i = 1:length(times)
        if rem(times(i),1) == 0 && ~mod(times(i),4)
            bestTimeUnit = timeUnitLabels{i};
            endTime = times(i);
            break;
        end
    end

    if ~exist('endTime') && ~exist('bestTimeUnit')
        endTime = SimEndTime;
        bestTimeUnit = timeUnitLabels{timeIndex};
    end
    
    set(ax,'XTick',linspace(0,SimEndTime,5));
    set(ax, 'XTickLabel',linspace(0,endTime,5));

    % Set default x axis label
    xLabel = sprintf('Time (%s)', bestTimeUnit);
    set(ax.XLabel, 'String', xLabel);
    catch
        disp('Axis scaling error. Scale x axis manually')
    end  
end
%% Add Caption Function
function addCaption(Struct, filename)
    
    VP_Names = unique({Struct.Variant});
    Dose_Names = unique({Struct.Dose});

    Doses = ['Dose: ' sprintf('%s ', Dose_Names{:})];
    VP_Vars = ['VP Variant: ' sprintf('%s ', VP_Names{:})];

    if isfield(Struct, 'RunInfo') & ~strcmp(Struct(1).RunInfo, '')
       Additional_Info = Struct(1).RunInfo;
    end  

    if length(VP_Names) > 1
        VP_Vars = '';
    end 
    if length(Dose_Names) > 1
        Doses = '';
    end
    
    ax = gca;
    set(ax, 'Units','normalized','Position', [0.15 0.33 0.775 0.57]);
    set(ax.XLabel, 'Units', 'normalized','Position',[0.5 -0.16 -1]);

    annotateString = sprintf('Rosa and Co LLC. Filename: %s %s %s %s',...
        filename,VP_Vars, Doses, Additional_Info);

        %Set the position [left bottom width height] for the caption.
        dim = [0.08 0 0.9 0.08];
        caption = annotation('textbox', dim,'String',annotateString, 'VerticalAlignment','bottom');

        %Modify the properties of the annotation box.
        set(caption, 'FontName','Calibri','FontSize',10,...
            'LineStyle','none','VerticalAlignment','bottom',...
            'HorizontalAlignment','left','Interpreter','none');
end

function prompts = generateYAxisPrompt(SpeciestoPlot)
    numPrompts = length(SpeciestoPlot);
    for i = 1:numPrompts
        prompts{i} = sprintf('Y Axis Label & Units (%s): ',SpeciestoPlot{i});
    end 
end
%% B.  Error Bar Functions
%% Configure Error Bars
function SimDataStruct = ConfigureErrorBars(filename, SimDataStruct)
sheetNames = cellstr(sheetnames(filename));
% Read in excel data
for k = 1:length(sheetNames)
    [num, txt, raw] = xlsread(filename, sheetNames{k});
    AllNames{:,:,k} = txt;
    AllData{:,:,k} = num;
end

% Have user select sheets containing relevant experimental data
prompt = [{'Select all sheets containing data to match with simulation runs:'},{''},{''}];
errorData = sheetNames(listdlg('PromptString',prompt,'ListString',sheetNames,'SelectionMode','multiple'));

% Have user match data in excel file to simulation runs
for i = 1:length(errorData)
    txtPrompts{i} = [sprintf('Run index # for %s',errorData{i})];
end

% Allow the user to view the run #, VP, and dose information if desired 
viewInfo = questdlg('Would you like to view the run index/dose/variant information?',...
                     'Yes','No');
switch viewInfo
    case "Yes"
        vars = {'Run Number', 'VP Variant', 'Dose', 'Additional Info'};
        for m = 1:length(SimDataStruct)
            runNums(:,m) = sprintf("Run %s",num2str(m));
        end
        tableInfo = table(runNums', {SimDataStruct.Variant}', {SimDataStruct.Dose}',{SimDataStruct.RunInfo}','VariableNames',vars);
        uifig = uifigure;
        runsTable = uitable(uifig, 'Data', tableInfo);
        uifig.Position = [350 180 450 500];
        runsTable.Position = [25 25 400 450];
        uifig.Name = "Runs Info";
        uiwait(msgbox('Once you have finished identifying run index numbers, click "ok" to proceed:','View run info','modal'));
end

% Prompt the user to input run index information for each excel sheet
try
    runIndicies = cellfun(@str2num, inputdlg(txtPrompts, 'Enter numerical value of run index')); % Convert to integers
catch
    warndlg('Make sure to input numerical index values for all sheets.')
    runIndicies = cellfun(@str2num, inputdlg(txtPrompts, 'Enter numerical value of run index'));
end

% Separate out the error bar/stdev data on each sheet; parse through the
% column names until the species names repeat for the standard deviation
% values
try
    for m = 1:length(AllNames)
        
        % Set default assuming only experimental data
        endMeans(m) = length(AllNames{m});
        startStdevs(m) = 0;
            
        for i = 3:length(AllNames{m})
            speciesName = AllNames{m}{2};
            if contains(AllNames{m}{i},speciesName)
                endMeans(m) = i-1
                startStdevs(m) = i
                break
            end
        end
    end
    endMeans
    startStdevs
% Assign error data (time, mean,stdev) to SimDataStruct
for i = 1:length(runIndicies)
    expData = AllData(:,:,i);
    nameData = AllNames(:,:,i);
    
    SimDataStruct(runIndicies(i)).ErrorData.time = expData{1}(:,1);
    SimDataStruct(runIndicies(i)).ErrorData.mean = expData{1}(:,(2:endMeans(i)));
    SimDataStruct(runIndicies(i)).ErrorData.species = nameData{1}(:,(2:endMeans(i)));
    
    if startStdevs(i)
        SimDataStruct(runIndicies(i)).ErrorData.stdev = expData{1}(:,(startStdevs(i):end));
    else
        SimDataStruct(runIndicies(i)).ErrorData.stdev = [];
    end
end

catch
    warndlg(['Species names must match for mean and standard deviation values '...
        'and both mean and standard deviation values must be included. '...
        'Please refer to the template for more information.'])
end

end

%% Plot Error Bars
function errorBars = PlotErrorBars(Struct, SpeciestoPlot, linehandles)
for i = 1:length(Struct)
    if ~isempty(Struct(i).ErrorData.time)
            % Species index information
            AllSpecies = Struct(i).ErrorData.species;
            try
                [~,speciesIdx] = ismember(SpeciestoPlot, AllSpecies);
                assert(~isequal(speciesIdx, 0));
            catch
                warndlg('Species names are not consistent. Please input manually.')
                speciesIdx = listdlg('PromptString', ['Please find the entry corresponding to '...
                        SpeciestoPlot ' in the list below:'], 'ListString', AllSpecies,...
                        'ListSize', [400 400]);
            end
            % Plot error bars
            x = Struct(i).ErrorData.time(:,1); 
            y = Struct(i).ErrorData.mean(:,speciesIdx);
            if ~isempty(Struct(i).ErrorData.stdev)
                err = Struct(i).ErrorData.stdev(:,speciesIdx);
            else
                err = [];
            end
            errorBars = errorbar(x,y,err);
            hold on
            
            % Set error bar properties
            set(errorBars,'LineStyle','none','Marker','o','MarkerSize',5,'Color',linehandles(i).Color,'LineWidth',3);
    else
        errorBars = [];     
    end
end
end
%% C. Overlay Plotting Functions
%% Struct Generation - Overlay Plots
function newStruct = ExtractfromStruct_OverlayPlots(SimDataStruct, featureSelect, Variants, Doses)   
    switch featureSelect
        case 'Species'
            newStruct = SimDataStruct(strcmp({SimDataStruct.Variant},Variants) & strcmp({SimDataStruct.Dose},Doses));
        case 'Variants'
            for i = 1:length(Variants)
                newStruct(i) = SimDataStruct(strcmp({SimDataStruct.Variant},Variants(i))& strcmp({SimDataStruct.Dose},Doses));
            end
        case 'Doses'
            for i = 1:length(Doses)
                newStruct(i) = SimDataStruct(strcmp({SimDataStruct.Dose},Doses(i)) & strcmp({SimDataStruct.Variant},Variants));
            end
    end
end

%% Plotting Function - Overlay Plots
function GenerateOverlayPlot(SpeciestoPlot,Struct,featureSelect, timeUnit, legendPosition,figure_subfolders,yAxisLabel,figNum, filename)
    fig = figure(figNum);
    SimEndTime = Struct(1).RunData.Time(end);
    ax = gca;
 
    switch featureSelect
        case 'Species'
            for i = 1:length(SpeciestoPlot)
                time = Struct.RunData.selectbyname(SpeciestoPlot{i}).Time; 
                speciesData = Struct.RunData.selectbyname(SpeciestoPlot{i}).Data;   
                linehandles(i) = plot(time,speciesData);
                hold on
                
                lgd{i} = SpeciestoPlot{i};
                figName = [Struct.Variant ', ' Struct.Dose ];
                set(ax.Title, 'String', [Struct(1).Variant ', ' Struct(1).Dose],'interpreter','none');
            end
     
        case 'Variants'
            for i = 1:length(Struct)
                time = Struct(i).RunData.selectbyname(SpeciestoPlot{1}).Time; 
                speciesData = Struct(i).RunData.selectbyname(SpeciestoPlot{1}).Data;   
                linehandles(i) = plot(time,speciesData);
                hold on
                
                lgd{i} = Struct(i).Variant;
                ylabel(char(SpeciestoPlot));
                figName = [Struct(i).Dose ', ' char(SpeciestoPlot)];
                set(ax.Title, 'String', Struct(1).Dose,'interpreter','none');
            end
       
        case 'Doses'
             for i = 1:length(Struct)
                time = Struct(i).RunData.selectbyname(SpeciestoPlot{1}).Time; 
                speciesData = Struct(i).RunData.selectbyname(SpeciestoPlot{1}).Data;   
                linehandles(i) = plot(time,speciesData);
                hold on
                ylabel(char(SpeciestoPlot));
                figName = [Struct(i).Variant ', ' char(SpeciestoPlot)];
                set(ax.Title, 'String', Struct(1).Variant,'interpreter','none');
             end     
             
            % Order doses legend by value of dose instead of alphabetical order
            for i = 1:length(Struct)
                matchCriteria = '\d*+[a-z]+g';
                extractDose = regexp(Struct(i).Dose,matchCriteria, 'match');
                if isempty(extractDose)
                    extractDose = Struct(i).Dose;
                    doseVal(i,1) = 0;
                    doseVal(i,2) = i;
                else
                    doseVal(i,1) = str2double(regexp(extractDose{:},'\d*','match'));
                    doseVal(i,2) = i;
                end
            end
                [sortedDoses, order] = sort(doseVal(:,1));
                lgd = {Struct(order).Dose};
    end
    
    % Legend/Title/Figure Name
    legend(lgd, 'location',legendPosition,'interpreter','none');  
    set(fig, 'name', figName);
   
    % Y Axis specs
    ax = gca;
    set(ax.YAxis, 'TickLabelFormat', '%0.2g');
    set(ax.YAxis.Label, 'interpreter','none')

 
    % Time Units/X Axis specs
    scaleXAxis(timeUnit);

    % Apply formatting
    addCaption(Struct, filename)
    FormatThisFigure
    
    % Plot error bars if present
    set(0,'DefaultLegendAutoUpdate','off');
    errorBars = PlotErrorBars(Struct, SpeciestoPlot, linehandles);
    
    % Save figures to simulation results directory
    savefig([figure_subfolders{1} figName]);
    SaveThisFigure(figure_subfolders{2}, figName);
end