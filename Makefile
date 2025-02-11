# vim: tabstop=8
PYTHON			?= python
CLIPS_VERSION		?= 6.40
CLIPS_SOURCE_URL	?= "https://sourceforge.net/projects/clipsrules/files/CLIPS/6.40/clips_core_source_640.zip"
MAKEFILE_NAME		?= makefile
SHARED_INCLUDE_DIR	?= /usr/local/include
SHARED_LIBRARY_DIR	?= /usr/local/lib

# platform detection
PLATFORM = $(shell uname -s)

.PHONY: clips clipspy test install clean

all: clips_source clips clipspy

clips_source:
	wget -O clips.zip $(CLIPS_SOURCE_URL)
	unzip -jo clips.zip -d clips_source

ifeq ($(PLATFORM),Darwin) # macOS
	TARGET_ARCH ?= $(shell uname -m)
	LDLIBS = -lm
	ifneq "$(wildcard /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib)" ""
		LDLIBS += -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib
	endif
clips: clips_source
	$(MAKE) -f $(MAKEFILE_NAME) -C clips_source                            \
		CFLAGS="-std=c99 -O3 -fno-strict-aliasing -fPIC"               \
		LDLIBS="$(LDLIBS)"
	ld clips_source/*.o $(LDLIBS) -dylib -arch $(TARGET_ARCH)              \
		-o clips_source/libclips.so
else
clips: clips_source
	$(MAKE) -f $(MAKEFILE_NAME) -C clips_source                            \
		CFLAGS="-std=c99 -O3 -fno-strict-aliasing -fPIC"               \
		LDLIBS="-lm -lrt"
	ld -G clips_source/*.o -o clips_source/libclips.so
endif

clipspy: clips
	$(PYTHON) setup.py build_ext

test: clipspy
	cp build/lib.*/clips/_clips*.so clips
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:clips_source			       \
		$(PYTHON) -m pytest -v

install-clips: clips
	install -d $(SHARED_INCLUDE_DIR)/
	install -m 644 clips_source/clips.h $(SHARED_INCLUDE_DIR)/
	install -d $(SHARED_INCLUDE_DIR)/clips
	install -m 644 clips_source/*.h $(SHARED_INCLUDE_DIR)/clips/
	install -d $(SHARED_LIBRARY_DIR)/
	install -m 644 clips_source/libclips.so                                \
	 	$(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION)
	ln -sf $(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION)	       \
	 	$(SHARED_LIBRARY_DIR)/libclips.so.6
	ln -sf $(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION)	       \
	 	$(SHARED_LIBRARY_DIR)/libclips.so
	-ldconfig -n -v $(SHARED_LIBRARY_DIR)

install: clipspy install-clips
	$(PYTHON) setup.py install

clean:
	-rm clips.zip
	-rm -fr clips_source build dist clipspy.egg-info
