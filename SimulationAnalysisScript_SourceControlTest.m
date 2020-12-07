% Simulation Analysis script
%       Script to simulate results across all VP variants/treatments
%
%       Simulation results are stored in a data structure (SimDataStruct)
%       and exported as a data file for later processing
%
%       Saves log file, backup copies of the script/project file,
%       MATLAB data file, and  excel workbooks containing simulation
%       results/variant data into directory folder
%
%       See also FigureGeneratorScript, xlswrite, sbiosimulate
%      
%   
%       Modified by Renee Myers
%       Revised: 11-20-2020

%% Preamble
close all, clear variables; clc

%% Descriptions of User Input Variables & Default Settings
% Variable Descriptions
%             ProjectFileName -  Full path and file name of SimBio project
%                                If unknown, can be copy/pasted from UI
%                                Ex: 'C:\Documents\...\SBioProject.sbproj'
%
%             ProjFolderName -   Desired folder name for simulation results
%                                Ex: 'GDF005 VP Runs'
%
%             SimDuration -      Total duration of simulation (6, 140, 24)
%   
%             SimTimeUnits -     Time units ('hours', 'days', 'weeks')
%           
%             Background_Variants - Background variants for the simulation
%                                   (to be applied to all runs)
%
%             Background_Doses - Background doses for the simulation
%                                 (to be applied to all runs)
%
%             VP_Variants -     Virtual patient variants (as named in .sbproj file)
%                               Ex: {'VP_1', 'VP_2', 'VP_3'}
%
%             VPLegend -        Names corresponding to VP variants
%                               Ex: {'VP 1', 'VP 2', 'VP 3'}
%
%             DosesLegend -     Names corresponding to dose variants
%                               Ex: {'DV 1', 'DV 2', 'DV 3'}
%             
%             Doses       -     Doses/treatments applied to the simulation 
%                               ** Represent untreated/no dose by  '' **
%                               Ex: {'D1', 'D2', 'D3'}
%
%             Dose_Variants -   Dose variants applied to the simulation
%                               **Must have same # of dose variants as doses **
%                               Ex: {{'DV_1';'DV_2'},{'DV_1';'DV_2'},{'DV_3';'DV_2'}};
%
%             SpeciesToSave -   Model species to be saved in excel spreadsheet
%                               output (as named in .sbproj file)
%
% Structure Descriptions
%            SimDataStruct: Stores simulation info, indexed by run #
%                   RunData - SimData object with time(RunData.Time) & state
%                             (RunData.Data) simulation data
%                   Variant - VP Variant applied to selected run
%                   Dose    - Dose/treatment applied to selected run
%                   ErrorData - Data for error bars (time, mean, stdev)
%                               (generated from external spreadsheet)
%
%           SimData: Simulation data object, indexed by run #
%                  Data - Simulation data for all model species 
%                  DataNames - Names of model species (column names in data) 
%                  Time - Simulation time points 
%                  selectbyname - (Method) Select species to observe time/state data
%
% Default Configuration Settings
%
%             SolverType -      'ode15s'

%% Data Structure Usage Examples & Useful Commands 
% Using SimDataStruct 
% 1. Retrieve SimData object for all model species for run #1 of the simulation
%    >> SimDataStruct(1).RunData
%
% 2. Retrieve time data for all model species for run #1 of the simulation
%    >> SimDataStruct(1).RunData.Time
%
% 3. Retrieve state data for all model species for run #1 of the simulation
%    >> SimDataStruct(1).RunData.Data
%
% 4. Retrieve time/state data for an individual model species ('Example_Species') 
%    for run #1 of the simulation
%    >> SimDataStruct(1).RunData.selectbyname('Example_Species').Time
%    >> SimDataStruct(1).RunData.selectbyname('Example_Species').Data
%
% 5. Find the VP variant applied to run #4 of the simulation
%    >> SimDataStruct(4).Variant
%
% 6. Get all runs where the VP variant is 'Variant_1'
%    >> newStruct = SimDataStruct(strcmp({SimDataStruct.Variant},'Variant_1'))
%
% 7. Get new struct containing all runs where the dose applied is 'Dose_1'
%    >> newStruct = SimDataStruct(strcmp({SimDataStruct.Dose},'Dose_1'))
%
% 8. Get new struct containing the simulation run where the VP variant is 'VP_2' 
%    and the dose applied is 'Dose_1'
%    >> newStruct2 = SimDataStruct(strcmp({SimDataStruct.Variant},'VP_2') & strcmp({SimDataStruct.Dose},'Dose_1'))
%
% 9. Get time and state for a model species ('Example_Species') for the VP
%    variant/dose criteria in example #8
%    >> newStruct2.RunData.selectbyname('Example_Species').Time
%    >> newStruct2.RunData.selectbyname('Example_Species').Data
%
% 10. View all model species used in simulation (data column headers)
%     >> SimDataStruct(1).RunData.DataNames

 %% User Input Template
