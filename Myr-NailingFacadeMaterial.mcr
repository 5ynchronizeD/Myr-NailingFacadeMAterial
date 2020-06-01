#Version 8
#BeginDescription
Last modified by: Anno Sportel (anno.sportel@hsbcad.com)
02.09.2015  -  version 1.08



























#End
#Type O
#NumBeamsReq 0
#NumPointsGrip 0
#DxaOut 1
#ImplInsert 1
#FileState 1
#MajorVersion 1
#MinorVersion 8
#KeyWords 
#BeginContents
/// <summary Lang=en>
/// This tsl takes care of the nailing of the facade materials. Each material has some specific nailing positions
/// </summary>

/// <insert>
/// 
/// </insert>

/// <remark Lang=en>
/// .
/// </remark>

/// <version  value="1.08" date="02.09.2015"></version>

/// <history>
/// AS - 1.00 - 19.10.2009 -	Pilot version
/// AS - 1.01 - 21.10.2009 -	Add a filter on labels
/// AS - 1.02 - 31.08.2010 -	Added a material
/// AS - 1.03 - 01.09.2010 -	Add options to check if nail is not too close to the edge.
/// AS - 1.04 - 01.09.2010 -	Use vertex points to find extremes of sheet to nail
/// AS - 1.05 - 11.06.2015 -	Add support for multiple element selection
/// AS - 1.06 - 01.09.2015 -	Remove extra space in "Panelbräda P81", add option to recalculate nail positions
/// AS - 1.07 - 01.09.2015 -	Add option to add or remove multiple nails at once. Add material filter.
/// AS - 1.08 - 02.09.2015 -	Change nail positions for CL walls
/// </history>

double dEps = U(.1,"mm");

String arSMaterial[0];								String arSNailPosition[0];				double arDToEdge[0];
arSMaterial.append("Panelbräda P81");			arSNailPosition.append("55;65");		arDToEdge.append(U(0));		// CL - horizontal - zn3
arSMaterial.append("Funkispanel");				arSNailPosition.append("30;45");		arDToEdge.append(U(0));		// CF - vertical - zn3
arSMaterial.append("Underbräda 21x145");		arSNailPosition.append("73");		arDToEdge.append(U(0));		// CC - vertical - zn3
arSMaterial.append("Lockläkt");					arSNailPosition.append("23");		arDToEdge.append(U(0));		// CC - vertical - zn4
arSMaterial.append("Underbräda 15x86");		arSNailPosition.append("43");		arDToEdge.append(U(0));		// CA - vertical - zn3
arSMaterial.append("Underbräda 21x86");		arSNailPosition.append("43");		arDToEdge.append(U(0));		// CA - vertical - zn3
arSMaterial.append("Överbräda");				arSNailPosition.append("30;50");		arDToEdge.append(U(0));		// CA - vertical - zn4

// tool index
int nToolingIndex = 1;

String categories[] = {
	T("|Filter|"),
	T("|Generation|"),
	T("|Nailing|"),
	T("|Visualization|")
};


// distance to edge of zone 2
PropDouble dToEdgeZn02(0, U(0), T("Distance to edge of spikregel"));
dToEdgeZn02.setDescription(T("|Sets the distance to the edge of zone| 2"));
dToEdgeZn02.setCategory(categories[2]);
PropDouble dMinDistToEdgeZn03(1, U(15), T("|Distance to end of sheet (zone 3)|"));
dMinDistToEdgeZn03.setDescription(T("|Sets the distance to the end of the sheeting in zone| 3"));
dMinDistToEdgeZn03.setCategory(categories[2]);
PropDouble dMinDistToEdgeZn04(2, U(15), T("|Distance to end of sheet (zone 4)|"));
dMinDistToEdgeZn04.setDescription(T("|Sets the distance to the end of the sheeting in zone| 4"));
dMinDistToEdgeZn04.setCategory(categories[2]);


