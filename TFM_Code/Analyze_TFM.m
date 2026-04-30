function [Average_Total_Force, Average_Stress, beatfreq_Hz, area_roi]  =  Analyze_TFM(numImages, FTTCfile,PIVfile,titlename,pxsize,dt, smoothwidth,width,dest_fldr);
%this function takes in user information about the input fileset and
%returns the average force, average stress (normalized to traction area),
%beat rate, and area of traction force for the sample
%this version is mostly automated and will identify the contraction image,
%ask the user to choose the cell of interest from pre-circled traction
%spots, then uses a buffered capsule merge to create the ROI

% --- Load FTTC and PIV data ---
FTTCdata = zeros(784,5,numImages); % change dimensions to fit input image
PIVdata = zeros(784,16,numImages); 
for i = 2:numImages
    FTTCfilename = sprintf('%s%d',FTTCfile,i);
    FTTCdata(:,:,i) = dlmread(FTTCfilename);
    PIVfilename = sprintf('%s%d',PIVfile,i);
    PIVdata(:,:,i) = dlmread(PIVfilename);
end

gridSize = 28;  % change dimensions to fit input image
mask = false(gridSize, gridSize);
mask(7:26,7:26)=true; % creates a mask for traction measurement to minimize interference from neighboring cells

% --- Compute total traction ---
totalTraction = zeros(numImages, 1);
allValues = [];
for i = 1:numImages
    magnitude = FTTCdata(:,5,i);
    magnitude_matrix = reshape(magnitude, [gridSize, gridSize])';
    masked_values = magnitude_matrix(mask);
    totalTraction(i) = nansum(masked_values);
    allValues = [allValues; masked_values(:)];
end

%determines max contraction image based on masked area and displays the
%identified frame
[~,contractionimage] = max(totalTraction);
disp(['Contraction frame: ', num2str(contractionimage)]);

% --- Interpolation grids for 28x28 ---
[X,Y] = meshgrid(linspace(1,512,gridSize), linspace(1,512,gridSize));  % 28x28 points
[xq,yq] = meshgrid(1:1:512, 1:1:512);

%determines the scale for heatmap traction display based on 1.5x highest
%traction values
maxROI = prctile(allValues,99.8);
disp(maxROI);

% --- Extract magnitude for contraction frame ---
magnitude_circle = FTTCdata(:,5,contractionimage);
magnitude_circle_matrix = reshape(magnitude_circle,[gridSize,gridSize])';
magnitude_circle_interp = interp2(X,Y,magnitude_circle_matrix, xq, yq);

%% --- Step 1: Threshold traction map to get candidate regions ---
%this section identifies regions of high traction, can adjust the threshold
%from "max" as needed
threshold = 0.225 * max(magnitude_circle_interp(:));
candidateMask = magnitude_circle_interp > threshold;
candidateMask = imfill(candidateMask,'holes');
candidateMask = bwareaopen(candidateMask,20);

%step 2 show candidate regions and get user input to identify regions of
%traction from the cell of interest
figure;
imagesc(magnitude_circle_interp);
colormap(jet);
colorbar;
caxis([0, maxROI])
set(gca,'YDir','reverse')
title('Click on regions to keep (markers appear as you click)')
hold on;
%% -------- Overlay traction arrows (FTTC) --------
Fx = FTTCdata(:,3,contractionimage);   % CHANGE COLUMN if needed
Fy = FTTCdata(:,4,contractionimage);   % CHANGE COLUMN if needed

Fx_mat = reshape(Fx,[gridSize, gridSize])';
Fy_mat = reshape(Fy,[gridSize, gridSize])';

Fx_interp = interp2(X,Y,Fx_mat, xq, yq);
Fy_interp = interp2(X,Y,Fy_mat, xq, yq);

% downsample arrows so it's readable
step = 20;
[xx, yy] = meshgrid(1:512, 1:512);

quiver(xx(1:step:end,1:step:end), yy(1:step:end,1:step:end), ...
       Fx_interp(1:step:end,1:step:end), Fy_interp(1:step:end,1:step:end), ...
       'w', 'LineWidth', 1);

% Draw candidate boundaries
[B_candidates,~] = bwboundaries(candidateMask,'noholes');
for k = 1:length(B_candidates)
    boundary = B_candidates{k};
    plot(boundary(:,2), boundary(:,1), 'w', 'LineWidth', 1.5);
end

