# Noita API wrapper

This wraps the Noita API and exposes it in a more dev friendly way.
Entities and components are returned as objects. All entity and component related functions are now methods of the respective objects.

The library also comes with EmmyLua annotations, so code completion, type information and other hints will work in any IDE or editor that supports this.
(Only tested with VSCode for now)

## State

Working but incomplete.
If something is missing, you need to add it!

It would be nice to have code generation to generate this library from the official files, but meh.
But this would be too complex, as there are a lot of edge cases and stuff that has to be handled in a specific way.

## Usage

1. Copy this library into your mod so you get the following file path: `mods/your-mod/files/libraries/noita-api/README.md`.
2. Add the following at the beginning of your mod's `init.lua`:

    ```lua
    -- Emulate and override some functions and tables to make everything conform more to standard lua.
    -- This will make `require` work, even in sandboxes with restricted Noita API.
    local libPath = "mods/noita-mapcap/files/libraries/"
    dofile(libPath .. "noita-api/compatibility.lua")(libPath)
    ```

    You need to adjust `libPath` to point into your mod's library directory.
    The trailing `/` is needed!

After that you can import and use the library like this:

```lua
local EntityAPI = require("noita-api.entity")

local x, y, radius = 10, 10, 100

local entities = EntityAPI.GetInRadius(x, y, radius)
for _, entity in ipairs(entities) do
    print(entity:GetName())

    local components = entity:GetComponents("VelocityComponent")
    for _, component in ipairs(components) do
        entity:SetComponentsEnabled(component, false)
    end
end
```

To include the whole set of API commands, use:

```lua
local NoitaAPI = require("noita-api")
```
