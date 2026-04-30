# Traction-Force-Microscopy-Updated-Reuploaded-04-30-26
This repository contains my most updated code to perform traction force microscopy analysis on contracting cardiomyocytes

# Overview
Traction force microscopy (TFM) is a common method used to determine the forces that cells excert on their microenvironment. A typical workflow for TFM includes creating a stiffness-tunable gel base - polyacrylamide (PAA) or polydimethylsiloxane (PDMS) - that contains fluorescent beads concentrated at the material surface. Single cells or multicellular patterned "islands" can be seeded on the surface of the gel, and as the cells pull on the gel, the beads move. By imaging movement of the beads overtime (non-excitable cells) or during stimulated cellular contraction (cardiomyocytes, skeletal myocytes), and using known information about the substrate material properties, we can determine the forces the cells are exerting on the substrate.

<img width="727" height="386" alt="Screenshot 2026-04-30 at 2 52 07 PM" src="https://github.com/user-attachments/assets/01aa6651-3cf4-4a94-bf9f-9a42d2d7cbfd" />
Fig 1. TFM workflow

# Folder Structure
This repository contains a code package to analyze traction force microscopy videos of single-cell or patterned islands of cardiomyocytes. Running this code requires MATLAB and FIJI. The workflow takes in a TIF stack of images showing bead contraction motion, organizes the samples into folders of the same name as the sample using "Folder_creator." 

<img width="256" height="257" alt="image" src="https://github.com/user-attachments/assets/5b3714e8-8673-4075-8617-61911bdf72ff" />
Fig 2. Example bead image

These folders can be fed into the FIJI code "New_TFM_Script.ijm" which will split the TIF into individual frames and run iterative PIV returning PIV and FTTC files. The outputs can then be read in MATLAB using the code "Batch_TFM_code.m" which will go through a selected folder of samples and return the average traction force, stress, area of traction, and beat frequency for each sample along with associated stress and force graphs overtime and heatmaps of traction force with overlaid vectors. 

<img width="820" height="616" alt="image" src="https://github.com/user-attachments/assets/bb735dd6-fd75-41ca-a253-a364acdf4694" />
Fig 3. Example traction heatmap with circled ROI


<img width="684" height="291" alt="Screenshot 2026-04-30 at 3 02 50 PM" src="https://github.com/user-attachments/assets/8293a467-e8ba-4c54-9b86-eea516faca1e" />
Fig 4. Example output force and stress graphs

The code is customizable for input file changes and the repository contains two analysis codes. "Analyze_TFM.m" is mostly automated and will ask users to select pre-identified regions of high traction to identify the traction ROI. "Analyze_TFM_semiautomated.m" returns the same outputs but asks users to circle the region of interest before smoothing and shrinkwrapping the ROI. The semiautomated version performs better on samples with very low traction force, or with significant interference from neighboring cells. 

# Installation
Running this code requires MATLAB and FIJI.
FIJI must have Bio-Formats and PIV packages installed. MATLAB must have the Image Processing Toolbox and Signal Processing Toolbox installed. This code also requires the use of a helper function "fastsmooth" which can be downloaded here: https://www.mathworks.com/matlabcentral/fileexchange/19998-fast-smoothing-function. 
