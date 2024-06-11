.PHONY: all debug release clean createdirs

all: release debug

FBC ?= fbc.exe
CC ?= gcc.exe
AS ?= as.exe
AR ?= ar.exe
GORC ?= GoRC.exe
LD ?= ld.exe
DLL_TOOL ?= dlltool.exe
LIB_DIR ?=
INC_DIR ?=
LD_SCRIPT ?=

TARGET_TRIPLET ?=
MARCH ?= native

USE_RUNTIME ?= TRUE
FBC_VER ?= _FBC1101
GCC_VER ?= _GCC0930
ifeq ($(USE_RUNTIME),TRUE)
RUNTIME = _RT
else
RUNTIME = _WRT
endif
OUTPUT_FILE_NAME=Async-Pipe$(FILE_SUFFIX).exe

PATH_SEP ?= /
MOVE_PATH_SEP ?= \\

MOVE_COMMAND ?= cmd.exe /c move /y
DELETE_COMMAND ?= cmd.exe /c del /f /q
MKDIR_COMMAND ?= cmd.exe /c mkdir
SCRIPT_COMMAND ?= cscript.exe //nologo fix-emitted-code.vbs

ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
BIN_DEBUG_DIR ?= bin$(PATH_SEP)Debug$(PATH_SEP)x64
BIN_RELEASE_DIR ?= bin$(PATH_SEP)Release$(PATH_SEP)x64
OBJ_DEBUG_DIR ?= obj$(PATH_SEP)Debug$(PATH_SEP)x64
OBJ_RELEASE_DIR ?= obj$(PATH_SEP)Release$(PATH_SEP)x64
BIN_DEBUG_DIR_MOVE ?= bin$(MOVE_PATH_SEP)Debug$(MOVE_PATH_SEP)x64
BIN_RELEASE_DIR_MOVE ?= bin$(MOVE_PATH_SEP)Release$(MOVE_PATH_SEP)x64
OBJ_DEBUG_DIR_MOVE ?= obj$(MOVE_PATH_SEP)Debug$(MOVE_PATH_SEP)x64
OBJ_RELEASE_DIR_MOVE ?= obj$(MOVE_PATH_SEP)Release$(MOVE_PATH_SEP)x64
else
BIN_DEBUG_DIR ?= bin$(PATH_SEP)Debug$(PATH_SEP)x86
BIN_RELEASE_DIR ?= bin$(PATH_SEP)Release$(PATH_SEP)x86
OBJ_DEBUG_DIR ?= obj$(PATH_SEP)Debug$(PATH_SEP)x86
OBJ_RELEASE_DIR ?= obj$(PATH_SEP)Release$(PATH_SEP)x86
BIN_DEBUG_DIR_MOVE ?= bin$(MOVE_PATH_SEP)Debug$(MOVE_PATH_SEP)x86
BIN_RELEASE_DIR_MOVE ?= bin$(MOVE_PATH_SEP)Release$(MOVE_PATH_SEP)x86
OBJ_DEBUG_DIR_MOVE ?= obj$(MOVE_PATH_SEP)Debug$(MOVE_PATH_SEP)x86
OBJ_RELEASE_DIR_MOVE ?= obj$(MOVE_PATH_SEP)Release$(MOVE_PATH_SEP)x86
endif

