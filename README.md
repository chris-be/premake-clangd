# Premake-clangd-config Module
"Premake" module that generates *config files* for [clangd](https://clangd.llvm.org/).  

## Features
The idea is to separate `compilation flags` and `compilation database`.
- generate `clangd_config.yaml` with common compilation options
- generate one `compile_commands.json` per project

## Usage (little reminder)
1. Put these files in a "clangd-config" subdirectory of [Premake search paths](https://premake.github.io/docs/Locating-Scripts/).  

2. Adapt your premake5.lua script, or better: create/adapt your [premake-system.lua](https://premake.github.io/docs/System-Scripts/)

```lua
require "clangd-config"
```

3. Generation option
- `--clangd-config-yaml`: generate the `clang.yaml` file (default `false`)
- `--clangd-config-json`: generate a simple `compile_commands.json` for each project (default `true`)

```sh
# Help
premake5 --help
# Generate with defaults
premake5 clangd-config
# Or
premake5 clangd-config --clangd-config-yaml=false --clangd-config-json=true
```

4. Adjust ".clangd":  
Copy or move the "clangd_config.yaml" into ".clangd" if you generated it and adapt it.

Activate (uncomment) "CompilationDatabase":
- either for desired projects
- or globally (Configuration) and adapt path for a "common" compilation file (a command using `jq` to merge the files can be found at the end)

# Note
If you are interested in a similar project, you may try [*premake-export-compile-commands*](https://github.com/tarruda/premake-export-compile-commands).

## Tested on
<table>
<tr>
	<th>OS (Platform) - Date</th>	<th>Premake</th>	<th>clangd Version</th>
</tr>
<tr>
	<td>Alpine Linux (x64) - March 2025</td>	<td>5.0.0-beta3</td>	<td>19.1.7</td>
</tr>
</table>

