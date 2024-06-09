#include once "mini-runtime.bi"
#include once "windows.bi"

#ifdef WITHOUT_RUNTIME

#undef fb_End

Declare Function main Alias "main"(ByVal argc As Long, ByVal argv As ZString Ptr) As Long

Public Sub fb_End Alias "fb_End"(ByVal RetCode As Long)
	ExitProcess(RetCode)
End Sub

Public Function EntryPoint Alias "EntryPoint"()As Integer

	Dim RetCode As Long = main(0, 0)

	fb_End(RetCode)

	Return RetCode

End Function

#endif
