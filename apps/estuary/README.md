# Estuary

This application is used to persist events from the eventstream kafka topic of the smartcities data platform to the presto database.

A list of events that can be found on the eventstream topic and their respective definitions can be found at https://github.com/Datastillery/smart_city/blob/master/lib/smart_city/event.ex.

### Setup

  * Run `mix deps.get` to install dependencies

### To run locally:
  * To startup external dependancies in docker:
    ```bash
    `MIX_ENV=integration mix docker.start`
    ```
  * To run a single instance with no data in it:
    ```bash
    `MIX_ENV=integration iex -S mix phx.start`
    ```
  * To kill the docker:
    ```bash
    `MIX_ENV=integration mix docker.kill`
    ```

  It will be started in port `http:\\localhost:4010`

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests