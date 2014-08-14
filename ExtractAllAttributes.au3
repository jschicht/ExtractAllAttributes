#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Comment=Extract all NTFS attributes for given file
#AutoIt3Wrapper_Res_Description=Extract all NTFS attributes for given file
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Include <WinAPIEx.au3>
#include <Array.au3>
#Include <String.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#Include <FileConstants.au3>
;
; https://github.com/jschicht
; http://code.google.com/p/mft2csv/
;
Global $TargetImageFile, $Entries, $InputFile, $IsShadowCopy=False, $IsPhysicalDrive=False, $IsImage=False, $hDisk, $sBuffer, $ComboPhysicalDrives, $Combo
Global $OutPutPath=@ScriptDir, $InitState = False, $DATA_Clusters, $AttributeOutFileName, $DATA_InitSize, $ImageOffset, $ADS_Name, $bIndexNumber, $NonResidentFlag, $DATA_RealSize, $DataRun, $DATA_LengthOfAttribute
Global $TargetDrive = "", $ALInnerCouner, $MFTSize, $TargetOffset, $SectorsPerCluster,$MFT_Record_Size,$BytesPerCluster,$BytesPerSector,$MFT_Offset,$IsDirectory
Global $IsolatedAttributeList, $AttribListNonResident=0,$IsCompressed,$IsSparse
Global $RUN_VCN[1],$RUN_Clusters[1],$MFT_RUN_Clusters[1],$MFT_RUN_VCN[1],$DataQ[1],$AttribX[1],$AttribXType[1],$AttribXCounter[1],$sBuffer,$AttrQ[1]
Global Const $RecordSignature = '46494C45' ; FILE signature
Global Const $RecordSignatureBad = '44414142' ; BAAD signature
Global Const $STANDARD_INFORMATION = '10000000'
Global Const $ATTRIBUTE_LIST = '20000000'
Global Const $FILE_NAME = '30000000'
Global Const $OBJECT_ID = '40000000'
Global Const $SECURITY_DESCRIPTOR = '50000000'
Global Const $VOLUME_NAME = '60000000'
Global Const $VOLUME_INFORMATION = '70000000'
Global Const $DATA = '80000000'
Global Const $INDEX_ROOT = '90000000'
Global Const $INDEX_ALLOCATION = 'A0000000'
Global Const $BITMAP = 'B0000000'
Global Const $REPARSE_POINT = 'C0000000'
Global Const $EA_INFORMATION = 'D0000000'
Global Const $EA = 'E0000000'
Global Const $PROPERTY_SET = 'F0000000'
Global Const $LOGGED_UTILITY_STREAM = '00010000'
Global Const $ATTRIBUTE_END_MARKER = 'FFFFFFFF'
;Global Const $FileBasicInformation = 4
Global Const $FileInternalInformation = 6
Global Const $OBJ_CASE_INSENSITIVE = 0x00000040
Global Const $FILE_DIRECTORY_FILE = 0x00000002
Global Const $FILE_NON_DIRECTORY_FILE = 0x00000040
Global Const $FILE_RANDOM_ACCESS = 0x00000800
Global Const $tagIOSTATUSBLOCK = "dword Status;ptr Information"
Global Const $tagOBJECTATTRIBUTES = "ulong Length;hwnd RootDirectory;ptr ObjectName;ulong Attributes;ptr SecurityDescriptor;ptr SecurityQualityOfService"
Global Const $tagUNICODESTRING = "ushort Length;ushort MaximumLength;ptr Buffer"
Global Const $tagFILEINTERNALINFORMATION = "int IndexNumber;"

Opt("GUICloseOnESC", 1)
$Form = GUICreate("Extract All Attributes v1.0.0.1", 560, 280, -1, -1)
$ComboPhysicalDrives = GUICtrlCreateCombo("", 180, 5, 305, 20)
$buttonScanPhysicalDrives = GUICtrlCreateButton("Scan Physical", 5, 5, 80, 20)
$buttonScanShadowCopies = GUICtrlCreateButton("Scan Shadows", 90, 5, 80, 20)
$buttonTestPhysicalDrive = GUICtrlCreateButton("<-- Test it", 495, 5, 60, 20)
$Combo = GUICtrlCreateCombo("", 20, 40, 360, 20)
$buttonDrive = GUICtrlCreateButton("Rescan Mounted Drives", 425, 40, 130, 20)
$LabelDataRun = GUICtrlCreateLabel("IndexNumber (MFT ref/inode):",20,70,150,20)
$InputMFTRef = GUICtrlCreateInput("",170,70,70,20)
$LabelChoose = GUICtrlCreateLabel("<-- or -->:",250,70,80,20)
$buttonBrowseFile = GUICtrlCreateButton("Browse for file", 300, 70, 100, 20)
$ButtonOutput = GUICtrlCreateButton("Change Output", 430, 70, 100, 20)
$ButtonImage = GUICtrlCreateButton("Browse for image", 430, 95, 100, 20)
$ButtonStart = GUICtrlCreateButton("Start", 430, 120, 100, 20)
$myctredit = GUICtrlCreateEdit("Current output folder: " & $outputpath & @CRLF, 0, 150, 560, 130, $ES_AUTOVSCROLL + $WS_VSCROLL)
_GUICtrlEdit_SetLimitText($myctredit, 128000)
_GetMountedDrivesInfo()
GUISetState(@SW_SHOW)

While 1
	$nMsg = GUIGetMsg()
	Select

		Case $nMsg = $ButtonImage
			_ProcessImage()
			$IsImage = True
			$IsShadowCopy = False
			$IsPhysicalDrive = False
		Case $nMsg = $ButtonOutput
			$newoutputpath = FileSelectFolder("Select output folder.", "",7,$outputpath)
			If Not @error then
			_DisplayInfo("New output folder: " & $newoutputpath & @CRLF)
			$outputpath = $newoutputpath
			EndIf
		Case $nMsg = $ButtonStart
			_Main()
		Case $nMsg = $buttonDrive
			_GetMountedDrivesInfo()
			$IsImage = False
			$IsShadowCopy = False
			$IsPhysicalDrive = False
		Case $nMsg = $GUI_EVENT_CLOSE
			Exit
		Case $nMsg = $buttonScanPhysicalDrives
			_GetPhysicalDrives("PhysicalDrive")
			$IsShadowCopy = False
			$IsPhysicalDrive = True
			$IsImage = False
		Case $nMsg = $buttonScanShadowCopies
			_GetPhysicalDrives("GLOBALROOT\Device\HarddiskVolumeShadowCopy")
			$IsShadowCopy = True
			$IsPhysicalDrive = False
			$IsImage = False
		Case $nMsg = $buttonTestPhysicalDrive
			_TestPhysicalDrive()
		Case $nMsg = $buttonBrowseFile
			_BrowseInput()
			$IsShadowCopy = False
			$IsPhysicalDrive = False
			$IsImage = False
	EndSelect
WEnd

Func _Main()
	Global $Timerstart = TimerInit()
	Global $DataQ[1], $RUN_VCN[1], $RUN_Clusters[1],$AttribX[1], $AttribXType[1], $AttribXCounter[1]
	$ReadMftRef = GUICtrlRead($InputMFTRef)
	If 	$IsShadowCopy=False And $IsPhysicalDrive=False And $IsImage=False And $ReadMftRef="" And $InputFile="" Then
		_DisplayInfo("Error: Nothing to do" & @CRLF)
		Return
	EndIf
	Select
		Case $IsImage = True
			$TargetDrive = $TargetImageFile
			$ImageOffset = Int(StringMid(GUICtrlRead($Combo),10),2)
			_DisplayInfo(@CRLF & "Target is: " & GUICtrlRead($Combo) & @CRLF)
			_DisplayInfo("Target is: " & $TargetImageFile & @CRLF)
			_DisplayInfo("Volume at offset: " & $ImageOffset & @CRLF)
		Case $IsPhysicalDrive = True
			$TargetDrive = StringMid($TargetImageFile,5)
			$ImageOffset = Int(StringMid(GUICtrlRead($Combo),10),2)
			_DisplayInfo("Target drive is: " & $TargetImageFile & @CRLF)
			_DisplayInfo("Volume at offset: " & $ImageOffset & @CRLF)
		Case $IsShadowCopy = True
			$TargetDrive = StringMid($TargetImageFile,5)
			$ImageOffset = Int(StringMid(GUICtrlRead($Combo),10),2)
			_DisplayInfo("Target shadow is: " & $TargetImageFile & @CRLF)
		Case $InputFile<>""
			$TargetDrive = StringMid($InputFile,1,2)
			$hDisk = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
			If $hDisk = 0 Then
				_DisplayInfo("CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
				Return
			EndIf
			_WinAPI_SetFilePointerEx($hDisk, $ImageOffset, $FILE_BEGIN)
			$bIndexNumber = _GetIndexNumber($InputFile, $IsDirectory)
			If Not StringIsDigit($bIndexNumber) Or @error Then
				_DisplayInfo($bIndexNumber & @CRLF)
				Return
			EndIf
			_ExtractSystemfile($bIndexNumber)
			ConsoleWrite(@CRLF)
			_End($Timerstart)
			$InputFile=""
			Return
		Case StringIsDigit($ReadMftRef)
			$TargetDrive = StringMid(GUICtrlRead($Combo),1,2)
			$hDisk = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
			If $hDisk = 0 Then
				_DisplayInfo("CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
				Return
			EndIf
			$bIndexNumber = $ReadMftRef
			_DisplayInfo("Target is MFT Reference " & $bIndexNumber & " on " & $TargetDrive & @CRLF)
			_ExtractSystemfile($bIndexNumber)
			ConsoleWrite(@CRLF)
			_End($Timerstart)
			$InputFile=""
			Return
	EndSelect
	$hDisk = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
	If $hDisk = 0 Then
		_DisplayInfo("CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Return
	EndIf
	_WinAPI_SetFilePointerEx($hDisk, $ImageOffset, $FILE_BEGIN)
;	$CurrentFileOffset = DllCall('kernel32.dll', 'int', 'SetFilePointerEx', 'ptr', $hDisk, 'int64', 0, 'int64*', 0, 'dword', 1)
;	$CurrentFileOffset = $CurrentFileOffset[3];-$Record_Size
;	ConsoleWrite("$CurrentFileOffset: 0x" & Hex($CurrentFileOffset) & @CRLF)
	$bIndexNumber = $ReadMftRef
	_ExtractSystemfile($bIndexNumber)
	ConsoleWrite(@CRLF)
	_End($Timerstart)
	$InputFile=""
	Return
EndFunc

Func _BrowseInput()
	$InputFile = FileOpenDialog("Select target file",@ScriptDir,"All (*.*)",3)
	If @error Then Return ""
	_DisplayInfo("Selected inputfile: " & $InputFile & @CRLF)
	Return $InputFile
EndFunc

Func _GetIndexNumber($file, $mode)
	Local $IndexNumber
    Local $hNTDLL = DllOpen("ntdll.dll")
    Local $szName = DllStructCreate("wchar[260]")
    Local $sUS = DllStructCreate($tagUNICODESTRING)
    Local $sOA = DllStructCreate($tagOBJECTATTRIBUTES)
    Local $sISB = DllStructCreate($tagIOSTATUSBLOCK)
    Local $buffer = DllStructCreate("byte[16384]")
    Local $ret, $FILE_MODE
    If $mode == 0 Then
        $FILE_MODE = $FILE_NON_DIRECTORY_FILE
    Else
        $FILE_MODE = $FILE_DIRECTORY_FILE
    EndIf
    $file = "\??\" & $file
    DllStructSetData($szName, 1, $file)
    $ret = DllCall($hNTDLL, "none", "RtlInitUnicodeString", "ptr", DllStructGetPtr($sUS), "ptr", DllStructGetPtr($szName))
    DllStructSetData($sOA, "Length", DllStructGetSize($sOA))
    DllStructSetData($sOA, "RootDirectory", 0)
    DllStructSetData($sOA, "ObjectName", DllStructGetPtr($sUS))
    DllStructSetData($sOA, "Attributes", $OBJ_CASE_INSENSITIVE)
    DllStructSetData($sOA, "SecurityDescriptor", 0)
    DllStructSetData($sOA, "SecurityQualityOfService", 0)
    $ret = DllCall($hNTDLL, "int", "NtOpenFile", "hwnd*", "", "dword", $GENERIC_READ, "ptr", DllStructGetPtr($sOA), "ptr", DllStructGetPtr($sISB), _
                                "ulong", $FILE_SHARE_READ, "ulong", BitOR($FILE_MODE, $FILE_RANDOM_ACCESS))
	If NT_SUCCESS($ret[0]) Then
;		ConsoleWrite("NtOpenFile: Success" & @CRLF)
	Else
		ConsoleWrite("Error: NtOpenFile returned: 0x" & Hex($ret[0],8) & @CRLF)
		Return SetError(1,0,"Error: NtOpenFile returned: 0x" & Hex($ret[0],8))
	EndIf
    Local $hFile = $ret[1]
    $ret = DllCall($hNTDLL, "int", "NtQueryInformationFile", "hwnd", $hFile, "ptr", DllStructGetPtr($sISB), "ptr", DllStructGetPtr($buffer), _
                                "int", 16384, "ptr", $FileInternalInformation)

    If NT_SUCCESS($ret[0]) Then
        Local $pFSO = DllStructGetPtr($buffer)
		Local $sFSO = DllStructCreate($tagFILEINTERNALINFORMATION, $pFSO)
		Local $IndexNumber = DllStructGetData($sFSO, "IndexNumber")
    Else
        ConsoleWrite("Error: NtQueryInformationFile returned: 0x" & Hex($ret[0],8) & @CRLF)
		Return SetError(1,0,"Error: NtQueryInformationFile returned: 0x" & Hex($ret[0],8))
    EndIf
    $ret = DllCall($hNTDLL, "int", "NtClose", "hwnd", $hFile)
    DllClose($hNTDLL)
	Return $IndexNumber
EndFunc

Func _ExtractSystemfile($TargetFile)
	Global $DataQ[1], $RUN_VCN[1], $RUN_Clusters[1],$AttribX[1], $AttribXType[1], $AttribXCounter[1]
	If StringLen($TargetDrive)=1 Then $TargetDrive=$TargetDrive&":"
	_ReadBootSector($TargetDrive)
	$BytesPerCluster = $SectorsPerCluster*$BytesPerSector
	$MFTEntry = _FindMFT(0)
	_DecodeMFTRecord($MFTEntry,0)
	_DecodeDataQEntry($DataQ[1])
	$MFTSize = $DATA_RealSize
	Global $RUN_VCN[1], $RUN_Clusters[1]
	_ExtractDataRuns()
	$MFT_RUN_VCN = $RUN_VCN
	$MFT_RUN_Clusters = $RUN_Clusters
	_ExtractSingleFile(Int($TargetFile,2))
	_WinAPI_CloseHandle($hDisk)
EndFunc

Func _ExtractSingleFile($MFTReferenceNumber)
	Global $DataQ[1],$AttribX[1],$AttribXType[1],$AttribXCounter[1]				;clear array
	$MFTRecord = _FindFileMFTRecord($MFTReferenceNumber)
	If $MFTRecord = "" Then
		ConsoleWrite("Target " & $MFTReferenceNumber & " not found" & @CRLF)
		_DisplayInfo("Target " & $MFTReferenceNumber & " not found" & @CRLF)
		Return SetError(1,0,0)
	ElseIf StringMid($MFTRecord,3,8) <> $RecordSignature AND StringMid($MFTRecord,3,8) <> $RecordSignatureBad Then
		ConsoleWrite("Found record is not valid:" & @CRLF)
		_DisplayInfo("Found record is not valid:" & @CRLF)
		ConsoleWrite(_HexEncode($MFTRecord) & @crlf)
		Return SetError(1,0,0)
	EndIf
	_DecodeMFTRecord($MFTRecord,1)
	Return
EndFunc

Func _DecodeAttrList($TargetFile, $AttrList)
	Local $offset, $length, $nBytes, $hFile, $LocalAttribID, $LocalName, $ALRecordLength, $ALNameLength, $ALNameOffset
	If StringMid($AttrList, 17, 2) = "00" Then		;attribute list is in $AttrList
		$offset = Dec(_SwapEndian(StringMid($AttrList, 41, 4)))
		$List = StringMid($AttrList, $offset*2+1)
;		$IsolatedAttributeList = $list
	Else			;attribute list is found from data run in $AttrList
		$size = Dec(_SwapEndian(StringMid($AttrList, $offset*2 + 97, 16)))
		$offset = ($offset + Dec(_SwapEndian(StringMid($AttrList, $offset*2 + 65, 4))))*2
		$DataRun = StringMid($AttrList, $offset+1, StringLen($AttrList)-$offset)
;		ConsoleWrite("Attribute_List DataRun is " & $DataRun & @CRLF)
		Global $RUN_VCN[1], $RUN_Clusters[1]
		_ExtractDataRuns()
		$tBuffer = DllStructCreate("byte[" & $BytesPerCluster & "]")
		$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 6, 6)
		If $hFile = 0 Then
			ConsoleWrite("Error in function CreateFile when trying to locate Attribute List." & @CRLF)
			_DisplayInfo("Error in function CreateFile when trying to locate Attribute List." & @CRLF)
			_WinAPI_CloseHandle($hFile)
			Return SetError(1,0,0)
		EndIf
		$List = ""
		For $r = 1 To Ubound($RUN_VCN)-1
			_WinAPI_SetFilePointerEx($hFile, $RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
			For $i = 1 To $RUN_Clusters[$r]
				_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $BytesPerCluster, $nBytes)
				$List &= StringTrimLeft(DllStructGetData($tBuffer, 1),2)
			Next
		Next
;		_DebugOut("***AttrList New:",$List)
		_WinAPI_CloseHandle($hFile)
		$List = StringMid($List, 1, $size*2)
	EndIf
	$IsolatedAttributeList = $list
	$offset=0
	$str=""
	While StringLen($list) > $offset*2
		$type=StringMid($List, ($offset*2)+1, 8)
		$ALRecordLength = Dec(_SwapEndian(StringMid($List, $offset*2 + 9, 4)))
		$ALNameLength = Dec(_SwapEndian(StringMid($List, $offset*2 + 13, 2)))
		$ALNameOffset = Dec(_SwapEndian(StringMid($List, $offset*2 + 15, 2)))
		$TestVCN = Dec(_SwapEndian(StringMid($List, $offset*2 + 17, 16)))
		$ref=Dec(_SwapEndian(StringMid($List, $offset*2 + 33, 8)))
		$LocalAttribID = "0x" & StringMid($List, $offset*2 + 49, 2) & StringMid($List, $offset*2 + 51, 2)
		If $ALNameLength > 0 Then
			$LocalName = StringMid($List, $offset*2 + 53, $ALNameLength*2*2)
			$LocalName = _UnicodeHexToStr($LocalName)
		Else
			$LocalName = ""
		EndIf
		If $ref <> $TargetFile Then		;new attribute
			If Not StringInStr($str, $ref) Then $str &= $ref & "-"
		EndIf
		If $type=$DATA Then
			$DataInAttrlist=1
			$IsolatedData=StringMid($List, ($offset*2)+1, $ALRecordLength*2)
			If $TestVCN=0 Then $DataIsResident=1
		EndIf
		$offset += Dec(_SwapEndian(StringMid($List, $offset*2 + 9, 4)))
	WEnd
	If $str = "" Then
		ConsoleWrite("No extra MFT records found" & @CRLF)
		_DisplayInfo("No extra MFT records found" & @CRLF)
	Else
		$AttrQ = StringSplit(StringTrimRight($str,1), "-")
;		ConsoleWrite("Decode of $ATTRIBUTE_LIST reveiled extra MFT Records to be examined = " & _ArrayToString($AttrQ, @CRLF) & @CRLF)
	EndIf
EndFunc

Func _StripMftRecord($MFTEntry)
	$UpdSeqArrOffset = Dec(_SwapEndian(StringMid($MFTEntry,11,4)))
	$UpdSeqArrSize = Dec(_SwapEndian(StringMid($MFTEntry,15,4)))
	$UpdSeqArr = StringMid($MFTEntry,3+($UpdSeqArrOffset*2),$UpdSeqArrSize*2*2)

	If $MFT_Record_Size = 1024 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 Then
			_DebugOut("The record failed Fixup", $MFTEntry)
			Return ""
		EndIf
		$MFTEntry = StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2
	ElseIf $MFT_Record_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		Local $RecordEnd3 = StringMid($MFTEntry,3071,4)
		Local $RecordEnd4 = StringMid($MFTEntry,4095,4)
		Local $RecordEnd5 = StringMid($MFTEntry,5119,4)
		Local $RecordEnd6 = StringMid($MFTEntry,6143,4)
		Local $RecordEnd7 = StringMid($MFTEntry,7167,4)
		Local $RecordEnd8 = StringMid($MFTEntry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			_DebugOut("The record failed Fixup", $MFTEntry)
			Return ""
		Else
			$MFTEntry =  StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2 & StringMid($MFTEntry,2051,1020) & $UpdSeqArrPart3 & StringMid($MFTEntry,3075,1020) & $UpdSeqArrPart4 & StringMid($MFTEntry,4099,1020) & $UpdSeqArrPart5 & StringMid($MFTEntry,5123,1020) & $UpdSeqArrPart6 & StringMid($MFTEntry,6147,1020) & $UpdSeqArrPart7 & StringMid($MFTEntry,7171,1020) & $UpdSeqArrPart8
		EndIf
	EndIf

	$RecordSize = Dec(_SwapEndian(StringMid($MFTEntry,51,8)),2)
	$HeaderSize = Dec(_SwapEndian(StringMid($MFTEntry,43,4)),2)
	$MFTEntry = StringMid($MFTEntry,$HeaderSize*2+3,($RecordSize-$HeaderSize-8)*2)        ;strip "0x..." and "FFFFFFFF..."
	Return $MFTEntry
EndFunc

Func _DecodeDataQEntry($attr)		;processes data attribute
   $NonResidentFlag = StringMid($attr,17,2)
   $NameLength = Dec(StringMid($attr,19,2))
   $NameOffset = Dec(_SwapEndian(StringMid($attr,21,4)))
   If $NameLength > 0 Then		;must be ADS
	  $ADS_Name = _UnicodeHexToStr(StringMid($attr,$NameOffset*2 + 1,$NameLength*4))
   Else
	  $ADS_Name = ""
   EndIf
   $Flags = StringMid($attr,25,4)
   If BitAND($Flags,"0100") Then $IsCompressed = 1
   If BitAND($Flags,"0080") Then $IsSparse = 1
   If $NonResidentFlag = '01' Then
	  $DATA_Clusters = Dec(_SwapEndian(StringMid($attr,49,16)),2) - Dec(_SwapEndian(StringMid($attr,33,16)),2) + 1
	  $DATA_RealSize = Dec(_SwapEndian(StringMid($attr,97,16)),2)
	  $DATA_InitSize = Dec(_SwapEndian(StringMid($attr,113,16)),2)
	  $Offset = Dec(_SwapEndian(StringMid($attr,65,4)))
	  $DataRun = StringMid($attr,$Offset*2+1,(StringLen($attr)-$Offset)*2)
   ElseIf $NonResidentFlag = '00' Then
	  $DATA_LengthOfAttribute = Dec(_SwapEndian(StringMid($attr,33,8)),2)
	  $Offset = Dec(_SwapEndian(StringMid($attr,41,4)))
	  $DataRun = StringMid($attr,$Offset*2+1,$DATA_LengthOfAttribute*2)
   EndIf
EndFunc

Func _DecodeMFTRecord($MFTEntry,$MFTMode)
Local $MFTEntryOrig,$FN_Number,$DATA_Number,$SI_Number,$ATTRIBLIST_Number,$OBJID_Number,$SECURITY_Number,$VOLNAME_Number,$VOLINFO_Number,$INDEXROOT_Number,$INDEXALLOC_Number,$BITMAP_Number,$REPARSEPOINT_Number,$EAINFO_Number,$EA_Number,$PROPERTYSET_Number,$LOGGEDUTILSTREAM_Number
$HEADER_RecordRealSize = ""
$HEADER_MFTREcordNumber = ""
$UpdSeqArrOffset = Dec(_SwapEndian(StringMid($MFTEntry,11,4)))
$UpdSeqArrSize = Dec(_SwapEndian(StringMid($MFTEntry,15,4)))
$UpdSeqArr = StringMid($MFTEntry,3+($UpdSeqArrOffset*2),$UpdSeqArrSize*2*2)
	If $MFT_Record_Size = 1024 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 Then
			;_DebugOut("The record failed Fixup", $MFTEntry)
			ConsoleWrite("Error: the $MFT record is corrupt" & @CRLF)
			Return SetError(1,0,0)
		EndIf
		$MFTEntry = StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2
	ElseIf $MFT_Record_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		Local $RecordEnd3 = StringMid($MFTEntry,3071,4)
		Local $RecordEnd4 = StringMid($MFTEntry,4095,4)
		Local $RecordEnd5 = StringMid($MFTEntry,5119,4)
		Local $RecordEnd6 = StringMid($MFTEntry,6143,4)
		Local $RecordEnd7 = StringMid($MFTEntry,7167,4)
		Local $RecordEnd8 = StringMid($MFTEntry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			;_DebugOut("The record failed Fixup", $MFTEntry)
			ConsoleWrite("Error: the $MFT record is corrupt" & @CRLF)
			Return SetError(1,0,0)
		Else
			$MFTEntry =  StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2 & StringMid($MFTEntry,2051,1020) & $UpdSeqArrPart3 & StringMid($MFTEntry,3075,1020) & $UpdSeqArrPart4 & StringMid($MFTEntry,4099,1020) & $UpdSeqArrPart5 & StringMid($MFTEntry,5123,1020) & $UpdSeqArrPart6 & StringMid($MFTEntry,6147,1020) & $UpdSeqArrPart7 & StringMid($MFTEntry,7171,1020) & $UpdSeqArrPart8
		EndIf
	EndIf
$HEADER_RecordRealSize = Dec(_SwapEndian(StringMid($MFTEntry,51,8)),2)
If $UpdSeqArrOffset = 48 Then
	$HEADER_MFTREcordNumber = Dec(_SwapEndian(StringMid($MFTEntry,91,8)),2)
Else
	$HEADER_MFTREcordNumber = "NT style"
EndIf
$AttributeOffset = (Dec(StringMid($MFTEntry,43,2))*2)+3

While 1
	$AttributeType = StringMid($MFTEntry,$AttributeOffset,8)
	$AttributeSize = StringMid($MFTEntry,$AttributeOffset+8,8)
	$AttributeSize = Dec(_SwapEndian($AttributeSize),2)
	Select
		Case $AttributeType = $STANDARD_INFORMATION
;			$STANDARD_INFORMATION_ON = "TRUE"
			$SI_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $SI_Number)
			EndIf
		Case $AttributeType = $ATTRIBUTE_LIST
;			$ATTRIBUTE_LIST_ON = "TRUE"
			$ATTRIBLIST_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $ATTRIBLIST_Number)
			EndIf
			$MFTEntryOrig = $MFTEntry
			$AttrList = StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2)
			_DecodeAttrList($HEADER_MFTRecordNumber, $AttrList)		;produces $AttrQ - extra record list
			$str = ""
			For $i = 1 To $AttrQ[0]
				$record = _FindFileMFTRecord($AttrQ[$i])
				$str &= _StripMftRecord($record)		;no header or end marker
			Next
			$str &= "FFFFFFFF"		;add end marker
			$MFTEntry = StringMid($MFTEntry,1,($HEADER_RecordRealSize-8)*2+2) & $str       ;strip "FFFFFFFF..." first
   		Case $AttributeType = $FILE_NAME
;			$FILE_NAME_ON = "TRUE"
			$FN_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $FN_Number)
			EndIf
		Case $AttributeType = $OBJECT_ID
