VERSION := $(shell tr -d '[:space:]' < VERSION)

.PHONY: help doctor install uninstall test-print pkg release release-pkg check clean

help:
	@echo "Canon G3010 macOS Compatibility v$(VERSION)"
	@echo "  make install       Install"
	@echo "  make uninstall     Uninstall"
	@echo "  make doctor        Diagnostics"
	@echo "  make test-print    Test page"
	@echo "  make release       User ZIP + SHA256SUMS + release notes"
	@echo "  make release-pkg   Release assets including .pkg"
	@echo "  make pkg           Build .pkg only"
	@echo "  make check         Syntax check"
	@echo "  make clean         Remove build/ and dist/"

doctor:
	./scripts/g3010-doctor.sh

install:
	./scripts/install.sh --accept-canon-license --force

uninstall:
	./scripts/uninstall.sh

test-print:
	./scripts/test-print.sh

pkg:
	./packaging/build-pkg.sh

release:
	./packaging/build-release.sh

release-pkg:
	./packaging/build-release.sh --with-pkg

check:
	@zsh -n scripts/lib/common.sh
	@zsh -n scripts/install.sh
	@zsh -n scripts/uninstall.sh
	@zsh -n scripts/g3010-doctor.sh
	@zsh -n scripts/test-print.sh
	@zsh -n scripts/ensure-canon-driver.sh
	@zsh -n packaging/build-pkg.sh
	@zsh -n packaging/build-release.sh
	@zsh -n Install.command
	@echo "OK"

clean:
	rm -rf build dist
