# For now, just don't start a background thread.
# Eventually we'll want a real EventMachine implementation.

require "hastur/api"
Hastur.register_process Hastur.app_name, {}
Hastur.no_background_thread!