;			$OBJECT_ID_ON = "TRUE"
			$OBJID_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $OBJID_Number)
			EndIf
		Case $AttributeType = $SECURITY_DESCRIPTOR
;			$SECURITY_DESCRIPTOR_ON = "TRUE"
			$SECURITY_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $SECURITY_Number)
			EndIf
		Case $AttributeType = $VOLUME_NAME
;			$VOLUME_NAME_ON = "TRUE"
			$VOLNAME_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $VOLNAME_Number)
			EndIf
		Case $AttributeType = $VOLUME_INFORMATION
;			$VOLUME_INFORMATION_ON = "TRUE"
			$VOLINFO_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $VOLINFO_Number)
			EndIf
		Case $AttributeType = $DATA
;			$DATA_ON = "TRUE"
			$DATA_Number += 1
			_ArrayAdd($DataQ, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
		Case $AttributeType = $INDEX_ROOT
;			$INDEX_ROOT_ON = "TRUE"
			$INDEXROOT_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $INDEXROOT_Number)
			EndIf
		Case $AttributeType = $INDEX_ALLOCATION
;			$INDEX_ALLOCATION_ON = "TRUE"
			$INDEXALLOC_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $INDEXALLOC_Number)
			EndIf
		Case $AttributeType = $BITMAP
;			$BITMAP_ON = "TRUE"
			$BITMAP_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $BITMAP_Number)
			EndIf
		Case $AttributeType = $REPARSE_POINT
;			$REPARSE_POINT_ON = "TRUE"
			$REPARSEPOINT_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $REPARSEPOINT_Number)
			EndIf
		Case $AttributeType = $EA_INFORMATION
;			$EA_INFORMATION_ON = "TRUE"
			$EAINFO_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $EAINFO_Number)
			EndIf
		Case $AttributeType = $EA
;			$EA_ON = "TRUE"
			$EA_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $EA_Number)
			EndIf
		Case $AttributeType = $PROPERTY_SET
;			$PROPERTY_SET_ON = "TRUE"
			$PROPERTYSET_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $PROPERTYSET_Number)
			EndIf
		Case $AttributeType = $LOGGED_UTILITY_STREAM
;			$LOGGED_UTILITY_STREAM_ON = "TRUE"
			$LOGGEDUTILSTREAM_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $LOGGEDUTILSTREAM_Number)
			EndIf
		Case $AttributeType = $ATTRIBUTE_END_MARKER
			ExitLoop
	EndSelect
	$AttributeOffset += $AttributeSize*2
WEnd
If $MFTMode = 1 Then
; Do data attribute first
	For $i = 1 To UBound($DataQ) - 1
		_DecodeDataQEntry($DataQ[$i])
		$AttributeOutFileName = $OutPutPath & "\" & $bIndexNumber & "_$DATA_" & $ADS_Name & "_" & $i & ".bin"
		_DisplayInfo("Writing: " & $bIndexNumber & "_$DATA_" & $ADS_Name & "_" & $i & ".bin" & @CRLF)
		If $NonResidentFlag = '00' Then
			_ExtractResidentFile($AttributeOutFileName, $DATA_LengthOfAttribute, $MFTEntry)
		Else
			Global $RUN_VCN[1], $RUN_Clusters[1]
			$TotalClusters = $Data_Clusters
			$RealSize = $DATA_RealSize		;preserve file sizes
			If Not $InitState Then $DATA_InitSize = $DATA_RealSize
			$InitSize = $DATA_InitSize
			_ExtractDataRuns()
			If $TotalClusters * $BytesPerCluster >= $RealSize Then
				_ExtractFile($MFTEntry)
			Else 		 ;code to handle attribute list
				$Flag = $IsCompressed		;preserve compression state
				For $j = $i + 1 To UBound($DataQ) -1
					_DecodeDataQEntry($DataQ[$j])
					$TotalClusters += $Data_Clusters
					_ExtractDataRuns()
					If $TotalClusters * $BytesPerCluster >= $RealSize Then
						$DATA_RealSize = $RealSize		;restore file sizes
						$DATA_InitSize = $InitSize
						$IsCompressed = $Flag		;recover compression state
						_ExtractFile($MFTEntry)
						ExitLoop
					EndIf
				Next
				$i = $j
			EndIf
		EndIf
	Next
; Do the rest of the attributes
	For $i = 1 To UBound($AttribX) - 1
		_DecodeDataQEntry($AttribX[$i])
		$AttributeOutFileName = $OutPutPath & "\" & $bIndexNumber & "_" & _TranslateAttributeType($AttribXType[$i]) & "_" & $ADS_Name & "_" & $AttribXCounter[$i] & ".bin"
		_DisplayInfo("Writing: " & $bIndexNumber & "_" & _TranslateAttributeType($AttribXType[$i]) & "_" & $ADS_Name & "_" & $AttribXCounter[$i] & ".bin" & @CRLF)
		If $NonResidentFlag = '00' Then
			_ExtractResidentFile($AttributeOutFileName, $DATA_LengthOfAttribute, $MFTEntry)
		Else
			Global $RUN_VCN[1], $RUN_Clusters[1]
			$TotalClusters = $Data_Clusters
			$RealSize = $DATA_RealSize		;preserve file sizes
			If Not $InitState Then $DATA_InitSize = $DATA_RealSize
			$InitSize = $DATA_InitSize
			_ExtractDataRuns()
			If $TotalClusters * $BytesPerCluster >= $RealSize Then
				_ExtractFile($MFTEntry)
			Else 		 ;code to handle attribute list
				$Flag = $IsCompressed		;preserve compression state
				For $j = $i + 1 To UBound($AttribX) -1
					_DecodeDataQEntry($AttribX[$j])
					$TotalClusters += $Data_Clusters
					_ExtractDataRuns()
					If $TotalClusters * $BytesPerCluster >= $RealSize Then
						$DATA_RealSize = $RealSize		;restore file sizes
						$DATA_InitSize = $InitSize
						$IsCompressed = $Flag		;recover compression state
						_ExtractFile($MFTEntry)
						ExitLoop
					EndIf
				Next
				$i = $j
			EndIf
		EndIf
	Next
EndIf
EndFunc