String elementFilterCatalogNames[] = TslInst().getListOfCatalogNames("hsbElementFilter");
elementFilterCatalogNames.insertAt(0, T("|Do not use an element filter|"));
PropString elementFilter(2, elementFilterCatalogNames, T("|Element filter catalog|"));
elementFilter.setDescription(T("|Sets the element filter to use.|"));
elementFilter.setCategory(categories[0]);
// filter GenBeams with label
PropString sFilterLabel(0,"",T("Filter sheets with label"));
sFilterLabel.setDescription(T("|Sheets with one of the specified labels are exclued.|"));
sFilterLabel.setCategory(categories[0]);
PropString sFilterMaterial(3,"",T("Filter sheets with material"));
sFilterMaterial.setDescription(T("|Sheets with one of the specified materials are exclued.|"));
sFilterMaterial.setCategory(categories[0]);


PropInt sequenceForGeneration(0, 0, T("|Sequence number|"));
sequenceForGeneration.setDescription(T("|The sequence number is used to sort the list of tsls during the generation of the element.|"));
sequenceForGeneration.setCategory(categories[1]);
// Set the sequence for execution on generate construction.
_ThisInst.setSequenceNumber(sequenceForGeneration);

// display representation to draw the obejct in
PropString sDispRep(1, _ThisInst.dispRepNames(), T("|Draw in display representation|"));
sDispRep.setDescription(T("|Sets the display representation to draw the nails in.|"));
sDispRep.setCategory(categories[3]);
// Set properties if inserted with an execute key

// Is it an initial insert by the tool inserter? Return and wait for recalc. Recalc is triggered by master after the props are set.
int executeMode = -1;
if (_Map.hasInt("ExecuteMode")) 
	executeMode = _Map.getInt("ExecuteMode");
if (executeMode == 69)
	return;

String arSCatalogNames[] = TslInst().getListOfCatalogNames("Myr-NailingFacadeMaterial");
if( arSCatalogNames.find(_kExecuteKey) != -1 ) 
	setPropValuesFromCatalog(_kExecuteKey);

if( _bOnInsert ){
	if( insertCycleCount() > 1 ){
		eraseInstance();
		return;
	}
	
	if( _kExecuteKey == "" || arSCatalogNames.find(_kExecuteKey) == -1 )
		showDialog();
	
	int nNrOfTslsInserted = 0;
	PrEntity ssE(T("Select a set of elements"), ElementWallSF());

	if( ssE.go() ){
		Element arSelectedElement[0];
		if (elementFilter !=  elementFilterCatalogNames[0]) {
			Entity selectedEntities[] = ssE.set();
			Map elementFilterMap;
			elementFilterMap.setEntityArray(selectedEntities, false, "Elements", "Elements", "Element");
			TslInst().callMapIO("hsbElementFilter", elementFilter, elementFilterMap);
			
			Entity filteredEntities[] = elementFilterMap.getEntityArray("Elements", "Elements", "Element");
			for (int i=0;i<filteredEntities.length();i++) {
				Element el = (Element)filteredEntities[i];
				if (!el.bIsValid())
					continue;
				arSelectedElement.append(el);
			}
		}
		else {
			arSelectedElement = ssE.elementSet();
		}
		
		String strScriptName = "Myr-NailingFacadeMaterial"; // name of the script
		Vector3d vecUcsX(1,0,0);
		Vector3d vecUcsY(0,1,0);
		Beam lstBeams[0];
		Element lstElements[1];
		
		Point3d lstPoints[0];
		int lstPropInt[0];
		double lstPropDouble[0];
		String lstPropString[0];
		Map mapTsl;
		mapTsl.setInt("MasterToSatellite", true);
		mapTsl.setInt("ManualInsert", true);
		setCatalogFromPropValues("MasterToSatellite");
				
		for( int e=0;e<arSelectedElement.length();e++ ){
			Element el = arSelectedElement[e];
			
			lstElements[0] = el;

			TslInst tsl;
			tsl.dbCreate(strScriptName, vecUcsX,vecUcsY,lstBeams, lstElements, lstPoints, lstPropInt, lstPropDouble, lstPropString, _kModelSpace, mapTsl);
			nNrOfTslsInserted++;
		}
	}
	
	reportMessage(nNrOfTslsInserted + T(" |tsl(s) inserted|"));
	
	eraseInstance();
	return;
}

if( _Map.hasInt("MasterToSatellite") ){
	int bMasterToSatellite = _Map.getInt("MasterToSatellite");
	if( bMasterToSatellite ){
		int bPropertiesSet = _ThisInst.setPropValuesFromCatalog("MasterToSatellite");
		_Map.removeAt("MasterToSatellite", TRUE);
	}
}

int bManualInsert = false;
if( _Map.hasInt("ManualInsert") ){
	bManualInsert = _Map.getInt("ManualInsert");
	_Map.removeAt("ManualInsert", true);
}

if (_Element.length() == 0) {
	reportError(T("|No element selected|"));
	eraseInstance();
	return;
}

ElementWallSF el= (ElementWallSF) _Element[0];
if (!el.bIsValid()) { 
	eraseInstance();
	return;
}

String sFLabel = sFilterLabel + ";";
String arSFLabel[0];
int nIndexLabel = 0; 
int sIndexLabel = 0;
while(sIndexLabel < sFLabel.length()-1){
	String sTokenLabel = sFLabel.token(nIndexLabel);
	nIndexLabel++;
	if(sTokenLabel.length()==0){
		sIndexLabel++;
		continue;
	}
	sIndexLabel = sFilterLabel.find(sTokenLabel,0);

	arSFLabel.append(sTokenLabel.makeUpper());
}

String sFMaterial = sFilterMaterial + ";";
String arSFMaterial[0];
int nIndexMaterial = 0; 
int sIndexMaterial = 0;
while(sIndexMaterial < sFMaterial.length()-1){
	String sTokenMaterial = sFMaterial.token(nIndexMaterial);
	nIndexMaterial++;
	if(sTokenMaterial.length()==0){
		sIndexMaterial++;
		continue;
	}
	sIndexMaterial = sFilterMaterial.find(sTokenMaterial,0);

	arSFMaterial.append(sTokenMaterial.makeUpper());
}
// remove duplicates
TslInst arTsl[] = el.tslInst();
for( int i=0;i<arTsl.length();i++ ){
	TslInst tsl = arTsl[i];
	
	if( tsl.scriptName() == _ThisInst.scriptName() && tsl.handle() != _ThisInst.handle() )
		tsl.dbErase();
}

// coordinate system of this element
CoordSys csEl = el.coordSys();
Point3d ptEl = csEl.ptOrg();
Vector3d vxEl = csEl.vecX();
Vector3d vyEl = csEl.vecY();
Vector3d vzEl = csEl.vecZ();

Plane pnZ(ptEl, vzEl);

// sheets
Sheet arSh[] = el.sheet();
Sheet arShZn02[0];
Sheet arShZn03[0];
Sheet arShZn04[0];

// sort sheeting per zone
for( int i=0;i<arSh.length();i++ ){
	Sheet sh = arSh[i];
	if( arSFLabel.find(sh.label().makeUpper()) != -1 ){
		// filter labels: do nothing; sheet not added
	}
	else if( arSFMaterial.find(sh.material().makeUpper()) != -1 ){
		// filter labels: do nothing; sheet not added
	}
	else if( sh.myZoneIndex() == 2 ){//Spikregel
		arShZn02.append(sh);
	}
	else if( sh.myZoneIndex() == 3 ){
		arShZn03.append(sh);
	}
	else if( sh.myZoneIndex() == 4 ){
		arShZn04.append(sh);
	}
	else{
		
	}
}
// merge 2 arrays
Sheet arShToNail[0];
arShToNail.append(arShZn03);
arShToNail.append(arShZn04);

// find points to nail
Point3d arPtToNail[0];
int arNZoneIndex[0];
// list of materials which can not be found in list at the top
String arSMaterialsToAdd[0];
// run through all spikregel
for( int i=0;i<arShZn02.length();i++ ){
	Sheet shZn02 = arShZn02[i];
	Body bdShZn02 = shZn02.realBody();
	
	PlaneProfile ppShZn02(csEl);
	ppShZn02 = bdShZn02.shadowProfile(pnZ);
	
	//Coordsys of sheet in zone 2
	Point3d pt02 = shZn02.ptCen();
	Vector3d vx02 = shZn02.vecY();
	Vector3d vy02 = shZn02.vecX();
	if( bdShZn02.lengthInDirection(vx02) < bdShZn02.lengthInDirection(vy02) ){
		vx02 = shZn02.vecX();
		vy02 = shZn02.vecY();
	}
	Vector3d vz02 = vx02.crossProduct(vy02);
	CoordSys cs02(pt02, vx02, vy02, vz02);
	cs02.vis();
	
	Point3d ptMinShZn02 = bdShZn02.ptCen() - vx02 * (.5 * bdShZn02.lengthInDirection(vx02) - dToEdgeZn02); ptMinShZn02.vis(2);
	Point3d ptMaxShZn02 = bdShZn02.ptCen() + vx02 * (.5 * bdShZn02.lengthInDirection(vx02) - dToEdgeZn02); ptMaxShZn02.vis(3);
	Plane pnZn02(pt02, vy02);
	
	for( int j=0;j<arShToNail.length();j++ ){
		Sheet shToNail = arShToNail[j];
		Body bdShToNail = shToNail.realBody();
		
		//Coordsys of sheet
		Point3d ptSh = shToNail.ptCen();
		Vector3d vxSh = shToNail.vecY();
		Vector3d vySh = shToNail.vecX();
		if( bdShToNail.lengthInDirection(vxSh) < bdShToNail.lengthInDirection(vySh) ){
			vxSh = shToNail.vecX();
			vySh = shToNail.vecY();
		}
		Vector3d vzSh = vxSh.crossProduct(vySh);
		CoordSys csSh(ptSh, vxSh, vySh, vzSh);
		csSh.vis();
		
		Line lnShX(ptSh, vxSh);
				
		String sMaterial = shToNail.material();
		int nMaterialIndex = arSMaterial.find(sMaterial);
		if( nMaterialIndex < 0 ){
			if( arSMaterialsToAdd.find(sMaterial) == -1 ){
				arSMaterialsToAdd.append(sMaterial);
				reportMessage(TN("|Material not found! - |") + sMaterial);
			}
			continue;
		}
		
		// zone index
		int nZoneIndex = shToNail.myZoneIndex();		
		double dToEdge = arDToEdge[nMaterialIndex];
		
		// 
		if( vxSh.isPerpendicularTo(vy02) )
			continue;
		
		// reference point for position nailing
		Point3d ptReference = ptSh + vySh * .5 * bdShToNail.lengthInDirection(vySh);
		
		// extremes
		Point3d arPtSh[] = bdShToNail.allVertices();
		Point3d arPtShX[] = lnShX.orderPoints(arPtSh);
		if( arPtShX.length() < 2 )
			continue;
		Point3d ptMinSh = ptSh + vxSh * vxSh.dotProduct(arPtShX[0] - ptSh);		//bdShToNail.ptCen() - vxSh * (.5 * bdShToNail.lengthInDirection(vxSh) - dToEdge); ptMinShZn02.vis(2);
		Point3d ptMaxSh = ptSh + vxSh * vxSh.dotProduct(arPtShX[arPtShX.length() - 1] - ptSh);	//bdShToNail.ptCen() + vxSh * (.5 * bdShToNail.lengthInDirection(vxSh) - dToEdge); ptMaxShZn02.vis(3);

		// find the nail positions
		String sNailPosition = arSNailPosition[nMaterialIndex];
		double arDNailPosition[0];
		int nIndex = 0;
		while( TRUE ){
			String sToken = sNailPosition.token(nIndex);
			if( sToken == "" || nIndex > 2 )
				break;
			
			// add this token
			arDNailPosition.append(sToken.atof());
			
			// get next
			nIndex++;
		}
		
		for( int k=0;k<arDNailPosition.length();k++ ){
			double dNailPosition = arDNailPosition[k];
			ptReference -= vySh * dNailPosition;
			Line lnShToNail(ptReference, vxSh);
			
			Point3d ptToNail = lnShToNail.intersect(pnZn02, 0);
			
			if( (vx02.dotProduct(ptToNail - ptMinShZn02) * vx02.dotProduct(ptToNail - ptMaxShZn02)) > 0 )continue;
			
			double dMinDistToEdgeZn = dMinDistToEdgeZn03;
			if( nZoneIndex == 4 )
				dMinDistToEdgeZn = dMinDistToEdgeZn04;
bdShToNail.vis();
ptMinSh.vis();
ptMaxSh.vis();
			if( abs(vxSh.dotProduct(ptToNail - ptMinSh)) < dMinDistToEdgeZn ){
				ptToNail += vxSh * vxSh.dotProduct(ptMinSh + vxSh * dMinDistToEdgeZn - ptToNail);
				if( ppShZn02.pointInProfile(ptToNail) != _kPointInProfile )
					continue;
			}
			if( abs(vxSh.dotProduct(ptToNail - ptMaxSh)) < dMinDistToEdgeZn ){
				ptToNail += vxSh * vxSh.dotProduct(ptMaxSh - vxSh * dMinDistToEdgeZn - ptToNail);
				if( ppShZn02.pointInProfile(ptToNail) != _kPointInProfile )
					continue;
			}			
			if( (vxSh.dotProduct(ptToNail - ptMinSh) * vxSh.dotProduct(ptToNail - ptMaxSh)) > 0 )continue;
			
			
			arPtToNail.append(ptToNail);
			arNZoneIndex.append(nZoneIndex);
		}
	}
}