FBCFLAGS+=-gen gcc
ifeq ($(USE_UNICODE),TRUE)
FBCFLAGS+=-d UNICODE
FBCFLAGS+=-d _UNICODE
endif
FBCFLAGS+=-d WINVER=$(WINVER)
FBCFLAGS+=-d _WIN32_WINNT=$(_WIN32_WINNT)
FBCFLAGS+=-m WinMain
ifeq ($(USE_RUNTIME),TRUE)
else
FBCFLAGS+=-d WITHOUT_RUNTIME
endif
FBCFLAGS+=-w error -maxerr 1
FBCFLAGS+=-i src
ifneq ($(INC_DIR),)
FBCFLAGS+=-i "$(INC_DIR)"
endif
FBCFLAGS+=-r
FBCFLAGS+=-s gui
FBCFLAGS+=-O 0
FBCFLAGS_DEBUG+=-g
debug: FBCFLAGS+=$(FBCFLAGS_DEBUG)

ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
CFLAGS+=-m64
else
CFLAGS+=-m32
endif
CFLAGS+=-march=$(MARCH)
CFLAGS+=-pipe
CFLAGS+=-Wall -Werror -Wextra -pedantic
CFLAGS+=-Wno-unused-label -Wno-unused-function
CFLAGS+=-Wno-unused-parameter -Wno-unused-variable
CFLAGS+=-Wno-dollar-in-identifier-extension
CFLAGS+=-Wno-language-extension-token
CFLAGS+=-Wno-parentheses-equality
CFLAGS_DEBUG+=-g -O0
release: CFLAGS+=$(CFLAGS_RELEASE)
release: CFLAGS+=-fno-math-errno -fno-exceptions
release: CFLAGS+=-fno-unwind-tables -fno-asynchronous-unwind-tables
release: CFLAGS+=-O3 -fno-ident -fdata-sections -ffunction-sections
release: CFLAGS+=-flto
debug: CFLAGS+=$(CFLAGS_DEBUG)

ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
ASFLAGS+=--64
else
ASFLAGS+=--32
endif
ASFLAGS_DEBUG+=
release: ASFLAGS+=--strip-local-absolute
debug: ASFLAGS+=$(ASFLAGS_DEBUG)

ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
GORCFLAGS+=/machine X64
endif
GORCFLAGS+=/ni /o /d FROM_MAKEFILE
GORCFLAGS_DEBUG=/d DEBUG
debug: GORCFLAGS+=$(GORCFLAGS_DEBUG)

ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
ifeq ($(USE_RUNTIME),FALSE)
LDFLAGS+=-Wl,-e EntryPoint
endif
else
ifeq ($(USE_RUNTIME),FALSE)
LDFLAGS+=-Wl,-e _EntryPoint@0
endif
LDFLAGS+=-Wl,--large-address-aware
endif
LDFLAGS+=-Wl,--subsystem windows
LDFLAGS+=-Wl,--no-seh -Wl,--nxcompat
LDFLAGS+=-Wl,--disable-dynamicbase
LDFLAGS+=-pipe -nostdlib
LDFLAGS+=-L .
LDFLAGS+=-L "$(LIB_DIR)"
ifneq ($(LD_SCRIPT),)
LDFLAGS+=-T "$(LD_SCRIPT)"
endif
release: LDFLAGS+=-flto -s -Wl,--gc-sections
debug: LDFLAGS+=$(LDFLAGS_DEBUG)
debug: LDLIBS+=$(LDLIBS_DEBUG)

ifeq ($(USE_RUNTIME),TRUE)
LDLIBSBEGIN+="$(LIB_DIR)\crt2.o"
LDLIBSBEGIN+="$(LIB_DIR)\crtbegin.o"
LDLIBSBEGIN+="$(LIB_DIR)\fbrt0.o"
endif
LDLIBS+=-Wl,--start-group
LDLIBS+=-ladvapi32 -lcomctl32 -lcomdlg32 -lcrypt32
LDLIBS+=-lgdi32 -lgdiplus -lkernel32 -lmswsock
LDLIBS+=-lole32 -loleaut32 -lshell32 -lshlwapi
LDLIBS+=-lwsock32 -lws2_32 -luser32
LDLIBS+=-lmsvcrt
ifeq ($(USE_RUNTIME),TRUE)
LDLIBS+=-lfb
LDLIBS+=-luuid
endif
LDLIBS_DEBUG+=-lgcc -lmingw32 -lmingwex -lmoldname -lgcc_eh
ifeq ($(USE_RUNTIME),TRUE)
LDLIBS+=-lgcc -lmingw32 -lmingwex -lmoldname -lgcc_eh
endif
LDLIBS+=-Wl,--end-group
ifeq ($(USE_RUNTIME),TRUE)
LDLIBSEND+="$(LIB_DIR)\crtend.o"
endif

OBJECTFILES_DEBUG+=$(OBJ_DEBUG_DIR)$(PATH_SEP)mini-runtime$(FILE_SUFFIX).o
OBJECTFILES_RELEASE+=$(OBJ_RELEASE_DIR)$(PATH_SEP)mini-runtime$(FILE_SUFFIX).o

$(OBJ_DEBUG_DIR)$(PATH_SEP)mini-runtime$(FILE_SUFFIX).c: src$(PATH_SEP)mini-runtime.bi
$(OBJ_RELEASE_DIR)$(PATH_SEP)mini-runtime$(FILE_SUFFIX).c: src$(PATH_SEP)mini-runtime.bi

OBJECTFILES_DEBUG+=$(OBJ_DEBUG_DIR)$(PATH_SEP)Resources$(FILE_SUFFIX).obj
OBJECTFILES_RELEASE+=$(OBJ_RELEASE_DIR)$(PATH_SEP)Resources$(FILE_SUFFIX).obj

$(OBJ_DEBUG_DIR)$(PATH_SEP)Resources$(FILE_SUFFIX).obj: src$(PATH_SEP)manifest.xml src$(PATH_SEP)Resources.RC src$(PATH_SEP)Resources.RH
$(OBJ_RELEASE_DIR)$(PATH_SEP)Resources$(FILE_SUFFIX).obj: src$(PATH_SEP)manifest.xml src$(PATH_SEP)Resources.RC src$(PATH_SEP)Resources.RH

