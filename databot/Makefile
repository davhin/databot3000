.PHONY: all

all: check

check: mypy ruff

mypy:
	uvx mypy@latest src/

ruff:
	uvx ruff@latest check src/
	uvx ruff@latest format src/
