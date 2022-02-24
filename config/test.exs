use Mix.Config

config :ex_banking,
  workers_supervisor: ExBanking.UserWorkersSupervisorTest,
  worker_registry: ExBanking.UserWorkerRegistryTest,
  bucket_registry: ExBanking.UserBucketRegistryTest
