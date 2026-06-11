APP_NAME     := Jellyfish
APP_VERSION  := 2.5
BUILD_NUMBER := 14
BUNDLE_ID    := de.extragroup.jellyfish
ARCH         := $(shell uname -m)
BUILD_DIR    := .build/$(ARCH)-apple-macosx/release
APP_BUNDLE   := build/$(APP_NAME).app
CONTENTS     := $(APP_BUNDLE)/Contents
DMG_NAME     := build/$(APP_NAME)-$(APP_VERSION).dmg

.PHONY: all release bundle dmg install clean

all: release

# ── Build ──────────────────────────────────────────────────────────────────────
release:
	swift build -c release
	@$(MAKE) --no-print-directory bundle

# ── Bundle ─────────────────────────────────────────────────────────────────────
bundle:
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"

	cp "$(BUILD_DIR)/$(APP_NAME)" "$(CONTENTS)/MacOS/$(APP_NAME)"

	cp Resources/*.icns "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/StatusBarTemplate@2x.png" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/snippets.json" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-clock.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-calendar.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-clipboard.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-calculator.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-optional.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-dropdown.svg" "$(CONTENTS)/Resources/"
	cp "Sources/Jellyfish/icon-condition.svg" "$(CONTENTS)/Resources/"

	@sed \
		-e 's/$$(APP_VERSION)/$(APP_VERSION)/g' \
		-e 's/$$(BUILD_NUMBER)/$(BUILD_NUMBER)/g' \
		"Resources/Info.plist" > "$(CONTENTS)/Info.plist"

	xattr -cr "$(APP_BUNDLE)"
	codesign --force --deep --sign "Jellyfish Local Signing" "$(APP_BUNDLE)" 2>/dev/null || \
		codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "✅ $(APP_BUNDLE) fertig"

# ── DMG ────────────────────────────────────────────────────────────────────────
dmg: release
	@MOUNT=$$(mktemp -d) && \
	rm -f "$(DMG_NAME)" "build/$(APP_NAME)_rw.dmg" && \
	hdiutil create -size 100m -volname "$(APP_NAME)" -fs HFS+ -o "build/$(APP_NAME)_rw.dmg" && \
	hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$$MOUNT" "build/$(APP_NAME)_rw.dmg" && \
	ditto "$(APP_BUNDLE)" "$$MOUNT/$(APP_NAME).app" && \
	ln -s /Applications "$$MOUNT/Applications" && \
	hdiutil detach "$$MOUNT" && \
	rmdir "$$MOUNT" && \
	hdiutil convert "build/$(APP_NAME)_rw.dmg" -format UDZO -o "$(DMG_NAME)" && \
	rm -f "build/$(APP_NAME)_rw.dmg"
	@echo "✅ $(DMG_NAME) erstellt"
	@pkill $(APP_NAME) 2>/dev/null || true
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "✅ /Applications/$(APP_NAME).app aktualisiert"

# ── Install ────────────────────────────────────────────────────────────────────
install: release
	@pkill $(APP_NAME) 2>/dev/null || true
	cp -R "$(APP_BUNDLE)" /Applications/
	open "/Applications/$(APP_NAME).app"
	@echo "✅ $(APP_NAME) installiert und gestartet"

# ── Clean ──────────────────────────────────────────────────────────────────────
clean:
	rm -rf .build build