Func _ExtractDataRuns()
	$r=UBound($RUN_Clusters)
	$i=1
	$RUN_VCN[0] = 0
	$BaseVCN = $RUN_VCN[0]
	If $DataRun = "" Then $DataRun = "00"
	Do
		$RunListID = StringMid($DataRun,$i,2)
		If $RunListID = "00" Then ExitLoop
		$i += 2
		$RunListClustersLength = Dec(StringMid($RunListID,2,1))
		$RunListVCNLength = Dec(StringMid($RunListID,1,1))
		$RunListClusters = Dec(_SwapEndian(StringMid($DataRun,$i,$RunListClustersLength*2)),2)
		$i += $RunListClustersLength*2
		$RunListVCN = _SwapEndian(StringMid($DataRun, $i, $RunListVCNLength*2))
		;next line handles positive or negative move
		$BaseVCN += Dec($RunListVCN,2)-(($r>1) And (Dec(StringMid($RunListVCN,1,1))>7))*Dec(StringMid("10000000000000000",1,$RunListVCNLength*2+1),2)
		If $RunListVCN <> "" Then
			$RunListVCN = $BaseVCN
		Else
			$RunListVCN = 0			;$RUN_VCN[$r-1]		;0
		EndIf
		If (($RunListVCN=0) And ($RunListClusters>16) And (Mod($RunListClusters,16)>0)) Then
		 ;may be sparse section at end of Compression Signature
			_ArrayAdd($RUN_Clusters,Mod($RunListClusters,16))
			_ArrayAdd($RUN_VCN,$RunListVCN)
			$RunListClusters -= Mod($RunListClusters,16)
			$r += 1
		ElseIf (($RunListClusters>16) And (Mod($RunListClusters,16)>0)) Then
		 ;may be compressed data section at start of Compression Signature
			_ArrayAdd($RUN_Clusters,$RunListClusters-Mod($RunListClusters,16))
			_ArrayAdd($RUN_VCN,$RunListVCN)
			$RunListVCN += $RUN_Clusters[$r]
			$RunListClusters = Mod($RunListClusters,16)
			$r += 1
		EndIf
	  ;just normal or sparse data
		_ArrayAdd($RUN_Clusters,$RunListClusters)
		_ArrayAdd($RUN_VCN,$RunListVCN)
		$r += 1
		$i += $RunListVCNLength*2
	Until $i > StringLen($DataRun)
EndFunc

Func _FindFileMFTRecord($TargetFile)
	Local $nBytes, $TmpOffset, $Counter, $Counter2, $RecordJumper, $TargetFileDec, $RecordsTooMuch
	$tBuffer = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 6, 6)
	If $hFile = 0 Then
		ConsoleWrite("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_DisplayInfo("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Return SetError(1,0,0)
	EndIf
	$TargetFile = _DecToLittleEndian($TargetFile)
	$TargetFileDec = Dec(_SwapEndian($TargetFile),2)
	Local $RecordsDivisor = $MFT_Record_Size/512
	For $i = 1 To UBound($MFT_RUN_Clusters)-1
		$CurrentClusters = $MFT_RUN_Clusters[$i]
		$RecordsInCurrentRun = ($CurrentClusters*$SectorsPerCluster)/$RecordsDivisor
		$Counter+=$RecordsInCurrentRun
		If $Counter>$TargetFileDec Then
			ExitLoop
		EndIf
	Next
	$TryAt = $Counter-$RecordsInCurrentRun
	$TryAtArrIndex = $i
	$RecordsPerCluster = $SectorsPerCluster/$RecordsDivisor
	Do
		$RecordJumper+=$RecordsPerCluster
		$Counter2+=1
		$Final = $TryAt+$RecordJumper
	Until $Final>=$TargetFileDec
	$RecordsTooMuch = $Final-$TargetFileDec
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset+$MFT_RUN_VCN[$i]*$BytesPerCluster+($Counter2*$BytesPerCluster)-($RecordsTooMuch*$MFT_Record_Size), $FILE_BEGIN)
	_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $MFT_Record_Size, $nBytes)
	$record = DllStructGetData($tBuffer, 1)
	If StringMid($record,91,8) = $TargetFile Then
		$TmpOffset = DllCall('kernel32.dll', 'int', 'SetFilePointerEx', 'ptr', $hFile, 'int64', 0, 'int64*', 0, 'dword', 1)
		ConsoleWrite("Record number: " & Dec(_SwapEndian($TargetFile),2) & " found at disk offset: " & $TmpOffset[3]-$MFT_Record_Size & " -> 0x" & Hex($TmpOffset[3]-$MFT_Record_Size) & @CRLF)
		_DisplayInfo("Record number: " & Dec(_SwapEndian($TargetFile),2) & " found at disk offset: " & $TmpOffset[3]-$MFT_Record_Size & " -> 0x" & Hex($TmpOffset[3]-$MFT_Record_Size) & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Return $record
	Else
		_WinAPI_CloseHandle($hFile)
		Return ""
	EndIf
EndFunc

Func _FindMFT($TargetFile)
	Local $nBytes;, $MFT_Record_Size=1024
	$tBuffer = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 2, 7)
	If $hFile = 0 Then
		ConsoleWrite("Error in function CreateFile when trying to locate MFT: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_DisplayInfo("Error in function CreateFile when trying to locate MFT: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Return SetError(1,0,0)
	EndIf
	ConsoleWrite("$MFT_Offset: " & $MFT_Offset & @CRLF)
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset+$MFT_Offset, $FILE_BEGIN)
	_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $MFT_Record_Size, $nBytes)
	_WinAPI_CloseHandle($hFile)
	$record = DllStructGetData($tBuffer, 1)
	If NOT StringMid($record,1,8) = '46494C45' Then
		ConsoleWrite("MFT record signature not found. "& @crlf)
		_DisplayInfo("MFT record signature not found. "& @crlf)
		Return ""
	EndIf
	If StringMid($record,47,4) = "0100" AND Dec(_SwapEndian(StringMid($record,91,8))) = $TargetFile Then
;		ConsoleWrite("MFT record found" & @CRLF)
		Return $record		;returns record for MFT
	EndIf
	ConsoleWrite("MFT record not found" & @CRLF)
	_DisplayInfo("MFT record not found" & @CRLF)
	Return ""
EndFunc

Func _DecToLittleEndian($DecimalInput)
	Return _SwapEndian(Hex($DecimalInput,8))
EndFunc

Func _SwapEndian($iHex)
	Return StringMid(Binary(Dec($iHex,2)),3, StringLen($iHex))
EndFunc

Func _UnicodeHexToStr($FileName)
	$str = ""
	For $i = 1 To StringLen($FileName) Step 4
		$str &= ChrW(Dec(_SwapEndian(StringMid($FileName, $i, 4))))
	Next
	Return $str
EndFunc

Func _DebugOut($text, $var)
	ConsoleWrite("Debug output for " & $text & @CRLF)
	For $i=1 To StringLen($var) Step 32
		$str=""
		For $n=0 To 15
			$str &= StringMid($var, $i+$n*2, 2) & " "
			if $n=7 then $str &= "- "
		Next
		ConsoleWrite($str & @CRLF)
	Next
EndFunc

