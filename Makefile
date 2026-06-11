APP    := TaskManager
BUNDLE := build/$(APP).app
BINARY := .build/release/$(APP)

.PHONY: build run dev clean

build:
	swift build -c release
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Support/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp -R .build/release/$(APP)_$(APP).bundle $(BUNDLE)/Contents/Resources/
	codesign --force -s - $(BUNDLE)

run: build
	open $(BUNDLE)

dev:
	swift run

clean:
	rm -rf .build build
