#include once "ServerPipes.bi"

Const PIPE_NAME_R = __TEXT("\\.\pipe\Async-ReaderR")
Const PIPE_NAME_W = __TEXT("\\.\pipe\Async-ReaderW")

Public Sub ClosePipeHandles( _
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

Public Function CreateChildProcessWithAsyncPipes( _
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