%asks user to say if computer generated regions are correct and to
%continue, or incorrect and abort
choice = questdlg('Select regions to keep?', ...
    'ROI Selection', ...
    'Select','Skip Sample','Select');

if strcmp(choice,'Skip Sample')
    close(gcf);

    % Return "no information"
    Average_Total_Force = NaN;
    Average_Stress      = NaN;
    beatfreq_Hz         = NaN;
    area_roi            = NaN;
    return
end

xSeeds = [];
ySeeds = [];
button = 1;

while ~isempty(button)
    [x, y, button] = ginput(1);
    if isempty(button), break; end
    xSeeds(end+1) = x; %#ok<SAGROW>
    ySeeds(end+1) = y; %#ok<SAGROW>
    plot(x, y,'ro','MarkerSize',10,'LineWidth',2); % marker appears immediately
end

CC = bwconncomp(candidateMask);
selectedRegions = {};  % cell array to hold individual regions

for i = 1:CC.NumObjects
    [rows, cols] = ind2sub(size(candidateMask), CC.PixelIdxList{i});
    if any(ismember(round(rows), round(ySeeds)) & ismember(round(cols), round(xSeeds)))
        regionMask = false(size(candidateMask));
        regionMask(CC.PixelIdxList{i}) = true;
        selectedRegions{end+1} = regionMask; %#ok<SAGROW>
    end
end

close(gcf);

%% --- Step 6: Buffered Capsule Merge (Smooth & Slightly Loose) ---
mergedMask = false(size(magnitude_circle_interp));
for k = 1:length(selectedRegions)
    mergedMask = mergedMask | selectedRegions{k};
end

bufferSize = 10;  % buffer around original blobs, can adjust for smoothing
bufferedMask = imdilate(mergedMask, strel('disk', bufferSize));

bridgeSize = 25;  % bridge across small gaps, can make longer for further apart regions
bridgedMask = imclose(bufferedMask, strel('disk', bridgeSize));

roiMax = max(magnitude_circle_interp(mergedMask(:)));  % max traction within selected ROI
noiseFloor = 0.15 * roiMax;                           % adjust % of max as needed
allowed_growth = magnitude_circle_interp > noiseFloor;

finalMergedMask = imreconstruct(bridgedMask, allowed_growth);
finalMergedMask = imfill(finalMergedMask,'holes');
finalMergedMask = bwareaopen(finalMergedMask,200);


% --- Step 7: Extract and plot the SINGLE final boundary ---
boundaries = bwboundaries(finalMergedMask, 'noholes');
if ~isempty(boundaries);
    b = boundaries{1};
    finalMergedMask = poly2mask(b(:,2),b(:,1),size(finalMergedMask,1),size(finalMergedMask,2));
end


figure;
imagesc(magnitude_circle_interp);
colormap(jet); colorbar; caxis([0, maxROI]);
set(gca, 'YDir', 'reverse'); hold on;
%% -------- Overlay traction arrows (FTTC) --------
Fx = FTTCdata(:,3,contractionimage);   % CHANGE COLUMN if needed
Fy = FTTCdata(:,4,contractionimage);   % CHANGE COLUMN if needed

Fx_mat = reshape(Fx,[gridSize, gridSize])';
Fy_mat = reshape(Fy,[gridSize, gridSize])';

Fx_interp = interp2(X,Y,Fx_mat, xq, yq);
Fy_interp = interp2(X,Y,Fy_mat, xq, yq);

% downsample arrows
step = 20;
[xx, yy] = meshgrid(1:512, 1:512);

quiver(xx(1:step:end,1:step:end), yy(1:step:end,1:step:end), ...
       Fx_interp(1:step:end,1:step:end), Fy_interp(1:step:end,1:step:end), ...
       'w', 'LineWidth', 1);
plot(b(:,2), b(:,1), 'w-', 'LineWidth', 3);
title(['Buffered Merge | Buffer: ', num2str(bufferSize), ' Bridge: ', num2str(bridgeSize)]);
hold off;
savename = sprintf('Heatmap_%s.tiff',titlename);
savename = fullfile(dest_fldr,savename);
saveas(gcf,savename);

%% Calculate area of the ROI 
area_roi = sum(finalMergedMask(:))*pxsize*pxsize;
forceTotal = zeros(numImages-20,1);
stressRMS = zeros(numImages-20,1);



