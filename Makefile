SHELL := bash

.PHONY: all scripts
all: dotfiles

.PHONY: dotfiles
dotfiles: # Installs the the dotfiles
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".git" -not -name ".config" -not -name ".github" -not -name ".*.swp" -not -name ".gnupg"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done;
	if [[ ! -d $(HOME)/.local/share/konsole ]]; then \
		mkdir -p $(HOME)/.local/share/konsole; \
	fi; 
	if [[ ! -d $(HOME)/.kde/share/config ]]; then \
		mkdir -p $(HOME)/.kde/share/config; \
	fi;

	ln -fn ./konsole/main.profile $(HOME)/.local/share/konsole/main.profile
	ln -fn ./kde/kdeglobals $(HOME)/.kde/share/config/kdeglobals

.PHONY: scripts
scripts: # Installs the scripts in .local/bin
	# Installs the scripts in /user/local/bin
	
	if [[ ! -d ~/.local/bin ]]; then \
		mkdir -p ~/.local/bin; \
	fi;

	for file in $(shell find $(CURDIR)/bin -type f -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		ln -sf $$file ~/.local/bin/$$f; \
	done	

.PHONY: lynx
lynx: 
	if [[ ! -d ~/.config ]]; then \
		mkdir -p ~/.config; \
	fi;
	rm -rf ~/.config/lynx 2>/dev/null
	ln -s "$$PWD" "$$HOME/.config/lynx"
	ls -l ~/.config/lynx

.PHONY: test
test: shellcheck ## Runs all the tests on the files in the repository.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run --rm -i $(DOCKER_FLAGS) \
		--name df-shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		jess/shellcheck ./test.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
