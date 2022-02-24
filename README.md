# ExBanking

**The application has been written using OTP v24.0.3 and Elixir v1.12.2-otp-24.**

## Notes for the implementation

The supervision tree is composed of 3 main modules
1) A Registry responsible for registering workers for each user
2) A Registry responsible for the records of buckets for each user
3) A DynamicSupervisor with will always be active creating and managing user workers

Creating a user starts a worker (Task.Supervisor) under the DynamicSupervisor that will be responsible for creating the processes per operation (get_balance, deposit, withdraw, send) and has a limit of 10 child processes.
Also when creating the user, a bucket (Agent) is started that will store the user's data in the following format:

``` elixir
%{
  "#{currency}" => %{
    current_balance: Float,
    changes: %{
      "#{PID}" => %{
        status: :ok | :not_enough_money | :sender_unavailable,
        balance: Float (the balance at the time of the operation)
      }
    }
  }
}
```

User actions (deposit, withdraw, get_balance, send) call the respective worker of that user which starts a process (Task) independent for each action that was called. Each process will access the same bucket and change it according to the above format, storing the "pid" of the process and informing the operation status and user balance as a result of the operation.