%----------------------------EDIT BELOW-----------------------------------%
ProjectFileName = '%Paste UI Output here or leave text to select using UI%'; 
ProjFolderName = '';

SimDuration = 672; 
SimEndTime = SimDuration;
SimTimeUnits = 'hours';

Background_Variants = {};
Background_Doses = {};

VP_Variants = {};
VPLegend = {};

Dose_Variants = {};
Doses =  {};
DosesLegend = {};

% Configuration Settings
absTolerance = 1e-6; 
relTolerance = 1e-6;
odeSolver = 'ode15s';
%----------------------------END EDIT-------------------------------------%

outputTimes = [];% Returns raw solver output

%% Step 1: Get the SimBiology project file

% Use UI to set model file name and path 
if ~exist(ProjectFileName,'file')
    [filename, pathname, filterindex] = uigetfile('*.sbproj','Select Simbiology project file to analyze');
    ProjectFileName = [pathname filename];
    fprintf(['To avoid using the GUI again, copy:\n\n', ...
            'ProjectFileName = ''%s'' \n\n' ...
            'and paste into "ProjectFileName" \n\n'],ProjectFileName)
end

%% Step 2: Import Simbiology model as a Simbiology model object

ModelInfo = sbioloadproject(ProjectFileName);
SimModelObj = ModelInfo.m1;
model = SimModelObj;

%% Step 3: User Input - Simulation Output Customization 
% Prompt 1: Select whether to record simulation details in a log file
saveinfo = questdlg('Would you like to generate a log file for the simulation?',...
    '(1/4) Save Log File',...
    'Yes','No','No');

% Prompt 2: Allow the user to downsample the simulation output times
solverOutput = questdlg('Would you like to downsample the solver output times?',...
    '(2/4) Specify solver output times',...
    'Yes','No','No');

     switch solverOutput
         case 'Yes'
            timeStart = str2double(cell2mat(inputdlg('Specify simulation start time: ')));
            timeStep = str2double(cell2mat(inputdlg('Specify time step for solver output: ')));
     end
     
% Prompt 3: Select whether to generate an excel spreadsheet for the data
generateExcel = questdlg('Would you like to generate an excel spreadsheet for the data?',...
    '(2/4) Generate Excel Output',...
    'Yes','No','No');

    switch generateExcel
        case 'Yes'
            if ~exist('timeStep')
                verifyExcel = questdlg('The excel spreadsheet feature requires user specified solver output times. Continue ("Yes") or use raw solver output times ("No")? If "No" is selected, no spreadsheet will be generated.',...
                    'Verify spreadsheet','Yes','No','No');
                switch verifyExcel
                    case 'No'
                        generateExcel = 'No';
                    case 'Yes'
                        timeStep = str2double(cell2mat(inputdlg('Specify time step for solver output: ')));
                        timeStart = str2double(cell2mat(inputdlg('Specify simulation start time: ')));
                        TimePoints = str2double(cell2mat(inputdlg('Specify number of points to save in spreadsheet output: ')));
                        ModelSpecies = {SimModelObj.Species.Name};
                        SpeciesToSave = {ModelSpecies{listdlg('PromptString', [{'Select species to save (Ctrl-Click to select multiple):'},{''}], 'ListString', ModelSpecies, 'ListSize',[300 300])}};
                end
            else
                TimePoints = str2double(cell2mat(inputdlg('Specify number of points to save in spreadsheet output: ')));
                ModelSpecies = {SimModelObj.Species.Name};
                SpeciesToSave = {ModelSpecies{listdlg('PromptString', [{'Select species to save (Ctrl-Click to select multiple):'},{''}], 'ListString', ModelSpecies, 'ListSize',[300 300])}};

            end
    end
    
