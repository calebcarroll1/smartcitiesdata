use Mix.Config
aws_region = "local"
System.put_env("AWS_ACCESS_KEY_ID", "testing_access_key")
System.put_env("AWS_ACCESS_KEY_SECRET", "testing_secret_key")
host = "localhost"
endpoints = [{to_charlist(host), 9092}]
redix_args = [host: host]

config :discovery_api, DiscoveryApiWeb.Endpoint,
  url: [scheme: "https", host: "data.integrationtests.example.com", port: 443],
  http: [protocol_options: [inactivity_timeout: 4_000_000, idle_timeout: 4_000_000]]

config :discovery_api,
  allowed_origins: ["integrationtests.example.com", "localhost:9001"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35],
  hosted_bucket: "kdp-cloud-storage",
  hosted_region: aws_region,
  hsts_enabled: false

config :redix,
  args: redix_args

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :prestige, :session_opts, url: "http://#{host}:8080"

config :ex_aws, :s3,
  scheme: "http://",
  region: aws_region,
  host: %{
    "local" => "localhost"
  },
  port: 9000

config :discovery_api, :elasticsearch,
  url: "http://#{host}:9200",
  indices: %{
    datasets: %{
      name: "datasets",
      options: %{
        settings: %{
          number_of_shards: 1
        },
        mappings: %{
          properties: %{
            title: %{
              type: "text",
              index: true
            },
            titleKeyword: %{
              type: "keyword",
              index: true
            },
            modifiedDate: %{
              type: "text",
              index: true
            },
            lastUpdatedDate: %{
              type: "text",
              index: true
            },
            sortDate: %{
              type: "date",
              index: true
            },
            keywords: %{
              type: "text",
              index: true
            },
            organizationDetails: %{
              properties: %{
                id: %{
                  type: "keyword",
                  index: true
                }
              }
            },
            facets: %{
              properties: %{
                orgTitle: %{
                  type: "keyword",
                  index: true
                },
                keywords: %{
                  type: "keyword",
                  index: true
                }
              }
            }
          }
        }
      }
    }
  }

config :discovery_api, ecto_repos: [DiscoveryApi.Repo]

config :discovery_api, DiscoveryApi.Repo,
  database: "discovery_api_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: "5456"

config :discovery_api, DiscoveryApiWeb.Auth.TokenHandler,
  issuer: "https://smartcolumbusos-demo.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :discovery_api, Guardian.DB, repo: DiscoveryApi.Repo

config :discovery_api, :brook,
  instance: :discovery_api,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "discovery-api-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [DiscoveryApi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "discovery-api:view"]
  ]

config :discovery_api,
  user_visualization_limit: 4
