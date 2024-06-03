#ifndef SERVERPIPES_BI
#define SERVERPIPES_BI

#include once "windows.bi"

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

Declare Sub ClosePipeHandles( _
	ByVal pipes As ProcessPipes Ptr _
)

Declare Function CreateChildProcessWithAsyncPipes( _
	ByVal pipes As ProcessPipes Ptr, _
	ByVal pApplicationName As TCHAR Ptr, _
	ByVal pLine As TCHAR Ptr _
)As HRESULT

#endif
