# homestak-dev workspace Makefile

.PHONY: help install-deps setup check-deps install-deps-all

help:
	@echo "homestak-dev - polyrepo workspace"
	@echo ""
	@echo "Targets:"
	@echo "  make setup            - Full workspace setup (clone, register, check deps)"
	@echo "  make check-deps       - Check if all dependencies are installed"
	@echo "  make install-deps     - Install workspace dependencies (gita)"
	@echo "  make install-deps-all - Install all repo dependencies (requires sudo)"
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
	@echo "Installing gita..."
	@command -v pipx >/dev/null 2>&1 || { echo "Error: pipx not found"; exit 1; }
	@command -v gita >/dev/null 2>&1 || pipx install gita
	@echo "gita installed"

check-deps:
	@echo "Checking dependencies..."
	@missing=""; \
	command -v gita >/dev/null 2>&1 && echo "  gita:       OK" || { echo "  gita:       MISSING"; missing="$$missing gita"; }; \
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
	@for repo in .claude .github ansible bootstrap iac-driver packer site-config tofu; do \
		[ -d "$$repo" ] || git clone https://github.com/homestak-dev/$$repo.git; \
	done
	@echo "Registering repos with gita..."
	@gita add .claude .github ansible bootstrap iac-driver packer site-config tofu homestak-dev
	@echo ""
	@$(MAKE) check-deps || true
	@echo ""
	@echo "Configuring site-config git hooks..."
	@cd site-config && make setup
	@echo ""
	@echo "Setup complete. Run 'gita ll' to verify."
