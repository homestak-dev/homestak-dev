# homestak-dev workspace Makefile

.PHONY: help install-deps setup check-deps install-deps-all test lint

help:
	@echo "homestak-dev - polyrepo workspace"
	@echo ""
	@echo "Targets:"
	@echo "  make setup            - Full workspace setup (clone, register, check deps)"
	@echo "  make check-deps       - Check if all dependencies are installed"
	@echo "  make install-deps     - Install workspace dependencies (gita)"
	@echo "  make install-deps-all - Install all repo dependencies (requires sudo)"
	@echo "  make test             - Run release bats tests"
	@echo "  make lint             - Run shellcheck on release"
	@echo ""
	@echo "Gita Commands:"
	@echo "  gita ll                      - Show status of all repos"
	@echo "  gita fetch                   - Fetch all repos"
	@echo "  gita pull                    - Pull all repos"
	@echo "  gita shell make <target>     - Run make target in all repos"
	@echo ""
	@echo "Repos:"
	@gita ls 2>/dev/null || echo "  (gita not installed - run make install-deps)"

install-deps:
	@echo "Installing dependencies..."
	@command -v pipx >/dev/null 2>&1 || { echo "Error: pipx not found"; exit 1; }
	@command -v gita >/dev/null 2>&1 || pipx install gita
	@echo "  gita installed"
	@if [ "$$(id -u)" = "0" ]; then \
		command -v shellcheck >/dev/null 2>&1 || { apt-get update && apt-get install -y shellcheck; }; \
		echo "  shellcheck installed"; \
		command -v bats >/dev/null 2>&1 || { apt-get install -y bats; }; \
		echo "  bats installed"; \
	else \
		command -v shellcheck >/dev/null 2>&1 || echo "  shellcheck: run with sudo to install"; \
		command -v bats >/dev/null 2>&1 || echo "  bats: run with sudo to install"; \
	fi
	@echo "Done"

check-deps:
	@echo "Checking dependencies..."
	@missing=""; \
	command -v gita >/dev/null 2>&1 && echo "  gita:       OK" || { echo "  gita:       MISSING"; missing="$$missing gita"; }; \
	command -v bats >/dev/null 2>&1 && echo "  bats:       OK" || { echo "  bats:       MISSING"; missing="$$missing bats"; }; \
	command -v packer >/dev/null 2>&1 && echo "  packer:     OK" || { echo "  packer:     MISSING"; missing="$$missing packer"; }; \
	command -v shellcheck >/dev/null 2>&1 && echo "  shellcheck: OK" || { echo "  shellcheck: MISSING"; missing="$$missing shellcheck"; }; \
	command -v tofu >/dev/null 2>&1 && echo "  tofu:       OK" || { echo "  tofu:       MISSING"; missing="$$missing tofu"; }; \
	command -v ansible >/dev/null 2>&1 && echo "  ansible:    OK" || { echo "  ansible:    MISSING"; missing="$$missing ansible"; }; \
	command -v sops >/dev/null 2>&1 && echo "  sops:       OK" || { echo "  sops:       MISSING"; missing="$$missing sops"; }; \
	command -v age >/dev/null 2>&1 && echo "  age:        OK" || { echo "  age:        MISSING"; missing="$$missing age"; }; \
	if [ -n "$$missing" ]; then \
		echo ""; \
		echo "Missing dependencies:$$missing"; \
		echo "Run: sudo make install-deps-all"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "All dependencies installed."

install-deps-all:
	@echo "Installing dependencies across all repos..."
	@gita shell make install-deps

setup: install-deps
	@echo "Cloning child repos..."
	@[ -d ".claude" ]     || git clone https://github.com/homestak-dev/.claude.git
	@[ -d ".github" ]     || git clone https://github.com/homestak-dev/.github.git
	@[ -d "ansible" ]     || git clone https://github.com/homestak-iac/ansible.git
	@[ -d "bootstrap" ]   || git clone https://github.com/homestak/bootstrap.git
	@[ -d "iac-driver" ]  || git clone https://github.com/homestak-iac/iac-driver.git
	@[ -d "packer" ]      || git clone https://github.com/homestak-iac/packer.git
	@[ -d "config" ]    || git clone https://github.com/homestak/config.git
	@[ -d "tofu" ]        || git clone https://github.com/homestak-iac/tofu.git
	@echo "Registering repos with gita..."
	@gita add .claude .github ansible bootstrap iac-driver packer config tofu .
	@echo ""
	@$(MAKE) check-deps || true
	@echo ""
	@echo "Configuring config git hooks..."
	@cd config && make setup
	@echo ""
	@echo "Setup complete. Run 'gita ll' to verify."

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

test:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats not installed. Run: sudo apt install bats"; exit 1; }
	@echo "Running release tests..."
	@bats test/

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: shellcheck not installed. Run: sudo make install-deps"; exit 1; }
	@echo "Running shellcheck on release..."
	@shellcheck --severity=warning scripts/release scripts/lib/*.sh
