APP_NAME = Paste as Markdown
BUNDLE = $(APP_NAME).app
EXECUTABLE = paste-as-markdown

CC = clang
OBJC_FLAGS = -fobjc-arc -framework Cocoa -framework JavaScriptCore -mmacosx-version-min=11.0
SRC = main.m MarkdownConverter.m ClipboardHelper.m
TEST_SRC = tests.m MarkdownConverter.m ClipboardHelper.m

.PHONY: all clean js bundle run test dist

all: js bundle

# Step 1: Build the JS bundle (turndown + domino)
js: Resources/turndown-bundle.js

Resources/turndown-bundle.js: js/package.json js/build.js
	cd js && npm install --silent && node build.js

# Step 2: Compile the Objective-C binary
build/$(EXECUTABLE): $(SRC) MarkdownConverter.h ClipboardHelper.h
	@mkdir -p build
	$(CC) $(OBJC_FLAGS) -o $@ $(SRC)

# Step 3: Assemble the .app bundle
bundle: build/$(EXECUTABLE) Resources/turndown-bundle.js Info.plist
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@mkdir -p "$(BUNDLE)/Contents/Resources"
	cp build/$(EXECUTABLE) "$(BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(BUNDLE)/Contents/"
	cp Resources/turndown-bundle.js "$(BUNDLE)/Contents/Resources/"
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
