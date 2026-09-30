# DarkPlaces - MinGW-w64 cross build (Linux host -> Windows x86_64), release only.
#
#   make -j8 release SDL_CONFIG=/mingw64/x86_64-w64-mingw32/bin/sdl2-config
#
# Targets:  release (default) | sv-release | sdl-release | clean | help
# Executables are written to the repository root, objects to build-obj/.
# Everything here can be overridden on the make command line (CC=..., ARCH=..., etc).
# Output is quiet (one line per file, plus compiler warnings/errors); use V=1 to see full commands.

TRIPLE  := x86_64-w64-mingw32
CC      := $(TRIPLE)-clang
WINDRES := $(TRIPLE)-windres

EXE_SV  := xonotic-dedicated.exe
EXE_SDL := xonotic-sdl.exe
EXE_ALL := $(EXE_SV) $(EXE_SDL)

OUT := build-obj

# V=1 shows the full command lines; otherwise just "  CC  file.c"
V ?= 0
ifeq ($(V),1)
	Q :=
	say = @:
else
	Q := @
	say = @echo '  $(1)'
endif


##### Optional features #####

DP_VIDEO_CAPTURE ?= enabled
ifeq ($(DP_VIDEO_CAPTURE),enabled)
	CFLAGS_CAPTURE := -DCONFIG_VIDEO_CAPTURE
	OBJ_CAPTURE    := cap_avi.o cap_ogg.o
endif

ifdef DP_FS_BASEDIR
	CFLAGS_FS := -DDP_FS_BASEDIR=\"$(DP_FS_BASEDIR)\"
endif


##### Library linking: shared | static | dlopen #####

# SDL2
SDL_CONFIG ?= sdl2-config
DP_LINK_SDL ?= shared
ifneq ($(MAKECMDGOALS),clean)
# -isystem so warnings from SDL's own headers are not reported
SDL_CFLAGS := $(subst -I,-isystem ,$(shell $(SDL_CONFIG) --cflags))
ifeq ($(DP_LINK_SDL),shared)
	SDL_LIBS := $(shell $(SDL_CONFIG) --libs)
else ifeq ($(DP_LINK_SDL),static)
	SDL_LIBS := $(shell $(SDL_CONFIG) --static-libs)
else
  $(error DP_LINK_SDL must be shared or static)
endif
endif

# zlib
DP_LINK_ZLIB ?= shared
ifeq ($(DP_LINK_ZLIB),shared)
	CFLAGS_LIBZ := -DLINK_TO_ZLIB
	LIB_Z       := -lz
else ifeq ($(DP_LINK_ZLIB),static)
	CFLAGS_LIBZ := -DLINK_TO_ZLIB
	LIB_Z       := -l:libz.a
else ifneq ($(DP_LINK_ZLIB),dlopen)
  $(error DP_LINK_ZLIB must be shared, static or dlopen)
endif

# libjpeg
DP_LINK_JPEG ?= shared
ifeq ($(DP_LINK_JPEG),shared)
	CFLAGS_LIBJPEG := -DLINK_TO_LIBJPEG
	LIB_JPEG       := -ljpeg
else ifeq ($(DP_LINK_JPEG),static)
	CFLAGS_LIBJPEG := -DLINK_TO_LIBJPEG
	LIB_JPEG       := -l:libjpeg.a
else ifneq ($(DP_LINK_JPEG),dlopen)
  $(error DP_LINK_JPEG must be shared, static or dlopen)
endif

# ODE (leave empty to disable)
DP_LINK_ODE ?=
ODE_CONFIG  ?= ode-config
ifeq ($(DP_LINK_ODE),shared)
	LIB_ODE    := $(shell $(ODE_CONFIG) --libs)
	CFLAGS_ODE := $(shell $(ODE_CONFIG) --cflags) -DUSEODE -DLINK_TO_LIBODE
else ifeq ($(DP_LINK_ODE),static)
	# This is the configuration from Xonotic
	LIB_ODE    := -l:libode.a -lstdc++ -pthread
	CFLAGS_ODE := -DUSEODE -DLINK_TO_LIBODE -DdDOUBLE
else ifeq ($(DP_LINK_ODE),dlopen)
	CFLAGS_ODE := -DUSEODE
