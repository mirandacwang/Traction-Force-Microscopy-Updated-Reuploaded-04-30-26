function [Average_Total_Force, Average_Stress, beatfreq_Hz, area_roi] = Analyze_TFM_semiautomated(numImages, FTTCfile, PIVfile, titlename, pxsize, dt, smoothwidth, width, dest_fldr)
%this function takes in user information about the input fileset and
%returns the average force, average stress (normalized to traction area),
%beat rate, and area of traction force for the sample
%this version is semi automated and will identify the contraction image,
%then ask the user circle the ROI and will smooth out the resultant area
%based on relative traction


%% --- Load FTTC and PIV data ---
FTTCdata = zeros(784,5,numImages); % change dimensions to fit input image
PIVdata  = zeros(784,16,numImages); 
for i = 2:numImages
    FTTCfilename = sprintf('%s%d',FTTCfile,i);
    FTTCdata(:,:,i) = dlmread(FTTCfilename);
    PIVfilename = sprintf('%s%d',PIVfile,i);
    PIVdata(:,:,i) = dlmread(PIVfilename);
end

gridSize = 28;  % change dimensions to fit input image
mask = false(gridSize, gridSize);
mask(7:26,7:26) = true; % creates a mask for traction measurement to minimize interference from neighboring cells

%% --- Compute total traction ---
totalTraction = zeros(numImages,1);
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

%% --- Interpolation grids ---
[X,Y] = meshgrid(linspace(1,512,gridSize), linspace(1,512,gridSize));
[xq,yq] = meshgrid(1:512, 1:512);

%determines the scale for heatmap traction display based on 1.5x highest
%traction values
maxROI = prctile(allValues,99.8)*1.5;
disp(maxROI);

magnitude_circle = FTTCdata(:,5,contractionimage);
magnitude_circle_matrix = reshape(magnitude_circle,[gridSize,gridSize])';
magnitude_circle_interp = interp2(X,Y,magnitude_circle_matrix, xq, yq);

%% --- Step 1: User-drawn freehand + shrink-then-dilate + skip ---
figure;
imagesc(magnitude_circle_interp);
colormap(jet); colorbar; caxis([0, maxROI]);
set(gca,'YDir','reverse');
title('Draw a freehand region around the cell (or cancel to skip)');
hold on;

% --- Overlay FTTC arrows before user draws ---
Fx = reshape(FTTCdata(:,3,contractionimage), [gridSize,gridSize])';
Fy = reshape(FTTCdata(:,4,contractionimage), [gridSize,gridSize])';
Fx_interp = interp2(X,Y,Fx,xq,yq);
Fy_interp = interp2(X,Y,Fy,xq,yq);
step = 20;
[xx,yy] = meshgrid(1:512,1:512);
quiver(xx(1:step:end,1:step:end), yy(1:step:end,1:step:end), ...
       Fx_interp(1:step:end,1:step:end), Fy_interp(1:step:end,1:step:end), ...
       'w','LineWidth',1);

% --- User draws freehand region ---
h = imfreehand;

% --- Skip check ---
if isempty(h) || ~isvalid(h)
    close(gcf);
    Average_Total_Force = NaN;
    Average_Stress      = NaN;
    beatfreq_Hz         = NaN;
    area_roi            = NaN;
    return
end

userMask = createMask(h);  % binary mask of user-drawn region

if ~any(userMask(:))
    close(gcf);
    Average_Total_Force = NaN;
    Average_Stress      = NaN;
    beatfreq_Hz         = NaN;
    area_roi            = NaN;
    return
end

% --- Shrink: keep only high-traction pixels inside user region ---
roiMax = max(magnitude_circle_interp(userMask));   % max traction inside selection
threshold = 0.2 * roiMax;                         % fraction of max for threshold
thresholdMask = (magnitude_circle_interp > threshold) & userMask;

% --- Dilate & bridge after shrink to merge nearby blobs ---
bufferSize = 15;  % expand blobs slightly
bridgeSize  = 50; % connect nearby blobs
shrunkMask = imerode(thresholdMask, strel('disk',5));   % slight shrinkwrap
dilatedMask = imdilate(shrunkMask, strel('disk',bufferSize));
finalMergedMask = imclose(dilatedMask, strel('disk',bridgeSize));

% --- Clean up ---
finalMergedMask = imfill(finalMergedMask,'holes');   % fill holes inside blobs
finalMergedMask = bwareaopen(finalMergedMask,200);  % remove small noise

% --- Optional slight smoothing
sigma = 2; 
finalMergedMask = imgaussfilt(double(finalMergedMask), sigma) > 0.5;


%% --- Step 2: Extract and plot final boundary ---
boundaries = bwboundaries(finalMergedMask,'noholes');
figure;
imagesc(magnitude_circle_interp);
colormap(jet); colorbar; caxis([0, maxROI]);
set(gca,'YDir','reverse'); hold on;

