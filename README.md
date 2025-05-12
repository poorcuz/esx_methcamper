# ESX Meth Camper

A FiveM resource that allows players to use campers for cooking activities. Players can enter campers, place cooking stations, and manage their cooking process.

## Requirements

- ESX Framework
- chezza-inventory v3

## Dependencies

### ESX Framework
This resource requires ESX Framework to be installed and running on your server.

### chezza-inventory v3
This resource requires chezza-inventory v3 with the following exports:

```lua
exports("addItemToInventory", AddItemToInventory)
exports("removeItemFromInventory", RemoveItemFromInventory)
exports("getInventory", GetInventory)
```

## Installation

1. Ensure you have ESX Framework installed and configured
2. Install chezza-inventory v3 and add the required exports
3. Place `esx_methcamper` in your server's resources folder
4. Add `ensure esx_methcamper` to your server.cfg
5. Configure the resource in `config.lua` if needed

## Configuration

### Required Configuration

1. **Mixing Recipe**
   You need to adjust the `MixRecipe` in `config.lua` to match your server's items:
   ```lua
   MixRecipe = {
       {
           type = "item_standard",
           name = "your_item_name",
           count = 0,
           label = "Your Item Label"
       },
       -- Add more ingredients as needed
   }
   ```

2. **Help Notifications**
   The resource uses `Config.functions.SendHelpNotification` for displaying help text. You need to implement this function according to your server's notification system. For example:
   ```lua
   Config.functions = {
       SendHelpNotification = function(text)
           -- Implement your notification system here
           -- Example: exports["bc_hud"]:sendPress(text)
       end
   }
   ```

3. **Car Lock System**
   You need to modify the `ToggleCamperLock` function in `server.lua` to work with your server's car lock system. The current implementation uses `bc_car-tools`, but you should replace it with your own system:
   ```lua
   function ToggleCamperLock(plate, source)
       if not plate then return false end
       
       -- Replace this with your car lock system
       -- Example:
       local hasAccess = exports["your_car_system"]:hasVehicleKey(source, plate)
       if hasAccess then
           -- Your lock/unlock logic here
           return true
       end
       return false
   end
   ```

### Vehicle Model Limitation

Currently, this resource only works with the "journey" camper model.

### Optional Configuration

The resource can be further configured in `config.lua`:

- `InteriorCoords`: The coordinates for the camper interior
- `BeakerCoords`: The coordinates for placing the cooking station
- `Buckets`: The range of routing buckets for camper instances
- `StationItem`: The item required to place a cooking station
- `Mix`: Cooking process configuration
- `Lang`: All text strings used in the resource

## Features

- Enter/exit campers with proper dimension handling
- Place and remove cooking stations
- Cooking system with required ingredients
- Vehicle smoke effects during cooking
- Lock/unlock camper functionality
- Inventory integration for ingredients and output

## Usage

1. Approach a camper vehicle
2. Press E to enter if unlocked
3. Place a cooking station using the required item
4. Access the cooking menu to start/stop cooking
5. Manage ingredients through the inventory system

You can use the configured hotkey to toggle vehicle lock state.

## Support

For support, please contact the developer or create an issue in the repository.