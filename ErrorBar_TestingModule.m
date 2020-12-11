SimDataStruct = ConfigureErrorBars('TestData.xls',SimDataStruct)
errorBars =  PlotErrorBars(SimDataStruct, 'ABeta40_M_pg')
function SimDataStruct = ConfigureErrorBars(filename, SimDataStruct)

sheetNames = cellstr(sheetnames(filename));
% Read in excel data
for k = 1:length(sheetNames)
    [num, txt, raw] = xlsread(filename, sheetNames{k});
    AllNames(:,:,k) = txt;
    AllData(:,:,k) = num;
end

% Have user select sheets containing relevant experimental data
prompt = [{'Select all sheets containing data to match with simulation runs:'},{''},{''}];
errorData = sheetNames(listdlg('PromptString',prompt,'ListString',sheetNames,'SelectionMode','multiple'));

% Have user match data in excel file to simulation runs
for i = 1:length(errorData)
    txtPrompts{i} = [sprintf('Run index # for %s',errorData{i})];
end
%%%%%
% Add a window that allows the user to see the run #, VP, and dose 
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
%%%%%
try
    runIndicies = cellfun(@str2num, inputdlg(txtPrompts, 'Enter numerical value of run index')); % Convert to integers
    continueFlag = false;
catch
    warndlg('Make sure to input numerical index values for all sheets.')
    runIndicies = cellfun(@str2num, inputdlg(txtPrompts, 'Enter numerical value of run index'));
end

% Separate out the error bar/stdev data on each sheet
% Parse through the column names until a value is repeated
% FIXME
for i = 3:length(AllNames)
    speciesName = AllNames{2};
    if contains(AllNames{i},speciesName)
        endMeans = i-1;
        startStdevs = i;
        break
    end
end
% END FIXME
  
% Assign error data (time, mean,stdev) to SimDataStruct
for i = 1:length(runIndicies)
    SimDataStruct(runIndicies(i)).ErrorData.time = AllData(:,1,runIndicies(i));
    SimDataStruct(runIndicies(i)).ErrorData.mean = AllData(:,(2:endMeans),runIndicies(i));
    SimDataStruct(runIndicies(i)).ErrorData.stdev = AllData(:,(startStdevs:end),runIndicies(i));
    SimDataStruct(runIndicies(i)).ErrorData.species = AllNames(:,(2:endMeans),runIndicies(i));
end

end

%% Plot Error Bars
%function errorBars = PlotErrorBars(Struct, SpeciestoPlot, linehandles)
function errorBars = PlotErrorBars(Struct, SpeciestoPlot)
% FIXME
for i = 1:length(Struct)
    if ~isempty(Struct(i).ErrorData.time)
            % Species index information
            AllSpecies = Struct(i).ErrorData.species;
            try
                [~,speciesIdx] = ismember(SpeciestoPlot, AllSpecies);
            catch
                warndlg('Species names are not consistent. Please input manually.')
                
            end
            % Plot error bars
            x = Struct(i).ErrorData.time(:,1); 
            y = Struct(i).ErrorData.mean(:,speciesIdx);
            err = Struct(i).ErrorData.stdev(:,speciesIdx);
            errorBars = errorbar(x,y,err);
            hold on
            
            % Set error bar properties
            % set(errorBars,'LineStyle','none','Marker','d','MarkerSize',5,'Color',linehandles(i).Color,'LineWidth',3);
    else
        errorBars = [];     
    end
end
%END FIXME
end