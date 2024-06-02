#include once "WinMain.bi"
#include once "win\commctrl.bi"
#include once "win\windowsx.bi"
#include once "Resources.RH"

Const PIPE_NAME_R = __TEXT("\\.\pipe\Async-ReaderR")
Const PIPE_NAME_W = __TEXT("\\.\pipe\Async-ReaderW")
' Const PROCESS_NAME = __TEXT("C:\Program Files (x86)\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe")
' Const PROCESS_COMMAND_LINE = __TEXT("""C:\Program Files (x86)\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe"" ""-showincludes"" ""D:\QuickTestBasicProgram\file.bas""")
Const PROCESS_NAME = __TEXT("C:\Program Files\mingw64\bin\gdb.exe")
Const PROCESS_COMMAND_LINE = __TEXT("""C:\Program Files\mingw64\bin\gdb.exe"" ""-f"" ""D:\QuickTestBasicProgram\file.exe""")

Const READ_BUFFER_CAPACITY = 512
Const WRITE_BUFFER_CAPACITY = 512

Type ProcessPipes
	hServerReadPipe As HANDLE
	hServerWritePipe As HANDLE
	hClientReadPipe As HANDLE
	hClientWritePipe As HANDLE
	hClientErrorPipe As HANDLE
	hClientReadFile As HANDLE
	hClientWriteFile As HANDLE
	hClientErrorFile As HANDLE
	lpCommandLine As TCHAR Ptr
End Type

Type InputDialogParam
	hInst As HINSTANCE
	hWin As HWND
	OverlapRead As OVERLAPPED
	OverlapWrite As OVERLAPPED
	Pipes As ProcessPipes
	ReadBuffer(READ_BUFFER_CAPACITY - 1) As UByte
	WriteBuffer(WRITE_BUFFER_CAPACITY - 1) As UByte
End Type

Declare Sub ReadCompletionRoutine( _
	ByVal dwErrorCode As DWORD, _
	ByVal dwNumberOfBytesTransfered As DWORD, _
	ByVal lpOverlapped As OVERLAPPED Ptr _
)

Declare Sub WriteCompletionRoutine( _
	ByVal dwErrorCode As DWORD, _
	ByVal dwNumberOfBytesTransfered As DWORD, _
	ByVal lpOverlapped As OVERLAPPED Ptr _
)

Private Sub ClosePipeHandles( _
		ByVal pipes As ProcessPipes Ptr _
	)

	CloseHandle(pipes->hServerReadPipe)
	CloseHandle(pipes->hServerWritePipe)

	CloseHandle(pipes->hClientReadPipe)
	CloseHandle(pipes->hClientWritePipe)
	CloseHandle(pipes->hClientErrorPipe)

	CloseHandle(pipes->hClientReadFile)
	CloseHandle(pipes->hClientWriteFile)
	CloseHandle(pipes->hClientErrorFile)

	Deallocate(pipes->lpCommandLine)

End Sub

Private Sub AppendLengthTextW( _
		ByVal hwndControl As HWND, _
		ByVal lpwszText As LPWSTR, _
		ByVal Length As Integer _
	)

	Dim OldTextLength As Long = GetWindowTextLengthW(hwndControl)

	SendMessageW(hwndControl, EM_SETSEL, OldTextLength, Cast(LPARAM, OldTextLength))
	SendMessageW(hwndControl, EM_REPLACESEL, FALSE, Cast(LPARAM, lpwszText))
	Edit_ScrollCaret(hwndControl)

End Sub

