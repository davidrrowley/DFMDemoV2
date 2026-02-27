default:
	@just --list

help:
	@echo "Common tasks"
	@echo "  just fmt   - run formatting"
	@echo "  just lint  - run linting"
	@echo "  just test  - run tests"
	@echo "  just build - run build"

fmt:
	@echo "Define formatting command for your project."

lint:
	@echo "Define lint command for your project."

test:
	@echo "Define test command for your project."

build:
	@echo "Define build command for your project."