for i = 1:numImages-20
    % Grab the FTTC and PIV magnitude for this frame (shift by 10 as before)
    magnitude_FTTC = FTTCdata(:,5,i+10);
    displacement  = PIVdata(:,5,i+10);

    % Reshape to matrix
    magnitude_FTTC_matrix = reshape(magnitude_FTTC,[gridSize, gridSize])';
    displacement_matrix  = reshape(displacement,[gridSize, gridSize])';

    % Interpolate onto fine mesh
    magnitude_FTTC_interp = interp2(X,Y,magnitude_FTTC_matrix, xq,yq);
    displacement_interp   = interp2(X,Y,displacement_matrix, xq,yq);

    % Mask only the selected ROI
    magnitude_FTTC_roi   = finalMergedMask .* magnitude_FTTC_interp;
    displacement_roi     = finalMergedMask .* displacement_interp;

    % Calculate total force (nN) and RMS stress (Pa)
    forceTotal(i) = nansum(magnitude_FTTC_roi(:)) * pxsize^2 * 1e-3; % 10^-12*10^9 simplified
    stressRMS(i)  = sqrt(nansum(magnitude_FTTC_roi(:).^2) / nansum(finalMergedMask(:)));
end




%% --- Step 9: Plot Total Force over time ---
time = (0:numImages-21)*dt;  % time vector

Force_smooth = fastsmooth(forceTotal, smoothwidth, 1, 1);
Force_smooth = Force_smooth - min(Force_smooth(30:end-30));

cutoff = 20;
force_for_peaks = Force_smooth(cutoff+1:end-cutoff);
[pks, locs, w] = findpeaks(force_for_peaks);
locs = locs + cutoff;
realpkslocs = find(w > width); 
realpks = pks(realpkslocs);
reallocs = locs(realpkslocs);

realpks_normalized = zeros(length(realpks),1); 
realpks_normalized(1) = realpks(1); 
for i = 2:length(realpks)
    pktime = reallocs(i);
    localmins = min(Force_smooth((pktime-20):pktime));
    realpks_normalized(i) = realpks(i) - localmins;
end
Average_Total_Force = mean(realpks_normalized);

%find beat frequency
difflocs = zeros(length(reallocs)-1,1); 
for k = 2:length(reallocs)
    difflocs(k-1,1) = reallocs(k)-reallocs(k-1);
end
% Time between beats in seconds
beatcycle_s = mean(difflocs)* dt; 
% Beat frequency in Hz
beatfreq_Hz = 1/beatcycle_s; 


figure;
plot(time, Force_smooth, 'LineWidth', 2);
hold on;
plot(time(reallocs),Force_smooth(reallocs),'ro','MarkerSize',10,'LineWidth',2);
xlabel('Time (s)','FontSize',14);
ylabel('Total force (nN)','FontSize',14);
title([titlename ' | Total Force'],'FontSize',14);
set(gca,'FontSize',14);
savename = sprintf('TotalForce_%s.tiff',titlename);
savename = fullfile(dest_fldr,savename);
saveas(gcf,savename);


%% --- Step 10: Plot Stress RMS over time ---
Stress_smooth = fastsmooth(stressRMS,smoothwidth,1,1);
Stress_smooth = Stress_smooth-min(Stress_smooth(30:end-30)); 

cutoff = 20;
stress_for_peaks = Stress_smooth(cutoff+1:end-cutoff);
[pks, locs, w] = findpeaks(stress_for_peaks);
locs = locs + cutoff;
realpkslocs = find(w > width);
realpks = pks(realpkslocs);
reallocs = locs(realpkslocs);


realpks_normalized = zeros(length(realpks),1);
if ~isempty(realpks)
    realpks_normalized(1) = realpks(1);
    for i = 2:length(realpks)
        pktime = reallocs(i);
        localmins = min(Stress_smooth((pktime-20):pktime));
        realpks_normalized(i) = realpks(i) - localmins;
    end
end
Average_Stress = mean(realpks_normalized);

figure;
plot(time, Stress_smooth,'LineWidth',2);
hold on;
plot(time(reallocs),Stress_smooth(reallocs),'ro','MarkerSize',10,'LineWidth',2);
set(gca,'FontSize',14) 
xlabel('Time (s)','FontSize',14)
ylabel('Stress RMS (Pa)','FontSize',14)
title(titlename,'FontSize',14)
savename = sprintf('TotalStress_%s.tiff',titlename);
savename = fullfile(dest_fldr,savename);
saveas(gcf,savename);




close all;