Func _ReadBootSector($TargetDrive)
	Local $nbytes
	$tBuffer=DllStructCreate("byte[512]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
	If $hFile = 0 then
		ConsoleWrite("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		_DisplayInfo("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		Return SetError(1,0,0)
	EndIf
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset, $FILE_BEGIN)
	$read = _WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), 512, $nBytes)
	If $read = 0 then
		ConsoleWrite("Error in function ReadFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		_DisplayInfo("Error in function ReadFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		Return
	EndIf
	_WinAPI_CloseHandle($hFile)
   ; Good starting point from KaFu & trancexx at the AutoIt forum
	$tBootSectorSections = DllStructCreate("align 1;" & _
								"byte Jump[3];" & _
								"char SystemName[8];" & _
								"ushort BytesPerSector;" & _
								"ubyte SectorsPerCluster;" & _
								"ushort ReservedSectors;" & _
								"ubyte[3];" & _
								"ushort;" & _
								"ubyte MediaDescriptor;" & _
								"ushort;" & _
								"ushort SectorsPerTrack;" & _
								"ushort NumberOfHeads;" & _
								"dword HiddenSectors;" & _
								"dword;" & _
								"dword;" & _
								"int64 TotalSectors;" & _
								"int64 LogicalClusterNumberforthefileMFT;" & _
								"int64 LogicalClusterNumberforthefileMFTMirr;" & _
								"dword ClustersPerFileRecordSegment;" & _
								"dword ClustersPerIndexBlock;" & _
								"int64 NTFSVolumeSerialNumber;" & _
								"dword Checksum", DllStructGetPtr($tBuffer))

	$BytesPerSector = DllStructGetData($tBootSectorSections, "BytesPerSector")
	$SectorsPerCluster = DllStructGetData($tBootSectorSections, "SectorsPerCluster")
	$BytesPerCluster = $BytesPerSector * $SectorsPerCluster
	$ClustersPerFileRecordSegment = DllStructGetData($tBootSectorSections, "ClustersPerFileRecordSegment")
	$LogicalClusterNumberforthefileMFT = DllStructGetData($tBootSectorSections, "LogicalClusterNumberforthefileMFT")
	ConsoleWrite("BytesPerSector:  " & $BytesPerSector & @CRLF)
	ConsoleWrite("SectorsPerCluster:  " & $SectorsPerCluster & @CRLF)
	ConsoleWrite("ReservedSectors:  " & DllStructGetData($tBootSectorSections, "ReservedSectors") & @CRLF)
;	ConsoleWrite("MediaDescriptor:  " & DllStructGetData($tBootSectorSections, "MediaDescriptor") & @CRLF)
	ConsoleWrite("SectorsPerTrack:  " & DllStructGetData($tBootSectorSections, "SectorsPerTrack") & @CRLF)
	ConsoleWrite("NumberOfHeads:  " & DllStructGetData($tBootSectorSections, "NumberOfHeads") & @CRLF)
	ConsoleWrite("HiddenSectors:  " & DllStructGetData($tBootSectorSections, "HiddenSectors") & @CRLF)
	ConsoleWrite("TotalSectors:  " & DllStructGetData($tBootSectorSections, "TotalSectors") & @CRLF)
	ConsoleWrite("LogicalClusterNumberforthefileMFT:  " & $LogicalClusterNumberforthefileMFT & @CRLF)
	ConsoleWrite("LogicalClusterNumberforthefileMFTMirr:  " & DllStructGetData($tBootSectorSections, "LogicalClusterNumberforthefileMFTMirr") & @CRLF)
	ConsoleWrite("ClustersPerFileRecordSegment:  " & $ClustersPerFileRecordSegment & @CRLF)
;	ConsoleWrite("ClustersPerIndexBlock:  " & DllStructGetData($tBootSectorSections, "ClustersPerIndexBlock") & @CRLF)
;	ConsoleWrite("VolumeSerialNumber:  " & Ptr(DllStructGetData($tBootSectorSections, "NTFSVolumeSerialNumber")) & @CRLF)
;	ConsoleWrite("NTFSVolumeSerialNumber:  " & DllStructGetData($tBootSectorSections, "NTFSVolumeSerialNumber") & @CRLF)
;	ConsoleWrite("Checksum:  " & DllStructGetData($tBootSectorSections, "Checksum") & @CRLF)
	$MFT_Offset = $BytesPerCluster * $LogicalClusterNumberforthefileMFT
;	ConsoleWrite("$MFT_Offset: " & $MFT_Offset & @CRLF)
	If $ClustersPerFileRecordSegment > 127 Then
		$MFT_Record_Size = 2 ^ (256 - $ClustersPerFileRecordSegment)
	Else
		$MFT_Record_Size = $BytesPerCluster * $ClustersPerFileRecordSegment
	EndIf
;	ConsoleWrite("$MFT_Record_Size: " & $MFT_Record_Size & @crlf)
;	ConsoleWrite("$MFT_Offset:  " & $MFT_Offset & @CRLF)
	ConsoleWrite(@CRLF)
EndFunc

Func _HexEncode($bInput)
    Local $tInput = DllStructCreate("byte[" & BinaryLen($bInput) & "]")
    DllStructSetData($tInput, 1, $bInput)
    Local $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", 0, _
            "dword*", 0)

    If @error Or Not $a_iCall[0] Then
        Return SetError(1, 0, "")
    EndIf

    Local $iSize = $a_iCall[5]
    Local $tOut = DllStructCreate("char[" & $iSize & "]")

    $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", DllStructGetPtr($tOut), _
            "dword*", $iSize)

    If @error Or Not $a_iCall[0] Then
        Return SetError(2, 0, "")
    EndIf

    Return SetError(0, 0, DllStructGetData($tOut, 1))

EndFunc  ;==>_HexEncode

Func _File_Attributes($FAInput)
	Local $FAOutput = ""
	If BitAND($FAInput, 0x0001) Then $FAOutput &= 'read_only+'
	If BitAND($FAInput, 0x0002) Then $FAOutput &= 'hidden+'
	If BitAND($FAInput, 0x0004) Then $FAOutput &= 'system+'
	If BitAND($FAInput, 0x0010) Then $FAOutput &= 'directory+'
	If BitAND($FAInput, 0x0020) Then $FAOutput &= 'archive+'
	If BitAND($FAInput, 0x0040) Then $FAOutput &= 'device+'
	If BitAND($FAInput, 0x0080) Then $FAOutput &= 'normal+'
	If BitAND($FAInput, 0x0100) Then $FAOutput &= 'temporary+'
	If BitAND($FAInput, 0x0200) Then $FAOutput &= 'sparse_file+'
	If BitAND($FAInput, 0x0400) Then $FAOutput &= 'reparse_point+'
	If BitAND($FAInput, 0x0800) Then $FAOutput &= 'compressed+'
	If BitAND($FAInput, 0x1000) Then $FAOutput &= 'offline+'
	If BitAND($FAInput, 0x2000) Then $FAOutput &= 'not_indexed+'
	If BitAND($FAInput, 0x4000) Then $FAOutput &= 'encrypted+'
	If BitAND($FAInput, 0x8000) Then $FAOutput &= 'integrity_stream+'
	If BitAND($FAInput, 0x10000) Then $FAOutput &= 'virtual+'
	If BitAND($FAInput, 0x20000) Then $FAOutput &= 'no_scrub_data+'
	If BitAND($FAInput, 0x10000000) Then $FAOutput &= 'directory+'
	If BitAND($FAInput, 0x20000000) Then $FAOutput &= 'index_view+'
	$FAOutput = StringTrimRight($FAOutput, 1)
	Return $FAOutput
EndFunc

Func _End($begin)
	Local $timerdiff = TimerDiff($begin)
	$timerdiff = Round(($timerdiff / 1000), 2)
	ConsoleWrite("Job took " & $timerdiff & " seconds" & @CRLF)
	_DisplayInfo("Job took " & $timerdiff & " seconds" & @CRLF)
;	Exit
EndFunc

Func _ExtractFile($record)
	$cBuffer = DllStructCreate("byte[" & $BytesPerCluster * 16 & "]")
    $zflag = 0
	$hFile = _WinAPI_CreateFile($AttributeOutFileName,3,6,7)
	If $hFile Then
		Select
			Case UBound($RUN_VCN) = 1		;no data, do nothing
			Case UBound($RUN_VCN) = 2 	;may be normal or sparse
				If $RUN_VCN[1] = 0 And $IsSparse Then		;sparse
					$FileSize = _DoSparse(1, $hFile, $DATA_InitSize)
				Else								;normal
					$FileSize = _DoNormal(1, $hFile, $cBuffer, $DATA_InitSize)
				EndIf
		    Case Else					;may be compressed
				_DoCompressed($hFile, $cBuffer, $record)
		EndSelect
		If $DATA_RealSize > $DATA_InitSize Then
		    $FileSize = _WriteZeros($hfile, $DATA_RealSize - $DATA_InitSize)
		EndIf
		_WinAPI_CloseHandle($hFile)
		Return
	Else
		ConsoleWrite("Error creating output file: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_DisplayInfo("Error creating output file: " & _WinAPI_GetLastErrorMessage() & @CRLF)
	EndIf
EndFunc

Func _WriteZeros($hfile, $count)
   Local $nBytes
   If Not IsDllStruct($sBuffer) Then _CreateSparseBuffer()
   While $count > $BytesPerCluster * 16
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * 16, $nBytes)
	  $count -= $BytesPerCluster * 16
	  $ProgressSize = $DATA_RealSize - $count
   WEnd
   If $count <> 0 Then _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $count, $nBytes)
   $ProgressSize = $DATA_RealSize
   Return 0
EndFunc

Func _DoCompressed($hFile, $cBuffer, $record)
   Local $nBytes
   $r=1
   $FileSize = $DATA_InitSize
   $ProgressSize = $FileSize
   Do
	  _WinAPI_SetFilePointerEx($hDisk, $ImageOffset+$RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
	  $i = $RUN_Clusters[$r]
	  If (($RUN_VCN[$r+1]=0) And ($i+$RUN_Clusters[$r+1]=16) And $IsCompressed) Then
		 _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
		 $Decompressed = _LZNTDecompress($cBuffer, $BytesPerCluster * $i)
		 If IsString($Decompressed) Then
			If $r = 1 Then
			   _DebugOut("Decompression error for " & $ADS_Name, $record)
			Else
			   _DebugOut("Decompression error (partial write) for " & $ADS_Name, $record)
			EndIf
			Return
		 Else		;$Decompressed is an array
			Local $dBuffer = DllStructCreate("byte[" & $Decompressed[1] & "]")
			DllStructSetData($dBuffer, 1, $Decompressed[0])
		 EndIf
		 If $FileSize > $Decompressed[1] Then
			_WinAPI_WriteFile($hFile, DllStructGetPtr($dBuffer), $Decompressed[1], $nBytes)
			$FileSize -= $Decompressed[1]
			$ProgressSize = $FileSize
		 Else
			_WinAPI_WriteFile($hFile, DllStructGetPtr($dBuffer), $FileSize, $nBytes)
		 EndIf
		 $r += 1
	  ElseIf $RUN_VCN[$r]=0 Then
		 $FileSize = _DoSparse($r, $hFile, $FileSize)
		 $ProgressSize = 0
	  Else
		 $FileSize = _DoNormal($r, $hFile, $cBuffer, $FileSize)
		 $ProgressSize = 0
	  EndIf
	  $r += 1
   Until $r > UBound($RUN_VCN)-2
   If $r = UBound($RUN_VCN)-1 Then
	  If $RUN_VCN[$r]=0 Then
		 $FileSize = _DoSparse($r, $hFile, $FileSize)
		 $ProgressSize = 0
	  Else
		 $FileSize = _DoNormal($r, $hFile, $cBuffer, $FileSize)
		 $ProgressSize = 0
	  EndIf
   EndIf
EndFunc

Func _DoNormal($r, $hFile, $cBuffer, $FileSize)
   Local $nBytes
   _WinAPI_SetFilePointerEx($hDisk, $ImageOffset+$RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
   $i = $RUN_Clusters[$r]
   While $i > 16 And $FileSize > $BytesPerCluster * 16
	  _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * 16, $nBytes)
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $BytesPerCluster * 16, $nBytes)
	  $i -= 16
	  $FileSize -= $BytesPerCluster * 16
	  $ProgressSize = $FileSize
   WEnd
   If $i = 0 Or $FileSize = 0 Then Return $FileSize
   If $i > 16 Then $i = 16
   _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
   If $FileSize > $BytesPerCluster * $i Then
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
	  $FileSize -= $BytesPerCluster * $i
	  $ProgressSize = $FileSize
	  Return $FileSize
   Else
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $FileSize, $nBytes)
	  $ProgressSize = 0
	  Return 0
   EndIf
