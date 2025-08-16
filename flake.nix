{
  description = "Neovim plugin development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
		pluginPath = ./.;
        testConfig = pkgs.writeText "init.lua" ''
		  vim.cmd('set rtp^=' .. vim.fn.fnamemodify("${pluginPath}", ":p"))
		  require("timekeeper")
          -- Optionally: require your plugin here
        '';
        testNeovim = pkgs.writeShellScriptBin "test-nvim" ''
          exec ${pkgs.neovim}/bin/nvim -u ${testConfig} "$@"
        '';
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.neovim
            pkgs.lua
            pkgs.stylua
            pkgs.git
            testNeovim
          ];
		  SHELL = "${pkgs.zsh}/bin/zsh";
          shellHook = ''
            echo "Run 'test-nvim' to launch Neovim with only your plugin loaded."
			alias m='make test'
          '';
        };
      }
    );
}