OBJECTFILES_DEBUG+=$(OBJ_DEBUG_DIR)$(PATH_SEP)ServerPipes$(FILE_SUFFIX).o
OBJECTFILES_RELEASE+=$(OBJ_RELEASE_DIR)$(PATH_SEP)ServerPipes$(FILE_SUFFIX).o

$(OBJ_DEBUG_DIR)$(PATH_SEP)ServerPipes$(FILE_SUFFIX).c: src$(PATH_SEP)ServerPipes.bi
$(OBJ_RELEASE_DIR)$(PATH_SEP)ServerPipes$(FILE_SUFFIX).c: src$(PATH_SEP)ServerPipes.bi

OBJECTFILES_DEBUG+=$(OBJ_DEBUG_DIR)$(PATH_SEP)WinMain$(FILE_SUFFIX).o
OBJECTFILES_RELEASE+=$(OBJ_RELEASE_DIR)$(PATH_SEP)WinMain$(FILE_SUFFIX).o

$(OBJ_DEBUG_DIR)$(PATH_SEP)WinMain$(FILE_SUFFIX).c: src$(PATH_SEP)WinMain.bi src$(PATH_SEP)Resources.RH src$(PATH_SEP)ServerPipes.bi
$(OBJ_RELEASE_DIR)$(PATH_SEP)WinMain$(FILE_SUFFIX).c: src$(PATH_SEP)WinMain.bi src$(PATH_SEP)Resources.RH src$(PATH_SEP)ServerPipes.bi


release: $(BIN_RELEASE_DIR)$(PATH_SEP)$(OUTPUT_FILE_NAME)

debug: $(BIN_DEBUG_DIR)$(PATH_SEP)$(OUTPUT_FILE_NAME)

clean:
	$(DELETE_COMMAND) $(OBJ_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).c
	$(DELETE_COMMAND) $(OBJ_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).c
	$(DELETE_COMMAND) $(OBJ_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).asm
	$(DELETE_COMMAND) $(OBJ_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).asm
	$(DELETE_COMMAND) $(OBJ_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).o
	$(DELETE_COMMAND) $(OBJ_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).o
	$(DELETE_COMMAND) $(OBJ_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).obj
	$(DELETE_COMMAND) $(OBJ_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)*$(FILE_SUFFIX).obj
	$(DELETE_COMMAND) $(BIN_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)$(OUTPUT_FILE_NAME)
	$(DELETE_COMMAND) $(BIN_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)$(OUTPUT_FILE_NAME)

createdirs:
	$(MKDIR_COMMAND) $(BIN_DEBUG_DIR_MOVE)
	$(MKDIR_COMMAND) $(BIN_RELEASE_DIR_MOVE)
	$(MKDIR_COMMAND) $(OBJ_DEBUG_DIR_MOVE)
	$(MKDIR_COMMAND) $(OBJ_RELEASE_DIR_MOVE)

$(BIN_RELEASE_DIR)$(PATH_SEP)$(OUTPUT_FILE_NAME): $(OBJECTFILES_RELEASE)
	$(CC) $(LDFLAGS) $(LDLIBSBEGIN) $^ $(LDLIBS) $(LDLIBSEND) -o $@

$(BIN_DEBUG_DIR)$(PATH_SEP)$(OUTPUT_FILE_NAME): $(OBJECTFILES_DEBUG)
	$(CC) $(LDFLAGS) $(LDLIBSBEGIN) $^ $(LDLIBS) $(LDLIBSEND) -o $@

$(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).o: $(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).asm
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).o: $(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).asm
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).asm: $(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).c
	$(CC) $(EXTRA_CFLAGS) $(CFLAGS) -o $@ $<

$(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).asm: $(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).c
	$(CC) $(EXTRA_CFLAGS) $(CFLAGS) -o $@ $<

$(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).c: src$(PATH_SEP)%.bas
	$(FBC) $(FBCFLAGS) $<
	$(MOVE_COMMAND) src$(MOVE_PATH_SEP)$*.c $(OBJ_RELEASE_DIR_MOVE)$(MOVE_PATH_SEP)$*$(FILE_SUFFIX).c

$(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).c: src$(PATH_SEP)%.bas
	$(FBC) $(FBCFLAGS) $<
	$(MOVE_COMMAND) src$(MOVE_PATH_SEP)$*.c $(OBJ_DEBUG_DIR_MOVE)$(MOVE_PATH_SEP)$*$(FILE_SUFFIX).c

$(OBJ_RELEASE_DIR)$(PATH_SEP)%$(FILE_SUFFIX).obj: src$(PATH_SEP)%.RC
	$(GORC) $(GORCFLAGS) /fo $@ $<

$(OBJ_DEBUG_DIR)$(PATH_SEP)%$(FILE_SUFFIX).obj: src$(PATH_SEP)%.RC
	$(GORC) $(GORCFLAGS) /fo $@ $<

