#include once "WinMain.bi"
#include once "win\commctrl.bi"
#include once "Resources.RH"

Const PIPE_NAME_R = __TEXT("\\.\pipe\Async-ReaderR")
Const PIPE_NAME_W = __TEXT("\\.\pipe\Async-ReaderW")
Const PROCESS_NAME = __TEXT("C:\Program Files (x86)\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe")
Const PROCESS_COMMAND_LINE = __TEXT("""C:\Program Files (x86)\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe"" ""-showincludes"" ""D:\QuickTestBasicProgram\file.bas""")

Const READ_BUFFER_CAPACITY = 512

Type InputDialogParam
	hInst As HINSTANCE
	hWin As HWND
	OverlapRead As OVERLAPPED
	OverlapWrite As OVERLAPPED
	hReadPipe As HANDLE
	hWritePipe As HANDLE

	hClientWritePipe As HANDLE
	hClientReadPipe As HANDLE

	hClientWriteFile As HANDLE
	hClientErrorFile As HANDLE
	hClientReadFile As HANDLE

	ReadBuffer(READ_BUFFER_CAPACITY - 1) As UByte
	WriteBuffer(READ_BUFFER_CAPACITY - 1) As UByte
End Type

Private Sub ReadCompletionRoutine( _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD, _
		ByVal lpOverlapped As OVERLAPPED Ptr _
	)

	If dwErrorCode Then
		' error
		Exit Sub
	End If

	If dwNumberOfBytesTransfered = 0 Then
		' end of the stream
		Exit Sub
	End If

	Dim this As InputDialogParam Ptr = CONTAINING_RECORD(lpOverlapped, InputDialogParam, OverlapRead)

	ZeroMemory(@this->OverlapRead, SizeOf(OVERLAPPED))
	Dim resRead As BOOL = ReadFileEx( _
		this->hReadPipe, _
		@this->ReadBuffer(0), _
		READ_BUFFER_CAPACITY, _
		@this->OverlapRead, _
		@ReadCompletionRoutine _
	)
	If resRead = 0 Then
		' error
	End If

End Sub

Private Sub WriteCompletionRoutine( _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD, _
		ByVal lpOverlapped As OVERLAPPED Ptr _
	)

End Sub

