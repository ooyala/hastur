require "hastur/api"
Hastur.register_process Hastur.app_name, {}
Hastur.no_background_thread!

# Sinatra-Synchrony 0.4.1 has a bug where UDP lookup of
# a numeric address can cause double-resume errors.
Hastur.udp_address = "localhost"
