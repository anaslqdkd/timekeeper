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
			pkgs.lua52Packages.luarocks
			pkgs.lua52Packages.luarocks-nix
			pkgs.lua52Packages.luarocks_bootstrap
			pkgs.gcc
			pkgs.unzip
			pkgs.cmake
			pkgs.pkg-config
            testNeovim
			nixpkgs.legacyPackages.x86_64-linux.lua52Packages.luasql-sqlite3
			nixpkgs.legacyPackages.x86_64-linux.lua51Packages.luasql-sqlite3
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