% Prompt 4: Confirm the number of runs with the user 

% Check to see if VPs/Therapy doses are empty & confirm lengths
if ~isempty(VP_Variants)
    numVPs = length(VP_Variants);
else
    numVPs = 1;
end

if ~isempty(Doses)
    numDoses = length(Doses);
else
    numDoses = 1;
end

numRuns = numVPs*numDoses;
confirmRuns = questdlg(['The total number of runs is ' num2str(numRuns) ...
                        '. Would you like to run the simulation?'], ...    
                        '(4/4) Confirm Runs','Yes','No','No');

% Return out of simulation if runs are not confirmed                   
switch confirmRuns
    case 'No'
        return;
end

% Downsample the output times for the solver if selected
if exist('timeStep')
    outputTimes = [timeStart:timeStep:SimEndTime];
end

%% Step 4: Configure Model, Set ODE Solver & Obtain Model Variants & Doses

csObj = getconfigset(SimModelObj,'active');
set(csObj,'SolverType',odeSolver);
set(csObj.SolverOptions, 'AbsoluteTolerance',absTolerance, 'RelativeTolerance',relTolerance);
set(csObj.SolverOptions, 'OutputTimes', outputTimes);
set(csObj,'Stoptime',SimEndTime);

vObjAll = getvariant(model);
dObjAll = getdose(model);

%% Step 5: Get Species/Parameter/Variants/Dose Information

SpeciesNames = {''};
for i = 1:length(SimModelObj.Species)
    SpeciesNames{i}=SimModelObj.Species(i).Name;
    SpeciesCompartments{i}=SimModelObj.Species(i).Parent.Name;
end
clear i
ParameterNames = {''};
for i = 1:length(SimModelObj.Parameters)
    ParameterNames{i}=SimModelObj.Parameters(i).Name;
end
clear i
VariantNames = {''};
for i = 1:length(SimModelObj.Variants)
    VariantNames{i}=SimModelObj.Variants(i).Name;
end
DoseNames = {''};
for i = 1:length(SimModelObj.Doses)
    DoseNames{i}=SimModelObj.Doses(i).Name;
end

%% Step 6: Organize Variants and Doses

%Get index positions for VP variants and doses 
[~,VP_index] = ismember(VP_Variants,VariantNames);
[~,Doses_index] = ismember(Doses,DoseNames);

% Get indicies for background variants and background doses
[~,BackgroundVar_index] = ismember(Background_Variants,VariantNames);
[~,BackgroundDoses_index] = ismember(Background_Doses,DoseNames);

% Get indicies for dose variants (if present)
if ~isempty(Dose_Variants)
    for ii = 1:length(Doses)
        for jj = 1:length(Dose_Variants{ii})
            [~,DoseVar_index_out] = ismember(Dose_Variants{ii}{jj},VariantNames);
            DoseVar_index(ii,jj)=DoseVar_index_out;
        end
    end
end
%% Step 7: Make Directory Folder to Store Simulation Results & Information

% Current time
dateinfo = clock;

% Get the calendar date in yymmdd format
calendardate = sprintf('%d%02d%02d', dateinfo(1:3));

% Get the starting date and time of the simulation
dateandtime = sprintf('%d%02d%02d_%d%d', dateinfo(1:5));

% Make directory to store the simulation result files
SimulationDir = [ProjFolderName ' Simulation_Results/' dateandtime ' Simulation Info' '/'];
if ~exist(SimulationDir,'dir')
    mkdir(SimulationDir)
end

%% Step 8: Set up Log File to Save Simulation Information

