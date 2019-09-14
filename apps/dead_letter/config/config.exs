use Mix.Config

config :husky,
  pre_commit: "./scripts/git_pre_commit_hook.sh"

import_config "#{Mix.env()}.exs"