% Overlay FTTC arrows
quiver(xx(1:step:end,1:step:end), yy(1:step:end,1:step:end), ...
       Fx_interp(1:step:end,1:step:end), Fy_interp(1:step:end,1:step:end), ...
       'w','LineWidth',1);

% Overlay final mask boundary
if ~isempty(boundaries)
    b = boundaries{1};
    finalMergedMask = poly2mask(b(:,2), b(:,1), size(finalMergedMask,1), size(finalMergedMask,2));
    plot(b(:,2), b(:,1),'w-','LineWidth',3);
end
title('Shrinkwrapped ROI');
savename = fullfile(dest_fldr, sprintf('Heatmap_%s.tiff', titlename));
saveas(gcf,savename);

%% --- Step 3: ROI area ---
area_roi = sum(finalMergedMask(:)) * pxsize^2;

%% --- Step 4: Force & stress calculations ---

%cuts off first and last 10 frames to reduce edge artifacts
forceTotal = zeros(numImages-20,1);
stressRMS  = zeros(numImages-20,1);

for i = 1:numImages-20
    mag_FTTC = reshape(FTTCdata(:,5,i+10), [gridSize,gridSize])';
    disp_FTTC = reshape(PIVdata(:,5,i+10), [gridSize,gridSize])';
    mag_interp = interp2(X,Y,mag_FTTC,xq,yq);
    disp_interp = interp2(X,Y,disp_FTTC,xq,yq);

    mag_roi = finalMergedMask .* mag_interp;
    disp_roi = finalMergedMask .* disp_interp;

    forceTotal(i) = nansum(mag_roi(:)) * pxsize^2 * 1e-3; % nN
    stressRMS(i)  = sqrt(nansum(mag_roi(:).^2) / nansum(finalMergedMask(:)));
end

%% --- Step 5: Total Force vs Time ---
time = (0:numImages-21)*dt;
Force_smooth = fastsmooth(forceTotal, smoothwidth, 1, 1);
Force_smooth = Force_smooth - min(Force_smooth(30:end-30));

cutoff = 20;
force_for_peaks = Force_smooth(cutoff+1:end-cutoff);
[pks, locs, w] = findpeaks(force_for_peaks);
locs = locs + cutoff;
realpkslocs = find(w>width);
realpks = pks(realpkslocs);
reallocs = locs(realpkslocs);

realpks_normalized = zeros(length(realpks),1);
if ~isempty(realpks)
    realpks_normalized(1) = realpks(1);
    for i=2:length(realpks)
        pktime = reallocs(i);
        localmins = min(Force_smooth((pktime-20):pktime));
        realpks_normalized(i) = realpks(i) - localmins;
    end
end
Average_Total_Force = mean(realpks_normalized);

difflocs = diff(reallocs);
beatcycle_s = mean(difflocs) * dt;
beatfreq_Hz = 1/beatcycle_s;

figure;
plot(time, Force_smooth,'LineWidth',2); hold on;
plot(time(reallocs),Force_smooth(reallocs),'ro','MarkerSize',10,'LineWidth',2);
xlabel('Time (s)'); ylabel('Total force (nN)');
title([titlename ' | Total Force']);
savename = fullfile(dest_fldr, sprintf('TotalForce_%s.tiff', titlename));
saveas(gcf,savename);

%% --- Step 6: Stress RMS vs Time ---
Stress_smooth = fastsmooth(stressRMS, smoothwidth, 1, 1);
Stress_smooth = Stress_smooth - min(Stress_smooth(30:end-30));

stress_for_peaks = Stress_smooth(cutoff+1:end-cutoff);
[pks, locs, w] = findpeaks(stress_for_peaks);
locs = locs + cutoff;
realpkslocs = find(w>width);
realpks = pks(realpkslocs);
reallocs = locs(realpkslocs);

realpks_normalized = zeros(length(realpks),1);
if ~isempty(realpks)
    realpks_normalized(1) = realpks(1);
    for i=2:length(realpks)
        pktime = reallocs(i);
        localmins = min(Stress_smooth((pktime-20):pktime));
        realpks_normalized(i) = realpks(i) - localmins;
    end
end
Average_Stress = mean(realpks_normalized);

figure;
plot(time, Stress_smooth,'LineWidth',2); hold on;
plot(time(reallocs), Stress_smooth(reallocs),'ro','MarkerSize',10,'LineWidth',2);
xlabel('Time (s)'); ylabel('Stress RMS (Pa)');
title(titlename);
savename = fullfile(dest_fldr, sprintf('TotalStress_%s.tiff', titlename));
saveas(gcf,savename);

close all;
end