Private Sub ChildProcess_OnRead( _
		ByVal this As InputDialogParam Ptr, _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD _
	)

	If dwErrorCode Then
		' error
		ClosePipeHandles(@this->Pipes)
		Exit Sub
	End If

	If dwNumberOfBytesTransfered = 0 Then
		' end of the stream
		ClosePipeHandles(@this->Pipes)
		Exit Sub
	End If

	Scope
		Const NewLine = !"\r\n"

		Dim buf As WString * (READ_BUFFER_CAPACITY + Len(NewLine) + 1) = Any
		Dim Length As Long = MultiByteToWideChar( _
			CP_ACP, _
			0, _
			@this->ReadBuffer(0), _
			dwNumberOfBytesTransfered, _
			@buf, _
			READ_BUFFER_CAPACITY _
		)

		lstrcpyW(@buf[Length], @WStr(NewLine))

		Dim hwndControl As HWND = GetDlgItem(this->hWin, IDC_EDT_OUTPUT)
		AppendLengthTextW(hwndControl, @buf, Length + Len(NewLine))
	End Scope

	ZeroMemory(@this->OverlapRead, SizeOf(OVERLAPPED))
	Dim resRead As BOOL = ReadFileEx( _
		this->Pipes.hServerReadPipe, _
		@this->ReadBuffer(0), _
		READ_BUFFER_CAPACITY, _
		@this->OverlapRead, _
		@ReadCompletionRoutine _
	)
	If resRead = 0 Then
		' error
		ClosePipeHandles(@this->Pipes)
	End If

End Sub

Private Sub ChildProcess_OnWrite( _
		ByVal this As InputDialogParam Ptr, _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD _
	)

	If dwErrorCode Then
		' error
		ClosePipeHandles(@this->Pipes)
		Exit Sub
	End If

	If dwNumberOfBytesTransfered = 0 Then
		' end of the stream
		ClosePipeHandles(@this->Pipes)
		Exit Sub
	End If

End Sub

Private Sub ReadCompletionRoutine( _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD, _
		ByVal lpOverlapped As OVERLAPPED Ptr _
	)

	Dim this As InputDialogParam Ptr = CONTAINING_RECORD(lpOverlapped, InputDialogParam, OverlapRead)
	ChildProcess_OnRead(this, dwErrorCode, dwNumberOfBytesTransfered)

End Sub

Private Sub WriteCompletionRoutine( _
		ByVal dwErrorCode As DWORD, _
		ByVal dwNumberOfBytesTransfered As DWORD, _
		ByVal lpOverlapped As OVERLAPPED Ptr _
	)

	Dim this As InputDialogParam Ptr = CONTAINING_RECORD(lpOverlapped, InputDialogParam, OverlapWrite)
	ChildProcess_OnWrite(this, dwErrorCode, dwNumberOfBytesTransfered)

End Sub

