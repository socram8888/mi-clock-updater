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
	Public manager As BleManager2
	Public currentState As Int
	Public rp As RuntimePermissions
	Public scanTimer As Timer
	
	' Device name whitelist
	Private validNames As List
	
	' List of devices that have been found
	Public foundDevices As List
	
	' List of pending devices
	Public currentDevice As Int
	
	' True if updating current device
	Public processingDevice As Boolean
	
	' True if no error has happened so far while updating
	Public updateOkay As Boolean
	
	Type FoundDevice(Name As String, Mac As String)
End Sub

' SERVICE CALLBACKS

Sub Service_Create
	manager.Initialize("manager")
	validNames.Initialize
	validNames.Add("LYWSD02")
End Sub

Sub Service_Start (startingIntent As Intent)
End Sub

Sub Service_Destroy
End Sub

' MANAGER CALLBACKS

Sub Manager_StateChanged(state As Int)
	If StillBusy Then
		CallSub(Main, "UpdateAborted")
		scanTimer.Enabled = False
	End If
End Sub

Sub Manager_DeviceFound(Name As String, Mac As String, AdvertisingData As Map, RSSI As Double)
	If validNames.IndexOf(Name) >= 0 Then
		For Each dev As FoundDevice In foundDevices
			If dev.Mac = Mac Then
				Return
			End If
		Next

		Dim newDev As FoundDevice
		newDev.Initialize
		newDev.Name = Name
		newDev.Mac = Mac
		foundDevices.Add(newDev)

		ConnectIfIdle
	End If
End Sub

Sub Manager_Disconnected
	If updateOkay Then
		CallSub(Main, "DeviceSucceeded")
	Else
		CallSub(Main, "DeviceFailed")
	End If
	
	processingDevice = False
	currentDevice = currentDevice + 1
	ConnectIfIdle
End Sub

Sub Manager_Connected (services As List)
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
			manager.WriteData("ebe0ccb0-7a0a-4b0c-8a1a-6ff2997da3a6", "ebe0ccb7-7a0a-4b0c-8a1a-6ff2997da3a6", tsbytes)
			Log("Write succeeded")
			updateOkay = True
		Catch
			Log("Update failed with an exception: " & LastException)
		End Try
	Else
		Log("Device did not have the time service")
	End If
	manager.Disconnect
End Sub

' TIMER CALLBACK

Sub ScanTimer_Tick
	manager.StopScan
	scanTimer.Enabled = False
	Log("Scan finished")
	
	If Not(StillBusy) Then
		CallSub(Main, "FinishedProcessing")
	End If
End Sub

' OWN METHODS

Sub StartUpdate
	foundDevices.Initialize
	foundDevices.Clear

	currentDevice = 0
	processingDevice = False

	scanTimer.Initialize("ScanTimer", 15000)
	scanTimer.Enabled = True
	manager.Scan2(Null, True)
End Sub

Sub ConnectIfIdle
	Do While currentDevice < foundDevices.Size And Not(processingDevice)
		Dim dev As FoundDevice = foundDevices.Get(currentDevice)
		Try
			updateOkay = False
			processingDevice = True

			manager.Connect2(dev.Mac, False)
			CallSub(Main, "DeviceFound")
		Catch
			Log("Failed to connect to " & dev.Name & ", " & dev.Mac)

			CallSub(Main, "DeviceFailed")
			currentDevice = currentDevice + 1
			processingDevice = False
		End Try
	Loop

	If Not(StillBusy) Then
		CallSub(Main, "FinishedProcessing")
	End If
End Sub

Sub StillBusy As Boolean
	Return processingDevice Or scanTimer.Enabled
End Sub