else ifneq ($(DP_LINK_ODE),)
  $(error DP_LINK_ODE must be shared, static, dlopen or empty)
endif

# d0_blind_id
DP_LINK_CRYPTO ?= dlopen
ifeq ($(DP_LINK_CRYPTO),shared)
	LIB_CRYPTO    := -ld0_blind_id
	CFLAGS_CRYPTO := -DLINK_TO_CRYPTO
else ifeq ($(DP_LINK_CRYPTO),static)
	LIB_CRYPTO    := -l:libd0_blind_id.a -lgmp
	CFLAGS_CRYPTO := -DLINK_TO_CRYPTO
else ifeq ($(DP_LINK_CRYPTO),static_inc_gmp)
	LIB_CRYPTO    := -l:libd0_blind_id.a -l:libgmp.a
	CFLAGS_CRYPTO := -DLINK_TO_CRYPTO
else ifneq ($(DP_LINK_CRYPTO),dlopen)
  $(error DP_LINK_CRYPTO must be shared, static, static_inc_gmp or dlopen)
endif

# d0_rijndael
DP_LINK_CRYPTO_RIJNDAEL ?= dlopen
ifeq ($(DP_LINK_CRYPTO_RIJNDAEL),shared)
	LIB_CRYPTO_RIJNDAEL    := -ld0_rijndael
	CFLAGS_CRYPTO_RIJNDAEL := -DLINK_TO_CRYPTO_RIJNDAEL
else ifeq ($(DP_LINK_CRYPTO_RIJNDAEL),static)
	LIB_CRYPTO_RIJNDAEL    := -l:libd0_rijndael.a
	CFLAGS_CRYPTO_RIJNDAEL := -DLINK_TO_CRYPTO_RIJNDAEL
else ifneq ($(DP_LINK_CRYPTO_RIJNDAEL),dlopen)
  $(error DP_LINK_CRYPTO_RIJNDAEL must be shared, static or dlopen)
endif

# libxmp (snd_xmp.o is always built; the mode only decides how it finds libxmp)
DP_LINK_XMP ?= dlopen
ifeq ($(DP_LINK_XMP),shared)
	LIB_XMP    := -lxmp
	CFLAGS_XMP := -DUSEXMP -DLINK_TO_LIBXMP
else ifeq ($(DP_LINK_XMP),static)
	LIB_XMP    := -l:libxmp.a
	CFLAGS_XMP := -DUSEXMP -DLINK_TO_LIBXMP
else ifeq ($(DP_LINK_XMP),dlopen)
	CFLAGS_XMP := -DUSEXMP
else
  $(error DP_LINK_XMP must be shared, static or dlopen)
endif


##### Compiler and linker flags #####

# x86-64-v3 = AVX2, FMA, BMI1/2. The previous "-mno-avx" (added because AVX auto-vectorisation
# caused subtle bugs in Xonotic QC physics and changed the CI hash) is gone, so re-check physics
# and the demo/CI hash on the first build; add -mno-avx back here if they change.
ARCH ?= -march=x86-64-v3

# Per-target CPU baseline. Both default to ARCH; override one to loosen it, e.g. a dedicated
# server that has to run on old VPS hardware:  make ARCH_SV=-march=x86-64-v2 sv-release
ARCH_SV  ?= $(ARCH)
ARCH_SDL ?= $(ARCH)

# -ffp-contract=off: v3 has FMA and clang fuses a*b+c by default, which changes float results
# (QC physics, CI hash). Remove it if you want the extra speed and don't need identical results.
FPFLAGS := -fno-math-errno -fno-trapping-math -ffp-contract=off

# -fno-strict-aliasing (see OPT_COMMON below): the engine casts between float/int/byte buffers in many places and ThinLTO
# sees far more of the program at once, so don't rely on strict aliasing being respected (~0-2%).
# Try removing it if you have tested that the build is fine without.

