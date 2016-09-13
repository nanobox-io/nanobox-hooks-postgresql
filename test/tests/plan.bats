# source docker helpers
. util/docker.sh

@test "Start Container" {
  start_container "simple-single" "192.168.0.2"
}

@test "simple-single-plan" {
  run run_hook "simple-single" "plan" "$(payload plan)"
  [ "$status" -eq 0 ]

  echo "$output"

  expected=$(cat <<-END
{
  "redundant": false,
  "horizontal": false,
  "user": "nanobox",
  "users": [
    {
      "username": "nanobox",
      "meta": {
        "privileges": [
          {
            "privilege": "ALL PRIVILEGES",
            "type": "DATABASE",
            "column": null,
            "on": "gonano",
            "with_grant": true
          }
        ],
        "roles": [
          "SUPERUSER"
        ]
      }
    }
  ],
  "ips": [
    "default"
  ],
  "port": 5432,
  "behaviors": [
    "migratable",
    "backupable"
  ]
}
END
)

  [ "$output" = "$expected" ]
}

@test "Stop Container" {
  stop_container "simple-single"
}
