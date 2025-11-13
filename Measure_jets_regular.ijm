// clean up first
// close all images
//close("*");
// empty the ROI manager
roiManager("reset");
// empty the results table
run("Clear Results");
// configure that binary image are black in background, objects are white
setOption("BlackBackground", true);
// deselect all
run("Select None");


// function declaration
function rotatePoint(pointarr,angle, centerarr) { // rotates a point an angle (radians) around a center
	transpoint=newArray(2);
	rottranspoint=newArray(2);
	rotpoint=newArray(2);
	for (i = 0; i < 2; i++) { //translates so that centerarr is at the origin
		transpoint[i]=pointarr[i]-centerarr[i];
	}
	rottranspoint[0]=transpoint[0]*cos(angle)-transpoint[1]*sin(angle); // 2d rotations
	rottranspoint[1]=transpoint[0]*sin(angle)+transpoint[1]*cos(angle);
	for (i = 0; i < 2; i++) { //translates so that 0,0 is the origin again
		rotpoint[i]=rottranspoint[i]+centerarr[i];
	}
	return rotpoint;
}



// Get use mode dialog box
path=getDir("image");
do {
	Dialog.create("Measure jets");
	Dialog.addDirectory("images folder",path);
	options=newArray("jets","protrusions","fluidedge");
	Dialog.addRadioButtonGroup("Measurement mode", options, 1, 3, "jets");
	Dialog.show();
	
	// save answers of dialog box
	path=Dialog.getString();
	File.setDefaultDir(path)
	mode=Dialog.getRadioButton();
	manual=Dialog.getCheckbox();
	
	existinggif=0;
	if (File.exists(path+"stack.gif")) {
		Dialog.create(".gif found");
		options=newArray("Yes","No");
		Dialog.addRadioButtonGroup("Use existing gif?", options, 1, 2, "Yes");
		Dialog.show();
		existinggif=(Dialog.getRadioButton()=="Yes");
	}
	if (existinggif) {
		//opens existing gif file instead of idividual images
		open(path+"stack.gif");
	}else {
		// open images as a stack
		File.openSequence(path, " filter=(^((?!gif).)*$)");
	}
	getDimensions(w_im, h_im, ch_im, sl_im, f_im);
	
	
	//asks user if image is macro and if the scale should be set manually
	Dialog.create("macro");
	Dialog.addNumber("Plate edge length (mm)", 102);
	Dialog.addCheckbox("Macrolense image", false);
	Dialog.addNumber("Macro scale (px/mm)", 66.3059)
	Dialog.addCheckbox("Manually set scale", false);
	Dialog.show();
	
	// saves answers
	edgelen=Dialog.getNumber();
	macrolens=Dialog.getCheckbox();
	macroscale=Dialog.getNumber();
	manual=Dialog.getCheckbox();
	
	//prompt user to select late edge
	setTool("line");
	do {
	waitForUser("Draw line","Draw line from plate corner to plate corner. Press 'ok' when done.");
	}while (selectionType()!=5)
	
	//correct line direction and get origin
	getSelectionCoordinates(xarr, yarr);
	Array.sort(xarr, yarr);
	makeLine(xarr[0],yarr[0],xarr[1],yarr[1]);
	if (macrolens) {
		slope=(yarr[1]-yarr[0])/(xarr[1]-xarr[0]);
		y_imedge=yarr[0]-slope*xarr[0];
		origin=newArray(0,y_imedge);
	
	}else {
		origin=newArray(xarr[0],yarr[0]);
	}
	
	//get length and angle for scaling and rotation
	run("Clear Results");
	run("Measure");
	scalelen=getResult("Length");
	imageangle=getResult("Angle");
	
	//rotate image and origin
	run("Rotate... ", "angle="+imageangle+" grid=0 interpolation=Bilinear stack");
	origin=rotatePoint(origin,Math.toRadians(imageangle),newArray(w_im/2,h_im/2));
	
	//sets scale
	if (manual) { //propts user to set scale if manual. Otherwise sets it based on edge selection or macro scale
		run("Set Scale...");
	}else if (macrolens) {
		run("Set Scale...", "distance="+macroscale+" known=1 unit=mm");
	}else {
		run("Set Scale...", "distance="+scalelen+" known="+edgelen+" unit=mm");
	}
	
	//find the origin in mm
	makePoint(origin[0], origin[1], "small yellow hybrid");
	run("Clear Results");
	run("Measure");
	origin=newArray(getResult("X"),getResult("Y"));
	run("Select None");
	
	//prompt user to select jets/
	setTool("multipoint");
	do {
	waitForUser("Select the "+mode,"Select the "+mode+" in all slices. Press ok when done.");
	}while (selectionType()!=10)
	
	//saves the points as an roi
	roiManager("reset");
	roiManager("Add");
	if (File.exists(path+mode+"Points.roi")==0) {
		roiManager("Save", path+mode+"Points.roi");
	}else {
		i=1;
		while (File.exists(path+mode+"Points"+i+".roi")) {
			i++;
		}
		roiManager("Save", path+mode+"Points"+i+".roi");
	}
	
	//calculates measurement positions relative to origin
	run("Clear Results");
	roiManager("Measure");
	X=newArray(nResults);
	Y=newArray(nResults);
	Slice=newArray(nResults);
	for (i = 0; i < nResults; i++) {
		X[i]=getResult("X",i)-origin[0];
		Y[i]=getResult("Y",i)-origin[1];
		Slice[i]=getResult("Slice",i);
	}
	//resorts points left to right
	Array.sort(X,Y,Slice);
	Array.sort(Slice,X,Y);
	
	//saves translated measurements
	Array.show(mode+"Results", X,Y,Slice);
	if (File.exists(path+mode+"Results.csv")==0) {
		saveAs("Results", path+mode+"Results.csv");
	}else {
		i=1;
		while (File.exists(path+mode+"Results"+i+".csv")) {
			i++;
		}
		saveAs("Results", path+mode+"Results"+i+".csv");
	}
	
	//saves stack as a gif unless use existing gif option was chosen
	if (existinggif==0) {
		if (File.exists(path+"stack.gif")==0) {
			saveAs("Gif", path+"stack.gif");
		}else {
			i=1;
			while (File.exists(path+"stack"+i+".gif")) {
				i++;
			}
			saveAs("Gif", path+"stack"+i+".gif");
		}
	}
	//checks to see if user wants to continue making measurements
	Dialog.create("Continue measuring?");
	options=newArray("Yes","No");
	Dialog.addRadioButtonGroup("Continue making measurements?", options, 1, 2, "Yes");
	Dialog.show();
	proceed=(Dialog.getRadioButton()=="Yes");
	if(proceed){
		close("*");
		selectWindow(mode+"Results.csv");
		run("Close");
		close("Results");
	}
}while (proceed)

