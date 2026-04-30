
//script that takes in a TIF image stack/video and returns PIV and FTTC results for traction force microscopy analysis
maindir = getDirectory("Choose a Directory"); 
level1 = getFileList(maindir);
for (i = 0; i < level1.length; i++) {
	if (endsWith(level1[i],"/")) {
	level1_path = maindir + level1[i];
	level2 = getFileList(level1_path);
	for (j=0; j < level2.length; j++) {
		if (endsWith(level2[j],"/")){
		subname = level2[j];
		subpath = level1_path + subname;
		clean_name = substring(subname, 0, lengthOf(subname)-1);
		open(subpath + clean_name + ".tif");
		num_relax = 1;
		run("Stack to Images");
		for (k = 0; k < nImages; k++) {
			selectImage(k+1);
			num_title = d2s(k+1,0);
			saveAs("tiff", subpath + clean_name + "_" + num_title);
		}
		run("Close All");
		//for each frame, runs iterative PIV
		for (l = 1; l <= 150; l++) {
			n = d2s(l,0);
			fname = clean_name + "_" + n + ".tif";
			fname_relax = clean_name + "_1.tif";
			open(subpath + fname_relax);
			open(subpath + fname);
			run("Images to Stack", "name=Stack title=[] use");
			run("iterative PIV(Advanced)...", "piv1 = 256 sw1 = 256 vs1 = 128 piv2 = 128 sw2 = 128 vs2 = 64 piv3 = 64 sw3 = 64 vs3 = 32 correlation=0.60 noise=0.20 threshold = 5 save=[" + subpath + clean_name + "_" + n + "]");
			//change pixel size and young's modulus as needed 60x = 266667, 30x 533333
			run("FTTC ", "pixel=533333 poisson=0.3 young's=22000 regularization=0.001 plot=512 select=[" + subpath + clean_name + "_" + n + "]");
			run("Close All");
	
}
}
}


