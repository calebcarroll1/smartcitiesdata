use Mix.Config

config :reaper,
  produce_retries: 10,
  produce_timeout: 100,
  vault_http_options: []

import_config "#{Mix.env()}.exs"
