# homestak-dev workspace Makefile

.PHONY: help install-deps

help:
	@echo "homestak-dev - polyrepo workspace"
	@echo ""
	@echo "  make install-deps  - Install workspace dependencies (gita)"
	@echo ""
	@echo "Gita Commands:"
	@echo "  gita ll            - Show status of all repos"
	@echo "  gita fetch         - Fetch all repos"
	@echo "  gita pull          - Pull all repos"
	@echo ""
	@echo "Repos:"
	@gita ls 2>/dev/null || echo "  (gita not installed - run make install-deps)"

install-deps:
	@echo "Installing gita..."
	@command -v pipx >/dev/null 2>&1 || { echo "Error: pipx not found"; exit 1; }
	@pipx install gita
	@echo "Registering repos..."
	@gita add -r .
	@gita add .github 2>/dev/null || true
	@echo "Done. Run 'gita ll' to see repo status."