Private Function CreateChildProcessWithAsyncPipes( _
		ByVal pipes As ProcessPipes Ptr, _
		ByVal pApplicationName As TCHAR Ptr, _
		ByVal pLine As TCHAR Ptr _
	)As HRESULT

	Scope
		' Server-side handles need to be noninheritable

		pipes->hServerReadPipe = CreateNamedPipe( _
			@PIPE_NAME_R, _
			PIPE_ACCESS_DUPLEX Or FILE_FLAG_OVERLAPPED, _
			PIPE_TYPE_BYTE Or PIPE_READMODE_BYTE, _
			PIPE_UNLIMITED_INSTANCES, _
			0, 0, 0, _
			NULL _
		)
		If pipes->hServerReadPipe = INVALID_HANDLE_VALUE Then
			' error
			Return E_FAIL
		End If

		pipes->hServerWritePipe = CreateNamedPipe( _
			@PIPE_NAME_W, _
			PIPE_ACCESS_DUPLEX Or FILE_FLAG_OVERLAPPED, _
			PIPE_TYPE_BYTE Or PIPE_READMODE_BYTE, _
			PIPE_UNLIMITED_INSTANCES, _
			0, 0, 0, _
			NULL _
		)
		If pipes->hServerWritePipe = INVALID_HANDLE_VALUE Then
			' error
			Return E_FAIL
		End If
	End Scope

	Scope
		' Client-side handles need to be inheritable

		Dim saAttr As SECURITY_ATTRIBUTES = Any
		With saAttr
			.nLength = SizeOf(SECURITY_ATTRIBUTES)
			.lpSecurityDescriptor = NULL
			.bInheritHandle = TRUE
		End With

		pipes->hClientReadPipe = CreateFile( _
			@PIPE_NAME_W, _
			GENERIC_READ, _
			0, _
			@saAttr, _
			OPEN_EXISTING, _
			0, _
			NULL _
		)

		pipes->hClientWritePipe = CreateFile( _
			@PIPE_NAME_R, _
			GENERIC_WRITE, _
			0, _
			@saAttr, _
			OPEN_EXISTING, _
			0, _
			NULL _
		)

		pipes->hClientErrorPipe = CreateFile( _
			@PIPE_NAME_R, _
			GENERIC_WRITE, _
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
			pipes->hClientReadPipe, _
			hCurrentProcess, _
			@pipes->hClientReadFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplRead = 0 Then
			' error
			Return E_FAIL
		End If

		Dim resDuplWrite As BOOL = DuplicateHandle( _
			hCurrentProcess, _
			pipes->hClientWritePipe, _
			hCurrentProcess, _
			@pipes->hClientWriteFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplWrite = 0 Then
			' error
			Return E_FAIL
		End If

		Dim resDuplError As BOOL = DuplicateHandle( _
			hCurrentProcess, _
			pipes->hClientErrorPipe, _
			hCurrentProcess, _
			@pipes->hClientErrorFile, _
			0, _
			TRUE, _
			DUPLICATE_SAME_ACCESS _
		)
		If resDuplError = 0 Then
			' error
			Return E_FAIL
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
			.dwFlags = STARTF_USESTDHANDLES Or STARTF_USESHOWWINDOW
			.wShowWindow = SW_HIDE
			.hStdInput = pipes->hClientReadFile
			.hStdOutput = pipes->hClientWriteFile
			.hStdError = pipes->hClientWriteFile
		End With

		Dim piProcInfo As PROCESS_INFORMATION = Any

		Dim LineLength As Long = lstrlen(pLine)
		pipes->lpCommandLine = Allocate((LineLength + 1) * SizeOf(TCHAR))
		If pipes->lpCommandLine = NULL Then
			' Out of memory
			Return E_FAIL
		End If

		lstrcpy(pipes->lpCommandLine, pLine)

		Dim resCreateProcess As BOOL = CreateProcess( _
			pApplicationName, _
			pipes->lpCommandLine, _
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
			Return E_FAIL
		End If

		CloseHandle(piProcInfo.hProcess)
		CloseHandle(piProcInfo.hThread)

	End Scope

	Return S_OK

End Function

Private Sub IDOK_OnClick( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

	' Start reading child process
	ZeroMemory(@this->OverlapRead, SizeOf(OVERLAPPED))
	Dim resRead As BOOL = ReadFileEx( _
		this->Pipes.hServerReadPipe, _
		@this->ReadBuffer(0), _
		READ_BUFFER_CAPACITY, _
		@this->OverlapRead, _
		@ReadCompletionRoutine _
	)
	If resRead = 0 Then
		' error
		Exit Sub
	End If

End Sub

Private Sub IDC_BTN_INPUT_OnClick( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

	Const NewLine = !"\r\n"

	Dim bufLength As Long = GetDlgItemTextA( _
		hWin, _
		IDC_EDT_INPUT, _
		@this->WriteBuffer(0), _
		WRITE_BUFFER_CAPACITY - Len(NewLine) - 1 _
	)

	lstrcpyA(@this->WriteBuffer(bufLength), @Str(NewLine))

	' Start writing to child process
	ZeroMemory(@this->OverlapWrite, SizeOf(OVERLAPPED))
	Dim resWrite As BOOL = WriteFileEx( _
		this->Pipes.hServerWritePipe, _
		@this->WriteBuffer(0), _
		bufLength + Len(NewLine), _
		@this->OverlapWrite, _
		@WriteCompletionRoutine _
	)
	If resWrite = 0 Then
		' error
		Exit Sub
	End If

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

	Dim hrCreateProcess As HRESULT = CreateChildProcessWithAsyncPipes( _
		@this->Pipes, _
		@PROCESS_NAME, _
		@PROCESS_COMMAND_LINE _
	)
	If FAILED(hrCreateProcess) Then
		Exit Sub
	End If

End Sub

Private Sub DialogMain_OnUnload( _
		ByVal this As InputDialogParam Ptr, _
		ByVal hWin As HWND _
	)

	ClosePipeHandles(@this->Pipes)

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

				Case IDC_BTN_INPUT
					IDC_BTN_INPUT_OnClick(pContext, hWin)

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
