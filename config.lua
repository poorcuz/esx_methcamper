Config = Config or {}

Config = {
    InteriorCoords = vector4(1973.0997, 3815.9922, 33.4287, 24.6931),
    BeakerCoords = vector3(1976.120, 3819.045, 33.426),
    Buckets = {
        Min = 800,
        Max = 900
    },

    StationItem = "kochstation",
    MixRecipe = {
        {
            type = "item_standard",
            name = "pseudo",
            count = 0,
            label = "Pseudoephedrin (Zutat)"
        },
        {
            type = "item_standard",
            name = "destillierteswasser",
            count = 0,
            label = "Destilliertes Wasser (Zutat)"
        },
        {
            type = "item_standard",
            name = "roterphosphor",
            count = 0,
            label = "Roter Phosphor (Zutat)"
        }
    },

    Mix = {
        requiredEach = 1,
        outputItem = "meth",
        outputAmount = 1,
        processTime = 10000,
    },

    Keys = {
        toggleLock = {
            key = "G",
            label = "Camper verriegeln/entriegeln"
        }
    },

    Lang = {
        error = {
            no_buckets = "Keine verfügbaren Dimensionen für diesen Camper. Bitte versuche es später erneut.",
            already_in_camper = "Du bist bereits in einem Camper",
            player_not_found = "Spieler nicht gefunden für ID: %s",
            inventory_failed = "Fehler beim Abrufen des Inventars für Camper %s",
            missing_item = "Fehlender Gegenstand: %s",
            wrong_camper = "Spieler %s versuchte, in falschem Camper zu handeln",
            no_beaker = "Kein Becher in Camper %s platziert",
            already_cooking = "Es wird bereits gekocht!",
            beaker_already_placed = "Es ist bereits ein Becher platziert oder jemand platziert gerade einen.",
            no_station = "Du hast keine Kochstation."
        },
        success = {
            cooking_stopped = "Der Kochvorgang wurde beendet!",
            beaker_placed = "Du hast den Becher platziert.",
            beaker_picked_up = "Du hast den Becher aufgehoben.",
            camper_locked = "Du hast den Camper abgeschlossen.",
            camper_unlocked = "Du hast den Camper aufgeschlossen."
        },
        help = {
            enter_camper = "Drücke E um den Camper zu betreten",
            leave_camper = "Drücke E um den Camper zu verlassen",
            cooking_menu = "Drücke E um auf das Kochmenu zuzugreifen"
        },
        keys = {
            toggle_lock = "Camper verriegeln/entriegeln"
        }
    },

    functions = {
        SendHelpNotification = function(message)
            exports["bc_hud"]:sendPress(message)
        end
    }
}