// add special context menu action to trigger the regeneration of the constuction
String sTriggerAddNailZn03 = T("Add nails to zone 3");
addRecalcTrigger(_kContext, sTriggerAddNailZn03 );
String sTriggerAddNailZn04 = T("Add nails to zone 4");
addRecalcTrigger(_kContext, sTriggerAddNailZn04 );
String sTriggerRemoveNail = T("Remove nails");
addRecalcTrigger(_kContext, sTriggerRemoveNail );
String sTriggerRecalc = T("|Recalculate nail positions|");
addRecalcTrigger(_kContext, sTriggerRecalc);

if( _kExecuteKey==sTriggerAddNailZn03 ){
	Point3d ptLast = getPoint(T("|Select a point to add to zone 3|"));
	_PtG.append(ptLast);
	_Map.setInt((_PtG.length() - 1), 3);
	
	while (true) {
		PrPoint ssP2(T("|Select next point|"), ptLast); 
		if (ssP2.go()==_kOk) {
			ptLast = ssP2.value();
			_PtG.append(ptLast);
			_Map.setInt((_PtG.length() - 1), 3);
		}
		else {
			break;
		}
	}
}

if( _kExecuteKey==sTriggerAddNailZn04 ){
	Point3d ptLast = getPoint(T("|Select a point to add to zone 4|"));
	_PtG.append(ptLast);
	_Map.setInt((_PtG.length() - 1), 4);
	
	while (true) {
		PrPoint ssP2(T("|Select next point|"), ptLast); 
		if (ssP2.go()==_kOk) {
			ptLast = ssP2.value();
			_PtG.append(ptLast);
			_Map.setInt((_PtG.length() - 1), 4);
		}
		else {
			break;
		}
	}
}