# NOTE: *never* *ever* use the -ffast-math or -funsafe-math-optimizations flag
# Also, since gcc 5, -ffinite-math-only makes NaN and zero compare equal inside engine code but
# not inside QC, which causes error spam for seemingly valid QC code like
# if (x != 0) return 1 / x;
# -flto=thin and --icf=all need clang and lld (llvm-mingw).
# -fno-ident drops the compiler version string from the objects/executable.
# OPT_* are used for both compiling and linking: with ThinLTO the codegen happens at link time
# and takes its -O level and -march from the link command.
OPT_COMMON := -O3 $(FPFLAGS) -fno-strict-aliasing -flto=thin -fno-ident
OPT_SV     := $(OPT_COMMON) $(ARCH_SV)
OPT_SDL    := $(OPT_COMMON) $(ARCH_SDL)

WARNINGS := -Wall -Werror=vla -Wc++-compat -Wwrite-strings -Wshadow -Wold-style-definition \
	-Wstrict-prototypes -Wsign-compare -Wdeclaration-after-statement -Wmissing-prototypes

# Sources live in src/<subsystem>/; headers are included by bare name, so every
# subsystem directory is on the include path.
SRC_SUBDIRS := core fs net client server vm physics render model sound
SRC_DIRS    := $(addprefix src/,$(SRC_SUBDIRS))
WINRES_DIR  := platform/windows

vpath %.c  $(SRC_DIRS)
vpath %.rc $(WINRES_DIR)

# -MMD -MP: generate .d dependency files (-MP so deleted headers don't break the build)
CFLAGS_BASE := -fdata-sections -ffunction-sections -fvisibility=hidden \
	-DUSE_WSPIAPI_H -DSUPPORTIPV6 -D_FILE_OFFSET_BITS=64 -D__KERNEL_STRICT_NAMES \
	-MMD -MP $(WARNINGS) $(CFLAGS_FS) $(CFLAGS_LIBZ) $(CFLAGS_LIBJPEG) $(CFLAGS_XMP) \
	$(CFLAGS_ODE) $(CFLAGS_CRYPTO) $(CFLAGS_CRYPTO_RIJNDAEL) \
	$(addprefix -I,$(SRC_DIRS)) $(CFLAGS_EXTRA)

CFLAGS_SV  := $(OPT_SV) $(CFLAGS_BASE)
CFLAGS_SDL := $(OPT_SDL) $(CFLAGS_BASE) $(SDL_CFLAGS) -DCONFIG_MENU $(CFLAGS_CAPTURE)

# builddate.c is deliberately compiled as part of the link command (not to a .o), so it
# is rebuilt on every link and the executable gets an accurate build date string.
VCREVISION := $(shell git describe --always --dirty='~' 2>/dev/null || echo -)
# -s strips symbols at link time, so there is no separate strip step.
LDFLAGS_BASE := -Wl,--gc-sections,--icf=all,-s -DVCREVISION=$(VCREVISION) -DBUILDTYPE=release
LDFLAGS_SV   := $(OPT_SV) $(LDFLAGS_BASE)
LDFLAGS_SDL  := $(OPT_SDL) $(LDFLAGS_BASE)

LIBS_SV  := $(LIB_CRYPTO) $(LIB_CRYPTO_RIJNDAEL) -mconsole -lwinmm -lws2_32 $(LIB_Z) $(LIB_JPEG) $(LIB_ODE)
LIBS_SDL := $(LIB_CRYPTO) $(LIB_CRYPTO_RIJNDAEL) $(SDL_LIBS) -lwinmm -lws2_32 $(LIB_Z) $(LIB_JPEG) $(LIB_ODE) $(LIB_XMP)


##### Objects #####

OBJ_COMMON := \
	bih.o crypto.o cd_shared.o cl_cmd.o cl_collision.o cl_demo.o cl_ents.o cl_ents4.o \
	cl_ents5.o cl_ents_nq.o cl_ents_qw.o cl_input.o cl_main.o cl_parse.o cl_particles.o \
	cl_screen.o cl_video.o cl_video_libavw.o clvm_cmds.o cmd.o collision.o com_crc16.o \
	com_ents.o com_ents4.o com_game.o com_infostring.o com_msg.o common.o console.o \
	csprogs.o curves.o cvar.o dpvsimpledecode.o filematch.o fractalnoise.o fs.o ft2.o \
	utf8lib.o gl_backend.o gl_draw.o gl_rmain.o gl_rsurf.o gl_textures.o hmac.o host.o \
	image.o image_png.o jpeg.o keys.o lhnet.o libcurl.o mathlib.o matrixlib.o mdfour.o \
	meshqueue.o mod_skeletal_animatevertices_sse.o mod_skeletal_animatevertices_generic.o \
	model_alias.o model_brush.o model_shared.o model_sprite.o netconn.o palette.o phys.o \
	polygon.o portals.o protocol.o prvm_cmds.o prvm_edict.o prvm_exec.o r_explosion.o \
	r_lightning.o r_modules.o r_shadow.o r_sky.o r_sprites.o r_stats.o sbar.o sv_ccmds.o \
	sv_demo.o sv_ents.o sv_ents4.o sv_ents5.o sv_ents_csqc.o sv_ents_nq.o sv_main.o \
	sv_move.o sv_phys.o sv_save.o sv_send.o sv_user.o svbsp.o svvm_cmds.o sys_shared.o \
	taskqueue.o vid_shared.o view.o wad.o world.o zone.o