%Write simulation starting parameters to the log file 
logFileName = [SimulationDir dateandtime '_log file.txt'];
switch saveinfo
    case 'Yes'
        logFileName = [SimulationDir dateandtime '_log file.txt'];
        LogFile_ID = fopen(logFileName, 'wt');
        
        %Print initial details to the log file
        fprintf(LogFile_ID,'Project File: %s\n',ProjectFileName);
        fprintf(LogFile_ID,'Simulation Date: %02d%02d%02d\n',dateinfo(1:3));
        fprintf(LogFile_ID,'Simulation Start Time: %02d:%02d\n\n',dateinfo(4:5));
        
        % Capture solver details 
        fprintf(LogFile_ID, 'Solver Settings: \n');
        fprintf(LogFile_ID, evalc('disp(csObj)'));
        
        % Print header title for simulation runs 
        fprintf(LogFile_ID, '\nSimulation Details:\n\n');

        %Set state for final processing
        GrabDetails = 1;
        
    case 'No'
        GrabDetails = 0; 
        logFileName = '';
end

%% Step 9: Organize Treatment/Variant Combinations

%Generate arrays of variant/therapy dose objects
VariantStack = vObjAll(VP_index);
DoseStack = dObjAll(Doses_index(Doses_index > 0)); %  Add untreated back in later

% Add any untreated doses to dose stack using an empty dose object
for i = 1:length(Doses_index)
    if Doses_index(i) == 0
       emptydose = sbiodose('Untreated','repeat','Amount',0);
       DoseStack = vertcat(emptydose, DoseStack);
    end
end

idxNum = 1;
% Create matrix to hold the VP/therapy dose combinations
for i = 1:numVPs
    for j = 1:numDoses
        if isempty(VP_Variants)
           ComboMatrix(idxNum,:) = [sbiovariant('No_VP') DoseStack(j)];
           ComboMatrixTable(idxNum,:) = {'No_VP',DoseStack(j).Name};
        else
           ComboMatrix(idxNum,:) = [VariantStack(i) DoseStack(j)];
           ComboMatrixTable(idxNum,:) = {VariantStack(i).Name,DoseStack(j).Name};
        end
        idxNum = idxNum + 1;
    end
end

% Get background variants/doses to be applied to all runs
BackgroundVariantStack = vObjAll(BackgroundVar_index);
BackgroundDoseStack = dObjAll(BackgroundDoses_index);

% Set up dose variants 
idxNum = 1;
if ~isempty(Dose_Variants)
    for i = 1:length(VP_Variants)
        for j = 1:length(Doses)
            if DoseVar_index(j,1) == 0
                DoseVariantStack{idxNum,:} = {};
            else
                DoseVariantStack{idxNum,:} = vObjAll(DoseVar_index(j,:));
            end
            idxNum = idxNum + 1;
        end
    end
else
    DoseVariantStack = cell(numRuns,1);
end
%% Step 10: Run VP/Treatment Response

disp('Starting Simulation')
% Run simulation response
NumRuns = numVPs*numDoses;
parfor k = 1:NumRuns

    % Get VP
    if strcmp(ComboMatrix(k,1).Name,'No_VP')
        VPVariantStack = [];
    else
        VPVariantStack = ComboMatrix(k,1);
    end
    
    % Get dose
    if strcmp(ComboMatrix(k,2).Name,'Untreated')
        TherapyDose = [];
    else
        TherapyDose = ComboMatrix(k,2);
    end

    Variants = [VPVariantStack; BackgroundVariantStack; DoseVariantStack{k}];
    Doses = [TherapyDose; BackgroundDoseStack];
    fprintf('Run %i/%i: %s, %s\n',k,NumRuns,ComboMatrix(k,1).Name,ComboMatrix(k,2).Name);

    % Run simulation
    SimData(k) = sbiosimulate(SimModelObj,csObj,Variants,Doses);
 
end

% Display message to show the simulation is complete
disp('Simulation is complete.'); 

%% Step 11: Generate Data Structure