Private Sub IDOK_OnClick( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

	Scope
		this->hReadPipe = CreateNamedPipe( _
			@PIPE_NAME_R, _
			PIPE_ACCESS_DUPLEX Or FILE_FLAG_OVERLAPPED, _
			PIPE_TYPE_BYTE Or PIPE_READMODE_BYTE, _
			PIPE_UNLIMITED_INSTANCES, _
			0, 0, 0, _
			NULL _
		)
		If this->hReadPipe = INVALID_HANDLE_VALUE Then
			' error
			Exit Sub
		End If

		this->hWritePipe = CreateNamedPipe( _
			@PIPE_NAME_W, _
			PIPE_ACCESS_DUPLEX Or FILE_FLAG_OVERLAPPED, _
			PIPE_TYPE_BYTE Or PIPE_READMODE_BYTE, _
			PIPE_UNLIMITED_INSTANCES, _
			0, 0, 0, _
			NULL _
		)
		If this->hWritePipe = INVALID_HANDLE_VALUE Then
			' error
			Exit Sub
		End If
	End Scope

	Scope
		' you need this for the client to inherit the handles
		Dim saAttr As SECURITY_ATTRIBUTES = Any
		With saAttr
			.nLength = SizeOf(SECURITY_ATTRIBUTES)
			.lpSecurityDescriptor = NULL
			.bInheritHandle = TRUE
		End With

		this->hClientWritePipe = CreateFile( _
			@PIPE_NAME_R, _
			GENERIC_WRITE, _
			0, _
			@saAttr, _
			OPEN_EXISTING, _
			0, _
			NULL _
		)

		this->hClientReadPipe = CreateFile( _
			@PIPE_NAME_W, _
			GENERIC_READ, _
			0, _
			@saAttr, _
			OPEN_EXISTING, _
			0, _
			NULL _
		)
	End Scope

	Scope
		Dim hCurrentProcess As HANDLE = GetCurrentProcess()

		Dim resDuplRead As BOOL = DuplicateHandle( _
			hCurrentProcess, _
			this->hClientReadPipe, _
			hCurrentProcess, _
			@this->hClientReadFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplRead = 0 Then
			' error
		End If

		Dim resDuplWrite As BOOL = DuplicateHandle( _
			hCurrentProcess, _
			this->hClientWritePipe, _
			hCurrentProcess, _
			@this->hClientWriteFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplWrite = 0 Then
			' error
		End If

		Dim resDuplError As BOOL = DuplicateHandle( _
			hCurrentProcess, _
			this->hClientWritePipe, _
			hCurrentProcess, _
			@this->hClientErrorFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplError = 0 Then
			' error
		End If
	End Scope

	Scope
		' you need this for the client to inherit the handles
		Dim saAttr As SECURITY_ATTRIBUTES = Any
		With saAttr
			.nLength = SizeOf(SECURITY_ATTRIBUTES)
			.lpSecurityDescriptor = NULL
			.bInheritHandle = TRUE
		End With

		Dim siStartInfo As STARTUPINFO = Any
		ZeroMemory(@siStartInfo, SizeOf(STARTUPINFO))
		With siStartInfo
			.cb = SizeOf(STARTUPINFO)
			.hStdInput = this->hClientReadFile
			.hStdOutput = this->hClientWriteFile
			.hStdError = this->hClientWriteFile
			.dwFlags = STARTF_USESTDHANDLES
		End With

		Dim piProcInfo As PROCESS_INFORMATION = Any

		Dim lpCommandLine As TCHAR Ptr = Allocate((Len(PROCESS_COMMAND_LINE) + 1) * SizeOf(TCHAR))
		lstrcpy(lpCommandLine, @PROCESS_COMMAND_LINE)

		Dim resCreateProcess As BOOL = CreateProcess( _
			@PROCESS_NAME, _
			lpCommandLine, _
			NULL, _
			NULL, _
			True, _
			CREATE_UNICODE_ENVIRONMENT, _
			NULL, _
			NULL, _
			@siStartInfo, _
			@piProcInfo _
		)

		If resCreateProcess = 0 Then
			' error
		End If

		ZeroMemory(@this->OverlapRead, SizeOf(OVERLAPPED))
		Dim resRead As BOOL = ReadFileEx( _
			this->hReadPipe, _
			@this->ReadBuffer(0), _
			READ_BUFFER_CAPACITY, _
			@this->OverlapRead, _
			@ReadCompletionRoutine _
		)
		If resRead = 0 Then
			' error
		End If

	End Scope

End Sub

Private Sub IDCANCEL_OnClick( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

	PostQuitMessage(0)

End Sub

Private Sub DialogMain_OnLoad( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

End Sub

Private Sub DialogMain_OnUnload( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

End Sub

Private Function InputDataDialogProc( _
		ByVal hWin As HWND, _
		ByVal uMsg As UINT, _
		ByVal wParam As WPARAM, _
		ByVal lParam As LPARAM _
	)As INT_PTR

	Dim pContext As InputDialogParam Ptr = Any

	If uMsg = WM_INITDIALOG Then
		pContext = Cast(InputDialogParam Ptr, lParam)
		pContext->hWin = hWin
		SetWindowLongPtr(hWin, GWLP_USERDATA, Cast(LONG_PTR, pContext))
		DialogMain_OnLoad(pContext, hWin)
		Return TRUE
	End If

	pContext = Cast(Any Ptr, GetWindowLongPtr(hWin, GWLP_USERDATA))

	Select Case uMsg

		Case WM_COMMAND
			Select Case LOWORD(wParam)

				Case IDOK
					IDOK_OnClick(pContext, hWin)

				Case IDCANCEL
					IDCANCEL_OnClick(pContext, hWin)

			End Select

		Case WM_CLOSE
			DialogMain_OnUnload(pContext, hWin)
			PostQuitMessage(0)

		Case Else
			Return FALSE

	End Select

	Return TRUE

End Function

Private Function EnableVisualStyles()As HRESULT

	Dim icc As INITCOMMONCONTROLSEX = Any
	icc.dwSize = SizeOf(INITCOMMONCONTROLSEX)
	icc.dwICC = ICC_ANIMATE_CLASS Or _
		ICC_BAR_CLASSES Or _
		ICC_COOL_CLASSES Or _
		ICC_DATE_CLASSES Or _
		ICC_HOTKEY_CLASS Or _
		ICC_INTERNET_CLASSES Or _
		ICC_LINK_CLASS Or _
		ICC_LISTVIEW_CLASSES Or _
		ICC_NATIVEFNTCTL_CLASS Or _
		ICC_PAGESCROLLER_CLASS Or _
		ICC_PROGRESS_CLASS Or _
		ICC_STANDARD_CLASSES Or _
		ICC_TAB_CLASSES Or _
		ICC_TREEVIEW_CLASSES Or _
		ICC_UPDOWN_CLASS Or _
		ICC_USEREX_CLASSES Or _
	ICC_WIN95_CLASSES

	Dim res As BOOL = InitCommonControlsEx(@icc)
	If res = 0 Then
		Dim dwError As DWORD = GetLastError()
		Return HRESULT_FROM_WIN32(dwError)
	End If

	Return S_OK

End Function

Private Function CreateMainWindow( _
		Byval hInst As HINSTANCE, _
		ByVal param As InputDialogParam Ptr _
	)As HWND

	Dim hWin As HWND = CreateDialogParam( _
		hInst, _
		MAKEINTRESOURCE(IDD_DLG_TASKS), _
		NULL, _
		@InputDataDialogProc, _
		Cast(LPARAM, param) _
	)

	Return hWin

End Function

Private Function MessageLoop( _
		ByVal hWin As HWND _
	)As Integer

	Do
		Const EventVectorLength = 0
		Dim dwWaitResult As DWORD = MsgWaitForMultipleObjectsEx( _
			EventVectorLength, _
			NULL, _
			INFINITE, _
			QS_ALLEVENTS Or QS_ALLINPUT Or QS_ALLPOSTMESSAGE, _
			MWMO_INPUTAVAILABLE Or MWMO_ALERTABLE _
		)

		Select Case dwWaitResult

			Case WAIT_OBJECT_0, WAIT_OBJECT_0 + 1
				' Messages have been added to the message queue
				' they need to be processed

			Case WAIT_IO_COMPLETION
				' The asynchronous procedure has ended
				' we continue to wait

			Case Else ' WAIT_ABANDONED, WAIT_TIMEOUT, WAIT_FAILED
				Return 1

		End Select

		Do
			Dim wMsg As MSG = Any
			Dim resGetMessage As BOOL = PeekMessage( _
				@wMsg, _
				NULL, _
				0, _
				0, _
				PM_REMOVE _
			)
			If resGetMessage =  0 Then
				Exit Do
			End If

			If wMsg.message = WM_QUIT Then
				Return wMsg.wParam
			Else
				Dim resDialogMessage As BOOL = IsDialogMessage( _
					hWin, _
					@wMsg _
				)
				If resDialogMessage = 0 Then
					TranslateMessage(@wMsg)
					DispatchMessage(@wMsg)
				End If
			End If
		Loop
	Loop

	Return 0

End Function

Private Function tWinMain( _
		Byval hInst As HINSTANCE, _
		ByVal hPrevInstance As HINSTANCE, _
		ByVal lpCmdLine As LPTSTR, _
		ByVal iCmdShow As Long _
	)As Integer

	Scope
		Dim hrVisualStyles As Integer = EnableVisualStyles()
		If FAILED(hrVisualStyles) Then
			Return 1
		End If
	End Scope

	Dim param As InputDialogParam = Any
	param.hInst = hInst

	Scope
		Dim hWin As HWND = CreateMainWindow( _
			hInst, _
			@param _
		)
		If hWin = NULL Then
			Return 1
		End If

		Dim resMessageLoop As Integer = MessageLoop(hWin)

		DestroyWindow(hWin)

		Return resMessageLoop
	End Scope

End Function

#ifndef WITHOUT_RUNTIME
Private Function EntryPoint()As Integer
#else
Public Function EntryPoint Alias "EntryPoint"()As Integer
#endif

	Dim hInst As HMODULE = GetModuleHandle(NULL)

	' The program does not process command line parameters
	Dim Arguments As LPTSTR = NULL
	Dim RetCode As Integer = tWinMain( _
		hInst, _
		NULL, _
		Arguments, _
		SW_SHOW _
	)

	#ifdef WITHOUT_RUNTIME
		ExitProcess(RetCode)
	#endif

	Return RetCode

End Function

#ifndef WITHOUT_RUNTIME
Dim RetCode As Long = CLng(EntryPoint())
End(RetCode)
#endif
