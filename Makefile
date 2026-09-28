# Persona — every build step goes through here (CLAUDE.md: never raw xcodebuild in the repo).
PROJECT  := Persona.xcodeproj
SCHEME   := Persona
DERIVED  := build/DerivedData
PACKAGES := Packages/VaultKit Packages/DesignKit
APP      := $(DERIVED)/Build/Products/Debug/Persona.app
XCODEBUILD = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' \
             -derivedDataPath $(DERIVED) -configuration Debug -quiet

.PHONY: gen build test test-packages test-app run format vault-dump stress-vault clean-stress dist clean

## gen: regenerate Persona.xcodeproj from project.yml (A03)
gen:
	xcodegen generate --quiet

## build: debug build of the app (bundle id …persona.debug)
build: gen
	$(XCODEBUILD) build

## test: package tests, then the app's unit tests
test: test-packages test-app

test-packages:
	@for pkg in $(PACKAGES); do echo "== swift test $$pkg"; (cd $$pkg && swift test) || exit 1; done

test-app: gen
	$(XCODEBUILD) test

## run: launch the debug app; `make run VAULT=<path>` opens a test vault (§8.6)
run: build
	open -n "$(APP)" $(if $(VAULT),--args --vault "$(VAULT)")

## format: SwiftFormat only — no SwiftLint (P0)
format:
	swiftformat App AppTests Packages

## vault-dump: read-only index summary of a vault; `make vault-dump VAULT=<folder>`, default the fixture vault
vault-dump:
	@vault="$(or $(VAULT),Packages/VaultKit/Tests/Fixtures/Vaults/Basic)"; \
	case "$$vault" in /*) ;; *) vault="$(CURDIR)/$$vault" ;; esac; \
	cd Packages/VaultKit && swift run -q vaultctl "$$vault"

stress-vault:
	@echo "stress-vault arrives in P8."; exit 1

clean-stress:
	@echo "clean-stress arrives in P8."; exit 1

dist:
	@echo "dist arrives in P9 (Developer ID + notarised dmg, A13)."; exit 1

clean:
	rm -rf build $(PROJECT) Packages/VaultKit/.build Packages/DesignKit/.build