parfor runNum = 1:NumRuns
    SimDataStruct(runNum).Variant = ComboMatrixTable{runNum,1};
    SimDataStruct(runNum).Dose = ComboMatrixTable{runNum,2};
    SimDataStruct(runNum).RunData = SimData(runNum);    
    SimDataStruct(runNum).RunInfo = PrintRunInfo(DoseVariantStack{runNum,:},BackgroundVariantStack,BackgroundDoseStack)
    SimDataStruct(runNum).ErrorData.time = '';
    SimDataStruct(runNum).ErrorData.mean = '';
    SimDataStruct(runNum).ErrorData.stdev = '';
end

%% Step 12: Record Simulation Details to Log File

% Record simulation info to text file
if GrabDetails
    for RunNum = 1:NumRuns
        VP = ComboMatrix(RunNum,1).Name; 
        Dose = ComboMatrix(RunNum,2).Name;
        BackgroundVarName = {BackgroundVariantStack(:).Name};
        
        if ~isempty(DoseVariantStack{RunNum,:})
            DoseVarName = {DoseVariantStack{RunNum,:}.Name};
        else 
            DoseVarName = [];
        end
        
        PrintRunToLogFile(LogFile_ID, RunNum, VP, Dose, DoseVarName, BackgroundVarName, SimDuration, SimTimeUnits);
    end
end

% Close text file
if GrabDetails
    dateinfo = clock;
    fprintf(LogFile_ID,'Simulation End Time: %02d:%02d\n',dateinfo(4:5));
    fprintf(LogFile_ID, '\n Backup Files Saved\n');
    fclose(LogFile_ID);
end

%% Step 13:Save Backup Files (.sbproj and .m) to Directory Folder

if GrabDetails
% Get the SimBiology project file name and analysis script name
[filepath, filename, ext] = fileparts(ProjectFileName);
ScriptName = strcat(mfilename,'.m');

% Copy simbiology file to the directory folder
backupSbioFile = [SimulationDir filename '_backup' dateandtime '.sbproj'];
copyfile(ProjectFileName,backupSbioFile);
    
% Copy analysis script to the directory folder
backupMFile = [SimulationDir mfilename '_backup' dateandtime '.m'];
copyfile(ScriptName,backupMFile);
    
% Save variants to an excel sheet
xlsWriteVariant(SimModelObj,[SimulationDir filename '.sbproj' ' variants.xls']);
end

% Save the structs, simulation directory, and dose/VP info to .mat file
 save([SimulationDir 'SimulationData_AllRuns.mat'],'SimData','SimDataStruct','filename','SimulationDir','-v7.3');
 
 %% Step 14: Record Simulation Details to Excel File

switch generateExcel
    case 'Yes'
        
    % Write the simulation data to an excel file
    xlsDataFile = [SimulationDir 'SimulationData_' dateandtime '.xls'];
    
    xlsWriteSimulation(SimData,NumRuns,SimDuration,TimePoints,...
        SpeciesToSave,xlsDataFile,logFileName); 
end

%% Step 15: Describe location of Results to the User

fprintf(['\nBackup files and a log file of the simulation',... 
                        ' are saved here:\n %s \n'], SimulationDir );

% Show the file save location in the file explorer                   
winopen(SimulationDir);

