APP_NAME     := Jellyfish
APP_VERSION  := 0.0.2
BUILD_NUMBER := 2
BUNDLE_ID    := de.extragroup.jellyfish
ARCH         := $(shell uname -m)
BUILD_DIR    := .build/$(ARCH)-apple-macosx/release
APP_BUNDLE   := build/$(APP_NAME).app
CONTENTS     := $(APP_BUNDLE)/Contents
SIGN_TOOL    := /tmp/sparkle/bin/sign_update

.PHONY: all release bundle install archive clean

all: release

# ── Build ──────────────────────────────────────────────────────────────────────
release:
	swift build -c release \
		-Xlinker -rpath -Xlinker "@executable_path/../Frameworks"
	@$(MAKE) --no-print-directory bundle

# ── Bundle ─────────────────────────────────────────────────────────────────────
bundle:
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources" "$(CONTENTS)/Frameworks"

	# Binary
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(CONTENTS)/MacOS/$(APP_NAME)"

	# Sparkle framework
	@SPARKLE_FW=$$(find .build/artifacts -name "Sparkle.framework" -type d 2>/dev/null | head -1); \
	if [ -n "$$SPARKLE_FW" ]; then \
		cp -R "$$SPARKLE_FW" "$(CONTENTS)/Frameworks/"; \
	else \
		echo "⚠️  Sparkle.framework nicht gefunden"; \
	fi

	# SPM resources bundle
	@if [ -d "$(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle" ]; then \
		cp -R "$(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle" "$(CONTENTS)/Resources/"; \
	fi

	# App icons (alle Varianten für dynamisches Erscheinungsbild)
	cp Resources/*.icns "$(CONTENTS)/Resources/"

	# Info.plist — substitute version placeholders
	@sed \
		-e 's/$$(APP_VERSION)/$(APP_VERSION)/g' \
		-e 's/$$(BUILD_NUMBER)/$(BUILD_NUMBER)/g' \
		"Resources/Info.plist" > "$(CONTENTS)/Info.plist"

	# Extended Attributes entfernen (verhindert codesign-Fehler)
	xattr -cr "$(APP_BUNDLE)"
	# Mit lokalem Self-signed-Zertifikat signieren (stabiles TCC-Identity)
	codesign --force --deep --sign "Jellyfish Local Signing" "$(APP_BUNDLE)" 2>/dev/null || \
		codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "✅ $(APP_BUNDLE) fertig"

# ── Install ────────────────────────────────────────────────────────────────────
install: release
	@pkill $(APP_NAME) 2>/dev/null || true
	cp -R "$(APP_BUNDLE)" /Applications/
	open "/Applications/$(APP_NAME).app"
	@echo "✅ $(APP_NAME) installiert und gestartet"

# ── Archive (für GitHub Release) ───────────────────────────────────────────────
archive: release
	@mkdir -p build
	cd build && zip -r "$(APP_NAME)-$(APP_VERSION).zip" "$(APP_NAME).app"
	@echo "✅ build/$(APP_NAME)-$(APP_VERSION).zip erstellt"

# ── Appcast-Signatur ausgeben (nach Archive ausführen) ─────────────────────────
sign:
	@if [ ! -f "build/$(APP_NAME)-$(APP_VERSION).zip" ]; then $(MAKE) archive; fi
	@if [ -f "$(SIGN_TOOL)" ]; then \
		"$(SIGN_TOOL)" "build/$(APP_NAME)-$(APP_VERSION).zip"; \
	else \
		echo "⚠️  Sparkle-Tools nicht gefunden unter $(SIGN_TOOL)"; \
	fi

# ── Clean ──────────────────────────────────────────────────────────────────────
clean:
	rm -rf .build build
