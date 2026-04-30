%new test_code for analyze_TFM or analyze_TFM_semiautomated
%takes a folder with samples for analysis and will analyze in batch then
%return a single excel spreadsheet with outputs (traction force, stress,
%beat frequency, and area of traction) as well as graphs showing force and
%stress v. time, and a traction heatmap with vector overlay

disp('Choose input folder with files for analysis')
input_fldr = uigetdir;

disp('Choose destination folder to export values to')
dest_fldr = uigetdir;

folderList = dir(input_fldr);

% Keep only directories (subfolders)
folderList = folderList([folderList.isdir]);

% Remove '.' and '..'
folderList = folderList(~ismember({folderList.name}, {'.','..'}));


sample_name = strings(length(folderList),1);
avg_force = nan(length(folderList),1);
avg_stress = nan(length(folderList),1);
beat_freq = nan(length(folderList),1);
area = nan(length(folderList),1);


for i = 1:length(folderList)
    foldername = folderList(i).name;
    disp(foldername);
    [Average_Total_Force, Average_Stress, beatfreq_Hz, area_roi]  =  Analyze_TFM_testing(150,sprintf("Traction_%s_",foldername),sprintf("%s_",foldername),foldername,0.533333,.033,15,5,dest_fldr);
    disp(foldername);
    sample_name(i)=foldername;
    avg_force(i)=Average_Total_Force;
    avg_stress(i)=Average_Stress;
    beat_freq(i)=beatfreq_Hz;
    area(i)=area_roi;

end

ResultsTable = table(sample_name,avg_force,avg_stress,beat_freq,area);
writetable(ResultsTable, fullfile(dest_fldr, "TFM_results.xlsx"));

disp("DONE. Results saved to Excel.")