%% Functions
function PrintRunToLogFile(LogFile,RunNum,VP,Dose,Dose_Variants, Background_Variants,SimDuration,SimTimeUnits)
% PrintRunToLogFile     Prints simulation information (run #, dose, variant) 
%                       to a log file (as .txt)

fprintf(LogFile,'Run %d Information:\n',RunNum);
fprintf(LogFile,'     %s, %s\n',VP,Dose);
fprintf(LogFile,'     Simulation End Time:\n');
fprintf(LogFile,'          %d %s\n',SimDuration,SimTimeUnits);
fprintf(LogFile,'     VP Variants:\n');
fprintf(LogFile,'          %s\n',VP);

if ~isempty(Dose_Variants(:))
    fprintf(LogFile,'     Dose Variants:\n');
    fprintf(LogFile,'          %s\n',Dose_Variants{:});
end

if ~isempty(Background_Variants)
    fprintf(LogFile,'     Background Variants:\n');
    fprintf(LogFile,'          %s\n',Background_Variants{:});

end
fprintf(LogFile,'     Dose:\n');
fprintf(LogFile,'          %s\n',Dose);
end
    
function RunInfo = PrintRunInfo(DoseVariantStack,BackgroundVariantStack,BackgroundDoseStack)

if ~isempty(DoseVariantStack(:))
    Dose_Vars = {DoseVariantStack.Name};
    Dose_VarNames = ['Dose Variants: ' sprintf('%s, ',Dose_Vars{:})];
    Dose_VarNames = strip(strtrim(Dose_VarNames), 'right',',');
else
    Dose_VarNames = '';
end

if ~isempty(BackgroundVariantStack)
    Background_Vars = {BackgroundVariantStack.Name};
    BackgroundVar_Names = ['Background Variants:  ' sprintf('%s ',Background_Vars{:})];
    BackgroundVar_Names = strip(strtrim(BackgroundVar_Names), 'right',',');
else
    BackgroundVar_Names = '';
end

if ~isempty(BackgroundDoseStack)
    Background_Doses = {BackgroundDoseStack.Name};
    BackgroundDose_Names = ['Background Doses: ' sprintf('%s ',Background_Doses{:})];
    BackgroundDose_Names = strip(strtrim(BackgroundDose_Names), 'right',',');
else
    BackgroundDose_Names = '';
end

RunInfo = sprintf('%s %s %s', Dose_VarNames, BackgroundVar_Names, BackgroundDose_Names);

end

function xlsWriteSimulation(obj, numRuns, SimDuration,TimePoints,...
    SpeciesToSave, xlsfilename, logFile)

% xlsWriteSimulation    Writes simulation data to an excel workbook for 
%                       selected species and timepoints, each sheet is a 
%                       separate run.
%      
%       obj - Simbiology model object containing simulation data 
%       TimePoints - Number of time points to record in the excel workbook
%       SpeciesToSave - Species to record in excel workbook

%       See also xlswrite
try
for m = 1:numRuns
    
    timeStep = SimDuration/TimePoints;
    SheetName = ['Run ' num2str(m)];
    
    % Column Headers 
    colheaders = [{'Time'} obj(m).selectbyname(SpeciesToSave).DataNames'];
    % Time Data
    timeData = [obj(m).Time(timeStep:timeStep:end)]; 
    % Simulation Data
    for k = 1:length(SpeciesToSave)
        simData(:,k) = [obj(m).selectbyname(SpeciesToSave{k}).Data(timeStep:timeStep:end)];
    end
    
    AllData = cell(TimePoints+1, length(SpeciesToSave)+1);
    AllData(1,:) = colheaders;
    AllData(2:TimePoints+1, :) = num2cell([timeData, simData]); 
    
    % Write data to excel workbook
    warning off
    xlswrite(xlsfilename, AllData, SheetName);
end

    % Write the log file to the first sheet of the Excel file
    if ~isempty(logFile)
        stringinfo = textread(logFile, '%s' ,'delimiter','\n');
        xlswrite(xlsfilename, stringinfo,'Sheet1');
    end
    warning on
catch
    disp('Excel error detected. No simulation data spreadsheet generated.')
end
end

function xlsWriteVariant(obj,filename)
%  xlsWriteVariant Writes ALL variants in the simbiology object Obj to an
%                 excel workbook, each sheet is a seperate variant
%      
%       obj - Simbiology model object containing variant data 
%       filename - Desired file name for the saved excel sheet
% 
%
%       Original script by Dr. Meghan Pryor, Ph.D., 201603
%       © 2019 Rosa & Co. LLC
%
%       See also GET, xlswrite
try
warning off
vObjAll = getvariant(obj);
[m,n] = size(vObjAll);

for ii = 1:m
    variantinfo = get(vObjAll(ii));
    if length(variantinfo.Name) > 30
        SheetName = variantinfo.Name(1:30);
    else
        SheetName = variantinfo.Name;
    end
    VariantData = variantinfo.Content;
    for jj = 1:length(VariantData)
        SortedVariantData{ii}(jj,:) = VariantData{jj};
    end
    xlswrite(filename,SortedVariantData{ii},SheetName);
end
warning on
catch
    disp('Excel error detected. No variant spreadsheet generated.')
end
end