if( _kExecuteKey==sTriggerRemoveNail ){
	Point3d arPtToRemove[0];
	Point3d ptLast = getPoint(T("|Select a point to remove|"));
	arPtToRemove.append(ptLast);
	
	while (true) {
		PrPoint ssP2(T("|Select next point|"), ptLast); 
		if (ssP2.go()==_kOk) {
			ptLast = ssP2.value();
			arPtToRemove.append(ptLast);
		}
		else {
			break;
		}
	}

	if( !_Map.hasInt( String(_PtG.length()-1) ) ){
		reportError(TN("|Internal error|!") + TN("|Indexes don't match grippoints|!"));
	}
	
	Point3d arPtNailTmp[0];
	int arNZoneIndexFromNailTmp[0];
	for( int i=0;i<_PtG.length();i++ ){
		Point3d pt = _PtG[i];
		if( !_Map.hasInt(String(i)) )reportError(TN("|Internal error|!") + TN("|Index not found in map|!"));
		int nZone = _Map.getInt(String(i));
		
		int bKeepNail = true;
		for (int p=0;p<arPtToRemove.length();p++) {
			Point3d ptToRemove = arPtToRemove[p];
			
			if( Vector3d(pt - (ptToRemove + vzEl * vzEl.dotProduct(pt - ptToRemove))).length() < U(5) ){
				bKeepNail = false;
			}
		}
		if (bKeepNail) {
			arPtNailTmp.append(pt);
			arNZoneIndexFromNailTmp.append(nZone);
		}
	}
	
	_PtG.setLength(0);
	_PtG.append(arPtNailTmp);
	
	_Map = Map();
	for( int i=0;i<arNZoneIndexFromNailTmp.length();i++ ){
		_Map.setInt(String(i), arNZoneIndexFromNailTmp[i]);
	}
}

if( _kExecuteKey==sTriggerRecalc ){
	_PtG.setLength(0);
}

if( _PtG.length() == 0 ){
	_PtG.append(arPtToNail);

	_Map = Map();
	for( int i=0;i<arNZoneIndex.length();i++ ){
		_Map.setInt(String(i), arNZoneIndex[i]);
	}
}
else{
	_Pt0 = _PtG[0];
}

Point3d arPtToNailZn03[0];
Point3d arPtToNailZn04[0];

Display dp03(-1);
dp03.elemZone(el, 3, 'E');
dp03.textHeight(U(10));
dp03.showInDispRep(sDispRep);

Display dp04(-1);
dp04.elemZone(el, 4, 'E');
dp04.textHeight(U(10));
dp04.showInDispRep(sDispRep);

for( int i=0;i<_PtG.length();i++ ){
	Point3d pt = _PtG[i];
	if( !_Map.hasInt(String(i)) )reportError(T("\nInternal error!\nIndex not found in map"));
	int nIndex = _Map.getInt(String(i));

//	int nIndex = arNZoneIndexFromNail[i];
	
	if( nIndex==3 ){
		arPtToNailZn03.append(pt);
		dp03.draw("3", pt, vxEl, vyEl, 0, 0, _kDevice);
	}
	else if( nIndex==4 ){
		arPtToNailZn04.append(pt);
		dp04.draw("4", pt, vxEl, vyEl, 0, 0, _kDevice);
	}
	else{
		reportError(T("\nPoint at wrong zone"));
	}
}

if( arPtToNailZn03.length() > 0 ){
	ElemNailCluster elNailClusterForZn03( 3, arPtToNailZn03, nToolingIndex );
	el.addTool(elNailClusterForZn03);
}

if( arPtToNailZn04.length() > 0 ){
	ElemNailCluster elNailClusterForZn04( 4, arPtToNailZn04, nToolingIndex );
	el.addTool(elNailClusterForZn04);
}

assignToElementGroup(el,TRUE,0,'E');




#End
#BeginThumbnail





#End