EndFunc

Func _DoSparse($r,$hFile,$FileSize)
   Local $nBytes
   If Not IsDllStruct($sBuffer) Then _CreateSparseBuffer()
   $i = $RUN_Clusters[$r]
   While $i > 16 And $FileSize > $BytesPerCluster * 16
	 _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * 16, $nBytes)
	 $i -= 16
	 $FileSize -= $BytesPerCluster * 16
	 $ProgressSize = $FileSize
   WEnd
   If $i <> 0 Then
 	 If $FileSize > $BytesPerCluster * $i Then
		_WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * $i, $nBytes)
		$FileSize -= $BytesPerCluster * $i
		$ProgressSize = $FileSize
	 Else
		_WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $FileSize, $nBytes)
		$ProgressSize = 0
		Return 0
	 EndIf
   EndIf
   Return $FileSize
EndFunc

Func _CreateSparseBuffer()
   Global $sBuffer = DllStructCreate("byte[" & $BytesPerCluster * 16 & "]")
   For $i = 1 To $BytesPerCluster * 16
	  DllStructSetData ($sBuffer, $i, 0)
   Next
EndFunc

Func _LZNTDecompress($tInput, $Size)	;note function returns a null string if error, or an array if no error
	Local $tOutput[2]
	Local $cBuffer = DllStructCreate("byte[" & $BytesPerCluster*16 & "]")
    Local $a_Call = DllCall("ntdll.dll", "int", "RtlDecompressBuffer", _
            "ushort", 2, _
            "ptr", DllStructGetPtr($cBuffer), _
            "dword", DllStructGetSize($cBuffer), _
            "ptr", DllStructGetPtr($tInput), _
            "dword", $Size, _
            "dword*", 0)

    If @error Or $a_Call[0] Then	;if $a_Call[0]=0 then output size is in $a_Call[6], otherwise $a_Call[6] is invalid
        Return SetError(1, 0, "") ; error decompressing
    EndIf
    Local $Decompressed = DllStructCreate("byte[" & $a_Call[6] & "]", DllStructGetPtr($cBuffer))
	$tOutput[0] = DllStructGetData($Decompressed, 1)
	$tOutput[1] = $a_Call[6]
    Return SetError(0, 0, $tOutput)
EndFunc

Func _ExtractResidentFile($Name, $Size, $record)
	Local $nBytes
	$xBuffer = DllStructCreate("byte[" & $Size & "]")
    DllStructSetData($xBuffer, 1, '0x' & $DataRun)
	$hFile = _WinAPI_CreateFile($Name,3,6,7)
	If $hFile Then
		_WinAPI_SetFilePointer($hFile, 0,$FILE_BEGIN)
		_WinAPI_WriteFile($hFile, DllStructGetPtr($xBuffer), $Size, $nBytes)
		_WinAPI_CloseHandle($hFile)
		Return
	Else
		ConsoleWrite("Error" & @CRLF)
	EndIf
EndFunc

Func _TranslateAttributeType($input)
	Local $RetVal
	Select
		Case $input = $STANDARD_INFORMATION
			$RetVal = "$STANDARD_INFORMATION"
		Case $input = $ATTRIBUTE_LIST
			$RetVal = "$ATTRIBUTE_LIST"
		Case $input = $FILE_NAME
			$RetVal = "$FILE_NAME"
		Case $input = $OBJECT_ID
			$RetVal = "$OBJECT_ID"
		Case $input = $SECURITY_DESCRIPTOR
			$RetVal = "$SECURITY_DESCRIPTOR"
		Case $input = $VOLUME_NAME
			$RetVal = "$VOLUME_NAME"
		Case $input = $VOLUME_INFORMATION
			$RetVal = "$VOLUME_INFORMATION"
		Case $input = $DATA
			$RetVal = "$DATA"
		Case $input = $INDEX_ROOT
			$RetVal = "$INDEX_ROOT"
		Case $input = $INDEX_ALLOCATION
			$RetVal = "$INDEX_ALLOCATION"
		Case $input = $BITMAP
			$RetVal = "$BITMAP"
		Case $input = $REPARSE_POINT
			$RetVal = "$REPARSE_POINT"
		Case $input = $EA_INFORMATION
			$RetVal = "$EA_INFORMATION"
		Case $input = $EA
			$RetVal = "$EA"
		Case $input = $PROPERTY_SET
			$RetVal = "$PROPERTY_SET"
		Case $input = $LOGGED_UTILITY_STREAM
			$RetVal = "$LOGGED_UTILITY_STREAM"
		Case $input = $ATTRIBUTE_END_MARKER
			$RetVal = "$ATTRIBUTE_END_MARKER"
	EndSelect
	Return $RetVal
EndFunc

Func NT_SUCCESS($status)
    If 0 <= $status And $status <= 0x7FFFFFFF Then
        Return True
    Else
        Return False
    EndIf
EndFunc

Func _DisplayInfo($DebugInfo)
	GUICtrlSetData($myctredit, $DebugInfo, 1)
EndFunc

Func _ProcessImage()
	$TargetImageFile = FileOpenDialog("Select image file",@ScriptDir,"All (*.*)")
	If @error then Return
	$TargetImageFile = "\\.\"&$TargetImageFile
	_DisplayInfo("Selected disk image file: " & $TargetImageFile & @CRLF)
	GUICtrlSetData($Combo,"","")
	$Entries = ''
	_CheckMBR()
	GUICtrlSetData($Combo,$Entries,StringMid($Entries, 1, StringInStr($Entries, "|") -1))
	If $Entries = "" Then _DisplayInfo("Sorry, no NTFS volume found in that file." & @CRLF)
EndFunc   ;==>_ProcessImage

Func _CheckMBR()
	Local $nbytes, $PartitionNumber, $PartitionEntry,$FilesystemDescriptor
	Local $StartingSector,$NumberOfSectors
	Local $hImage = _WinAPI_CreateFile($TargetImageFile,2,2,7)
	$tBuffer = DllStructCreate("byte[512]")
	Local $read = _WinAPI_ReadFile($hImage, DllStructGetPtr($tBuffer), 512, $nBytes)
	If $read = 0 Then Return ""
	Local $sector = DllStructGetData($tBuffer, 1)
	For $PartitionNumber = 0 To 3
		$PartitionEntry = StringMid($sector,($PartitionNumber*32)+3+892,32)
		If $PartitionEntry = "00000000000000000000000000000000" Then ExitLoop ; No more entries
		$FilesystemDescriptor = StringMid($PartitionEntry,9,2)
		$StartingSector = Dec(_SwapEndian(StringMid($PartitionEntry,17,8)),2)
		$NumberOfSectors = Dec(_SwapEndian(StringMid($PartitionEntry,25,8)),2)
		If ($FilesystemDescriptor = "EE" and $StartingSector = 1 and $NumberOfSectors = 4294967295) Then ; A typical dummy partition to prevent overwriting of GPT data, also known as "protective MBR"
			_CheckGPT($hImage)
		ElseIf $FilesystemDescriptor = "05" Or $FilesystemDescriptor = "0F" Then ;Extended partition
			_CheckExtendedPartition($StartingSector, $hImage)
		ElseIf $FilesystemDescriptor = "07" Then ;Marked as NTFS
			$Entries &= _GenComboDescription($StartingSector,$NumberOfSectors)
		EndIf
    Next
	If $Entries = "" Then ;Also check if pure partition image (without mbr)
		$NtfsVolumeSize = _TestNTFS($hImage, 0)
		If $NtfsVolumeSize Then $Entries = _GenComboDescription(0,$NtfsVolumeSize)
	EndIf
	_WinAPI_CloseHandle($hImage)
