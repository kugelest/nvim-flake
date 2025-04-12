local servers = {}
if nixCats('neonixdev') then
	servers.lua_ls = {
		settings = {
			Lua = {
				formatters = {
					ignoreComments = true,
				},
				signatureHelp = { enabled = true },
				diagnostics = {
					globals = { 'nixCats' },
					disable = { 'missing-fields' },
				},
			},
			telemetry = { enabled = false },

		},
		filetypes = { 'lua' },
	}
	if require('nixCatsUtils').isNixCats then
		servers.nixd = {
			settings = {
				nixd = {
					nixpkgs = {
						-- nixd requires some configuration in flake based configs.
						-- luckily, the nixCats plugin is here to pass whatever we need!
						-- we passed this in via the `extra` table in our packageDefinitions
						-- for additional configuration options, refer to:
						-- https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
						expr = [[import (builtins.getFlake "]] ..
							nixCats.extra("nixdExtras.nixpkgs") .. [[") { }   ]],
					},
					formatting = {
						command = { "nixfmt" }
					},
					diagnostic = {
						suppress = {
							"sema-escaping-with"
						}
					}
				}
			}
		}
		-- If you integrated with your system flake,
		-- you should pass inputs.self as nixdExtras.flake-path
		-- that way it will ALWAYS work, regardless
		-- of where your config actually was.
		-- otherwise flake-path could be an absolute path to your system flake, or nil or false
		if nixCats.extra("nixdExtras.flake-path") then
			local flakePath = nixCats.extra("nixdExtras.flake-path")
			if nixCats.extra("nixdExtras.systemCFGname") then
				-- (builtins.getFlake "<path_to_system_flake>").nixosConfigurations."<name>".options
				servers.nixd.settings.nixd.options.nixos = {
					expr = [[(builtins.getFlake "]] .. flakePath .. [[").nixosConfigurations."]] ..
						nixCats.extra("nixdExtras.systemCFGname") .. [[".options]]
				}
			end
			if nixCats.extra("nixdExtras.homeCFGname") then
				-- (builtins.getFlake "<path_to_system_flake>").homeConfigurations."<name>".options
				servers.nixd.settings.nixd.options["home-manager"] = {
					expr = [[(builtins.getFlake "]] .. flakePath .. [[").homeConfigurations."]]
						.. nixCats.extra("nixdExtras.homeCFGname") .. [[".options]]
				}
			end
		end
	else
		servers.rnix = {}
		servers.nil_ls = {}
	end
end

if nixCats('markdown') then
	servers.marksman = {}
	vim.opt.conceallevel = 2
end

if nixCats('java') then
	servers.jdtls = {}
end

if nixCats('csharp') then
	local handle = io.popen("which OmniSharp")
    local omnisharp_path = handle:read("*a"):gsub("\n", "")
    handle:close()
    
    -- Der Pfad von 'which OmniSharp' führt zum Skript; für die DLL müssen wir den Pfad anpassen
    local omnisharp_dll = omnisharp_path:gsub("/bin/OmniSharp$", "/lib/omnisharp-roslyn/OmniSharp.dll")
    
    servers.omnisharp = {
        cmd = { "dotnet", omnisharp_dll },
    }



	
	-- servers.omnisharp = {
	-- 	cmd = { "dotnet", "/path/to/omnisharp/OmniSharp.dll" },
	-- }
	-- servers.csharp_ls = {}
end

if nixCats('react') then
	servers.ts_ls = {}
	servers.cssls = {}
	servers.html = {}

	servers.eslint = {
		settings = {
			experimental = {
				useFlatConfig = false
			},
			format = false,
		}
	}
end



if not require('nixCatsUtils').isNixCats and nixCats('lspDebugMode') then
	vim.lsp.set_log_level("debug")
end

require('lze').load {
	{
		"nvim-lspconfig",
		for_cat = "general.always",
		event = "FileType",
		load = (require('nixCatsUtils').isNixCats and vim.cmd.packadd) or function(name)
			vim.cmd.packadd(name)
			vim.cmd.packadd("mason.nvim")
			vim.cmd.packadd("mason-lspconfig.nvim")
		end,
		after = function(plugin)
			if require('nixCatsUtils').isNixCats then
				for server_name, cfg in pairs(servers) do
					local server_config = {
						on_attach = require('myLuaConf.LSPs.caps-on_attach').on_attach
					}
					-- If cfg exists, use its values
					if cfg then
						-- Merge cfg into server_config
						for k, v in pairs(cfg) do
							server_config[k] = v
						end
					end
					-- Ensure capabilities is set properly
					if not server_config.capabilities then
						server_config.capabilities = require('myLuaConf.LSPs.caps-on_attach').get_capabilities(
							server_name)
					end
					-- Setup the LSP
					require('lspconfig')[server_name].setup(server_config)
				end

				-- for server_name, cfg in pairs(servers) do
				-- 	require('lspconfig')[server_name].setup({
				-- 		-- capabilities = require('myLuaConf.LSPs.caps-on_attach').get_capabilities(server_name),
				-- 		capabilities = (cfg and cfg.capabilities) or
				-- 		require('myLuaConf.LSPs.caps-on_attach').get_capabilities(server_name),
				-- 		on_attach = require('myLuaConf.LSPs.caps-on_attach').on_attach,
				-- 		settings = (cfg or {}).settings,
				-- 		filetypes = (cfg or {}).filetypes,
				-- 		cmd = (cfg or {}).cmd,
				-- 		root_pattern = (cfg or {}).root_pattern,
				-- 	})
				-- end
			else
				require('mason').setup()
				local mason_lspconfig = require 'mason-lspconfig'
				mason_lspconfig.setup {
					ensure_installed = vim.tbl_keys(servers),
				}
				mason_lspconfig.setup_handlers {
					function(server_name)
						require('lspconfig')[server_name].setup {
							capabilities = require('myLuaConf.LSPs.caps-on_attach').get_capabilities(server_name),
							on_attach = require('myLuaConf.LSPs.caps-on_attach').on_attach,
							settings = (servers[server_name] or {}).settings,
							filetypes = (servers[server_name] or {}).filetypes,
						}
					end,
				}
			end
		end,
	}
}
