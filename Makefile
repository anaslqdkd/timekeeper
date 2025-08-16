.PHONY: dev test

dev:
	nix develop

test:
	nix develop --command test-nvim