EndFunc   ;==>_CheckMBR

Func _CheckGPT($hImage) ; Assume GPT to be present at sector 1, which is not fool proof
   ;Actually it is. While LBA1 may not be at sector 1 on the disk, it will always be there in an image.
	Local $nbytes,$read,$sector,$GPTSignature,$StartLBA,$Processed=0,$FirstLBA,$LastLBA
	$tBuffer = DllStructCreate("byte[512]")
	$read = _WinAPI_ReadFile($hImage, DllStructGetPtr($tBuffer), 512, $nBytes)		;read second sector
	If $read = 0 Then Return ""
	$sector = DllStructGetData($tBuffer, 1)
	$GPTSignature = StringMid($sector,3,16)
	If $GPTSignature <> "4546492050415254" Then
		_DisplayInfo("Error: Could not find GPT signature" & @CRLF)
		Return
	EndIf
	$StartLBA = Dec(_SwapEndian(StringMid($sector,147,16)),2)
	$PartitionsInArray = Dec(_SwapEndian(StringMid($sector,163,8)),2)
	$PartitionEntrySize = Dec(_SwapEndian(StringMid($sector,171,8)),2)
	_WinAPI_SetFilePointerEx($hImage, $StartLBA*512, $FILE_BEGIN)
	$SizeNeeded = $PartitionsInArray*$PartitionEntrySize ;Set buffer size -> maximum number of partition entries that can fit in the array
	$tBuffer = DllStructCreate("byte[" & $SizeNeeded & "]")
	$read = _WinAPI_ReadFile($hImage, DllStructGetPtr($tBuffer), $SizeNeeded, $nBytes)
	If $read = 0 Then Return ""
	$sector = DllStructGetData($tBuffer, 1)
	Do
		$FirstLBA = Dec(_SwapEndian(StringMid($sector,67+($Processed*2),16)),2)
		$LastLBA = Dec(_SwapEndian(StringMid($sector,83+($Processed*2),16)),2)
		If $FirstLBA = 0 And $LastLBA = 0 Then ExitLoop ; No more entries
		$Processed += $PartitionEntrySize
		If Not _TestNTFS($hImage, $FirstLBA) Then ContinueLoop ;Continue the loop if filesystem not NTFS
		$Entries &= _GenComboDescription($FirstLBA,$LastLBA-$FirstLBA)
	Until $Processed >= $SizeNeeded
EndFunc   ;==>_CheckGPT

Func _CheckExtendedPartition($StartSector, $hImage)	;Extended partitions can only contain Logical Drives, but can be more than 4
	Local $nbytes,$read,$sector,$NextEntry=0,$StartingSector,$NumberOfSectors,$PartitionTable,$FilesystemDescriptor
	$tBuffer = DllStructCreate("byte[512]")
	While 1
		_WinAPI_SetFilePointerEx($hImage, ($StartSector + $NextEntry) * 512, $FILE_BEGIN)
		$read = _WinAPI_ReadFile($hImage, DllStructGetPtr($tBuffer), 512, $nBytes)
		If $read = 0 Then Return ""
		$sector = DllStructGetData($tBuffer, 1)
		$PartitionTable = StringMid($sector,3+892,64)
		$FilesystemDescriptor = StringMid($PartitionTable,9,2)
		$StartingSector = $StartSector+$NextEntry+Dec(_SwapEndian(StringMid($PartitionTable,17,8)),2)
		$NumberOfSectors = Dec(_SwapEndian(StringMid($PartitionTable,25,8)),2)
		If $FilesystemDescriptor = "07" Then $Entries &= _GenComboDescription($StartingSector,$NumberOfSectors)
		If StringMid($PartitionTable,33) = "00000000000000000000000000000000" Then ExitLoop ; No more entries
		$NextEntry = Dec(_SwapEndian(StringMid($PartitionTable,49,8)),2)
	WEnd
EndFunc   ;==>_CheckExtendedPartition

Func _TestNTFS($hImage, $PartitionStartSector)
	Local $nbytes, $TotalSectors
	If $PartitionStartSector <> 0 Then
		_WinAPI_SetFilePointerEx($hImage, $PartitionStartSector*512, $FILE_BEGIN)
	Else
		_WinAPI_CloseHandle($hImage)
		$hImage = _WinAPI_CreateFile($TargetImageFile,2,2,7)
	EndIf
	$tBuffer = DllStructCreate("byte[512]")
	$read = _WinAPI_ReadFile($hImage, DllStructGetPtr($tBuffer), 512, $nBytes)
	If $read = 0 Then Return ""
	$sector = DllStructGetData($tBuffer, 1)
	$TestSig = StringMid($sector,9,8)
	$TotalSectors = Dec(_SwapEndian(StringMid($sector,83,8)),2)
	If $TestSig = "4E544653" Then Return $TotalSectors		; Volume is NTFS
	_DisplayInfo("Could not find NTFS on that volume" & @CRLF)		; Volume is not NTFS
    Return 0
EndFunc   ;==>_TestNTFS   ;==>_TestNTFS

Func _GenComboDescription($StartSector,$SectorNumber)
	Return "Offset = " & $StartSector*512 & ": Volume size = " & Round(($SectorNumber*512)/1024/1024/1024,2) & " GB|"
EndFunc   ;==>_GenComboDescription

Func _GetMountedDrivesInfo()
	GUICtrlSetData($Combo,"","")
	Local $menu = '', $Drive = DriveGetDrive('All')
	If @error Then
		_DisplayInfo("Error - something went wrong in Func _GetPhysicalDriveInfo" & @CRLF)
		Return
	EndIf
	For $i = 1 to $Drive[0]
		$DriveType = DriveGetType($Drive[$i])
		$DriveCapacity = Round(DriveSpaceTotal($Drive[$i]),0)
		If DriveGetFileSystem($Drive[$i]) = 'NTFS' Then
			$menu &=  StringUpper($Drive[$i]) & "  (" & $DriveType & ")  - " & $DriveCapacity & " MB  - NTFS|"
		EndIf
	Next
	If $menu Then
;		_DisplayInfo("NTFS drives detected" & @CRLF)
		GUICtrlSetData($Combo, $menu, StringMid($menu, 1, StringInStr($menu, "|") -1))
		$IsImage = False
	Else
		_DisplayInfo("No NTFS drives detected" & @CRLF)
	EndIf
EndFunc

Func _GetPhysicalDrives($InputDevice)
	Local $PhysicalDriveString, $hFile0
	If StringLeft($InputDevice,10) = "GLOBALROOT" Then ; Shadow copies starts at 1 whereas physical drive starts at 0
		$i=1
	Else
		$i=0
	EndIf
	GUICtrlSetData($Combo,"","")
	$Entries = ''
	GUICtrlSetData($ComboPhysicalDrives,"","")
	$sDrivePath = '\\.\'&$InputDevice
;	ConsoleWrite("$sDrivePath: " & $sDrivePath & @CRLF)
	Do
		$hFile0 = _WinAPI_CreateFile($sDrivePath & $i,2,2,2)
		If $hFile0 <> 0 Then
			ConsoleWrite("Found: " & $sDrivePath & $i & @CRLF)
			_DisplayInfo("Found: " & $sDrivePath & $i & @CRLF)
			_WinAPI_CloseHandle($hFile0)
			$PhysicalDriveString &= $sDrivePath&$i&"|"
		EndIf
		$i+=1
	Until $hFile0=0
	GUICtrlSetData($ComboPhysicalDrives, $PhysicalDriveString, StringMid($PhysicalDriveString, 1, StringInStr($PhysicalDriveString, "|") -1))
EndFunc

Func _TestPhysicalDrive()
	$TargetImageFile = GUICtrlRead($ComboPhysicalDrives)
	If @error then Return
;	_DisplayInfo("Target is " & $TargetImageFile & @CRLF)
	GUICtrlSetData($Combo,"","")
	$Entries = ''
	_CheckMBR()
	GUICtrlSetData($Combo,$Entries,StringMid($Entries, 1, StringInStr($Entries, "|") -1))
	If $Entries = "" Then _DisplayInfo("Sorry, no NTFS volume found" & @CRLF)
	If StringInStr($TargetImageFile,"GLOBALROOT") Then
		$IsShadowCopy=True
		$IsPhysicalDrive=False
		$IsImage=False
	ElseIf StringInStr($TargetImageFile,"PhysicalDrive") Then
		$IsShadowCopy=False
		$IsPhysicalDrive=True
		$IsImage=False
	EndIf
EndFunc