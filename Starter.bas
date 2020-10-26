B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=10.2
@EndOfDesignText@
#Region  Service Attributes 
	#StartAtBoot: False
	#ExcludeFromLibrary: True
#End Region

Sub Process_Globals
	Public Manager As BleManager2
	Public CurrentState As Int
	Public Rp As RuntimePermissions
	
	' Device name whitelist
	Private ValidNames As List
	
	' List of devices that have been found
	Public FoundDevices As List
	
	' Currently updating device
	Public CurrentDevice As FoundDevice
	
	' Position of currently updating device
	Public CurrentDevicePos As Int
	
	' True if still running an update operation
	Public UpdateRunning As Boolean

	' True if batch update
	Public BatchUpdate As Boolean
	
	Type FoundDevice(Name As String, Mac As String, Status As Int)

	' Found devices status
	Public DEV_PENDING As Int = 0
	Public DEV_UPDATING As Int = 1
	Public DEV_OK As Int = 2
	Public DEV_ERROR As Int = 3
End Sub

' SERVICE CALLBACKS

Sub Service_Create
	Manager.Initialize("manager")
	ValidNames.Initialize
	ValidNames.Add("LYWSD02")
	FoundDevices.Initialize
End Sub

Sub Service_Start (startingIntent As Intent)
End Sub

Sub Service_Destroy
End Sub

' MANAGER CALLBACKS

Sub Manager_StateChanged(state As Int)
	CurrentState = state
	CallSub(Main, "BleStateChanged")
	FoundDevices.Clear
End Sub

Sub Manager_DeviceFound(Name As String, Mac As String, AdvertisingData As Map, RSSI As Double)
	If ValidNames.IndexOf(Name) >= 0 Then
		For Each dev As FoundDevice In FoundDevices
			If dev.Mac = Mac Then
				Return
			End If
		Next

		Dim newDev As FoundDevice
		newDev.Initialize
		newDev.Name = Name
		newDev.Mac = Mac
		newDev.Status = DEV_PENDING
		FoundDevices.Add(newDev)
		
		CallSub(Main, "NewDeviceFound")
	End If
End Sub

Sub Manager_Connected(services As List)
	Log("Connected")
	If services.IndexOf("ebe0ccb0-7a0a-4b0c-8a1a-6ff2997da3a6") >= 0 Then
		Dim timestamp As Long = Round(DateTime.Now / 1000 + DateTime.TimeZoneOffset * 3600)
		Log("Current local timestamp: " & timestamp & " (off: " & DateTime.TimeZoneOffset & ")")

		Dim tsbytes(5) As Byte
		tsbytes(0) = Bit.And(timestamp, 0xFF)
		tsbytes(1) = Bit.And(Bit.ShiftRight(timestamp, 8), 0xFF)
		tsbytes(2) = Bit.And(Bit.ShiftRight(timestamp, 16), 0xFF)
		tsbytes(3) = Bit.And(Bit.ShiftRight(timestamp, 24), 0xFF)
		tsbytes(4) = 0
		
		Try
			Log("Try write")
			Manager.WriteData("ebe0ccb0-7a0a-4b0c-8a1a-6ff2997da3a6", "ebe0ccb7-7a0a-4b0c-8a1a-6ff2997da3a6", tsbytes)
			Log("Write succeeded")
			CurrentDevice.Status = DEV_OK
		Catch
			Log("Update failed with an exception: " & LastException)
			CurrentDevice.Status = DEV_ERROR
		End Try
	Else
		Log("Device did not have the time service")
		CurrentDevice.Status = DEV_ERROR
	End If
	Manager.Disconnect
End Sub

Sub Manager_Disconnected
	If BatchUpdate Then
		CurrentDevicePos = CurrentDevicePos + 1
		StartUpdateCurrent
	Else
		StopUpdate
	End If
End Sub

' OWN METHODS

Sub ToggleScan(enable As Boolean)
	If enable Then
		Manager.Scan2(Null, True)
	Else
		Manager.StopScan()
		FoundDevices.Clear
	End If
End Sub

Sub UpdateDevice(pos As Int)
	BatchUpdate = False
	CurrentDevicePos = pos
	StartUpdateCurrent
End Sub

Sub UpdateAllDevices
	BatchUpdate = True
	CurrentDevicePos = 0
	StartUpdateCurrent
End Sub

Sub StartUpdateCurrent
	If CurrentDevicePos < FoundDevices.Size Then
		UpdateRunning = True
		CurrentDevice = FoundDevices.Get(CurrentDevicePos)
		Manager.Connect2(CurrentDevice.Mac, False)
	Else
		StopUpdate
	End If
End Sub

Sub StopUpdate
	UpdateRunning = False
	CurrentDevice = Null
	CallSub(Main, "UpdateFinished")
End Sub
