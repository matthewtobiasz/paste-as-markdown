APP_NAME = Paste as Markdown
BUNDLE = $(APP_NAME).app
EXECUTABLE = paste-as-markdown

CC = clang
OBJC_FLAGS = -fobjc-arc -framework Cocoa -framework JavaScriptCore -mmacosx-version-min=11.0 -Isrc
SRC = src/main.m src/MarkdownConverter.m src/ClipboardHelper.m
TEST_SRC = test/tests.m src/MarkdownConverter.m src/ClipboardHelper.m

.PHONY: all clean js bundle run test dist

all: js bundle

# Step 1: Build the JS bundle (turndown + domino)
js: Resources/turndown-bundle.js

Resources/turndown-bundle.js: js/package.json js/build.js js/entry.js js/converter.js
	cd js && npm ci --silent && node build.js

# Step 2: Compile the Objective-C binary
build/$(EXECUTABLE): $(SRC) src/MarkdownConverter.h src/ClipboardHelper.h
	@mkdir -p build
	$(CC) $(OBJC_FLAGS) -o $@ $(SRC)

# Step 3: Assemble the .app bundle
# Versions are stamped from git tags at build time — no manual bumping needed.
# CFBundleShortVersionString = marketing version (e.g. 0.1.3)
# CFBundleVersion = full build version (e.g. 0.1.3 at tag, 0.1.3.2.gabcdef after)
GIT_DESCRIBE := $(shell git describe --tags --always 2>/dev/null || echo v0.0.0)
VERSION := $(shell echo "$(GIT_DESCRIBE)" | sed 's/^v//' | sed 's/-.*//')
BUILD_VERSION := $(shell echo "$(GIT_DESCRIBE)" | sed 's/^v//' | sed 's/-/./g')

bundle: build/$(EXECUTABLE) Resources/turndown-bundle.js src/Info.plist
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@mkdir -p "$(BUNDLE)/Contents/Resources"
	cp build/$(EXECUTABLE) "$(BUNDLE)/Contents/MacOS/"
	cp src/Info.plist "$(BUNDLE)/Contents/"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_VERSION)" "$(BUNDLE)/Contents/Info.plist"
	cp Resources/turndown-bundle.js "$(BUNDLE)/Contents/Resources/"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/"
	codesign --force --deep --sign - "$(BUNDLE)"

# Run the app
run: bundle
	open "$(BUNDLE)"

# Build and run tests
test: Resources/turndown-bundle.js
	@mkdir -p build
	$(CC) $(OBJC_FLAGS) -o build/tests $(TEST_SRC)
	cp Resources/turndown-bundle.js build/
	cd build && ./tests

# Create a distributable ZIP
dist: bundle
	zip -r "PasteAsMarkdown.zip" "$(BUNDLE)"
	@echo "Created PasteAsMarkdown.zip"

clean:
	rm -rf build "$(BUNDLE)"
	rm -f Resources/turndown-bundle.js PasteAsMarkdown.zip
	rm -rf js/node_modules
