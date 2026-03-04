.PHONY: build release install clean test test-quick fixture demo-calculator demo-textedit demo

build:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/agent-native /usr/local/bin/agent-native
	@echo "Installed to /usr/local/bin/agent-native"

fixture:
	swiftc -o .build/TestFixture TestFixture/TestFixture.swift -framework Cocoa
	@echo "Built test fixture"

test: release fixture
	chmod +x test/integration.sh
	./test/integration.sh

test-quick: release
	chmod +x test/integration.sh
	./test/integration.sh --quick

demo-calculator: release
	./test/demo-calculator.sh

demo-textedit: release
	./test/demo-textedit.sh

demo: demo-calculator demo-textedit

clean:
	swift package clean
	rm -rf .build
