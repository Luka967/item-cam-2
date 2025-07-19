require("script.events-persist")
require("script.events-tick")
require("script.events-input")
require("script.remote-interface")
require("remote") -- To register metatable

require("script.gui-custom").register_main_event_handlers()
require("script.gui.follow-rules").register_event_handlers()
require("script.gui.dialog").register_event_handlers()
