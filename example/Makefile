SOURCES += example.cpp
SOURCES += ../src/glvr.mm
TARGET = GLVR

DEBUG_DIR = build/Debug/$(TARGET).app/Contents
RELEASE_DIR = build/Release/$(TARGET).app/Contents
FLAGS = $(SOURCES) -I../src -Wall -Wextra -std=c++11 -Wno-unused-parameter -L../lib -lc++ -framework OpenGL -framework Cocoa -framework IOKit

default: debug

debug:
	rm -fr $(DEBUG_DIR)
	mkdir -p $(DEBUG_DIR)/MacOS
	cp Info.plist $(DEBUG_DIR)
	clang $(FLAGS) -o $(DEBUG_DIR)/MacOS/$(TARGET) -lovrd

release:
	rm -fr $(RELEASE_DIR)
	mkdir -p $(RELEASE_DIR)/MacOS
	cp Info.plist $(RELEASE_DIR)
	clang $(FLAGS) -o $(RELEASE_DIR)/MacOS/$(TARGET) -lovr -O3 -DNDEBUG
	strip $(RELEASE_DIR)/MacOS/$(TARGET)

run: debug
	./$(DEBUG_DIR)/MacOS/$(TARGET)

clean:
	rm -fr build
