%companion code for TFM
%takes a folder containing samples for TFM analysis, and puts each file in
%a folder of the same name
targetFolder = '/Volumes/miranda h/031126_TFM/wt_22kpa/samples'; %input path to folder of interest
items = dir(targetFolder);
items = items(~[items.isdir]);
for i = 1:length(items)
    filename = items(i).name;
    [~, name, ext] = fileparts(filename);
    newfolder = fullfile(targetFolder, name)
    mkdir(newfolder);
    oldpath = fullfile(targetFolder, filename);
    newpath = fullfile(newfolder, filename);
    movefile(oldpath, newpath)
end

    