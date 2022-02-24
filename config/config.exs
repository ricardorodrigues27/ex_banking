use Mix.Config

config :ex_banking,
  workers_supervisor: ExBanking.UserWorkersSupervisor,
  worker_registry: ExBanking.UserWorkerRegistry,
  bucket_registry: ExBanking.UserBucketRegistry

import_config "#{Mix.env()}.exs"