OBJ_MENU  := menu.o mvm_cmds.o
OBJ_SOUND := snd_main.o snd_mem.o snd_mix.o snd_ogg.o snd_wav.o snd_xmp.o snd_sdl.o

OBJ_SV_LIST  := sys_null.o vid_null.o thread_null.o snd_null.o $(OBJ_COMMON)
OBJ_SDL_LIST := sys_sdl.o vid_sdl.o thread_sdl.o $(OBJ_MENU) $(OBJ_SOUND) $(OBJ_CAPTURE) $(OBJ_COMMON)

# Dedicated and client objects are built with different flags, so they live in
# separate directories.
OBJS_SV  := $(addprefix $(OUT)/sv/,$(OBJ_SV_LIST))
OBJS_SDL := $(addprefix $(OUT)/sdl/,$(OBJ_SDL_LIST))


##### Targets #####

.PHONY: release sv-release sdl-release clean help

release: sv-release sdl-release

sv-release:  $(EXE_SV)
sdl-release: $(EXE_SDL)

help:
	@echo "make [-j<n>] <target>     (set SDL_CONFIG=/path/to/sdl2-config if needed)"
	@echo "  release (default)       dedicated server + SDL client ($(EXE_SV), $(EXE_SDL))"
	@echo "  sv-release              dedicated server only"
	@echo "  sdl-release             SDL client only"
	@echo "  clean                   remove executables and build-obj/"
	@echo "  V=1                     show full command lines"

.DEFAULT_GOAL := release

# Executables
$(EXE_SV):  LIBS = $(LIBS_SV)
$(EXE_SV):  LDFLAGS = $(LDFLAGS_SV)
$(EXE_SDL): LIBS = $(LIBS_SDL)
$(EXE_SDL): LDFLAGS = $(LDFLAGS_SDL)

$(EXE_SV):  $(OBJS_SV)  $(OUT)/res/darkplaces.o
$(EXE_SDL): $(OBJS_SDL) $(OUT)/res/darkplaces.o

$(EXE_ALL): builddate.c
	$(call say,LD    $@)
	$(Q)$(CC) -o $@ $^ $(LDFLAGS) $(LIBS)

# Objects
$(OUT)/sv/%.o: %.c
	@mkdir -p $(@D)
	$(call say,CC    $<)
	$(Q)$(CC) $(CFLAGS_SV) $(CFLAGS_FILE) -c $< -o $@

$(OUT)/sdl/%.o: %.c
	@mkdir -p $(@D)
	$(call say,CC    $<)
	$(Q)$(CC) $(CFLAGS_SDL) $(CFLAGS_FILE) -c $< -o $@

# Per-file flags
$(OUT)/%/mod_skeletal_animatevertices_sse.o: CFLAGS_FILE := -msse

# Windows resources (icon + version info)
$(OUT)/res/%.o: %.rc
	@mkdir -p $(@D)
	$(call say,RC    $<)
	$(Q)$(WINDRES) -I $(WINRES_DIR) -o $@ $<

# Header dependencies
-include $(OBJS_SV:.o=.d) $(OBJS_SDL:.o=.d)

# If requested, clean must always run first (even with -j):
.EXTRA_PREREQS := $(filter clean,$(MAKECMDGOALS))
clean: .EXTRA_PREREQS =
clean:
	$(call say,CLEAN)
	$(Q)rm -rf $(EXE_ALL) $(OUT)