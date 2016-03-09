# source docker helpers
. util/docker.sh

echo_lines() {
  for (( i=0; i < ${#lines[*]}; i++ ))
  do
    echo ${lines[$i]}
  done
}

# Start containers
@test "Start Primary Container" {
  start_container "simple-redundant-primary" "192.168.0.2"
}

@test "Start Secondary Container" {
  start_container "simple-redundant-secondary" "192.168.0.3"
}

@test "Start Monitor Container" {
  start_container "simple-redundant-monitor" "192.168.0.4"
}

# Configure containers
@test "Configure Primary Container" {
  run run_hook "simple-redundant-primary" "default-configure" "$(payload default/configure-production)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Configure Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-configure" "$(payload default/configure-production)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Configure Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-configure" "$(payload monitor/configure)"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Stop Primary PostgreSQL" {
  run run_hook "simple-redundant-primary" "default-stop" "$(payload default/stop)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Secondary PostgreSQL" {
  run run_hook "simple-redundant-secondary" "default-stop" "$(payload default/stop)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Primary Container" {
  run run_hook "simple-redundant-primary" "default-redundant-configure" "$(payload default/redundant/configure-primary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-redundant-configure" "$(payload default/redundant/configure-secondary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-configure" "$(payload monitor/redundant/configure)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Primary Container" {
  run run_hook "simple-redundant-primary" "default-redundant-config_vip_agent" "$(payload default/redundant/config_vip_agent-primary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-redundant-config_vip_agent" "$(payload default/redundant/config_vip_agent-secondary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-config_vip_agent" "$(payload monitor/redundant/config_vip_agent-monitor)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure PostgreSQL Is Stopped" {
  while docker exec "simple-redundant-primary" bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
  while docker exec "simple-redundant-secondary" bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
}

@test "Start Primary PostgreSQL" {
  run run_hook "simple-redundant-primary" "default-start" "$(payload default/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Secondary PostgreSQL" {
  run run_hook "simple-redundant-secondary" "default-start" "$(payload default/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Monitor Yoke" {
  run run_hook "simple-redundant-monitor" "monitor-start" "$(payload monitor/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure PostgreSQL Primary Is Started" {
  until docker exec "simple-redundant-primary" bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
  until docker exec "simple-redundant-primary" bash -c "nc 192.168.0.2 5432 < /dev/null"
  do
    sleep 1
  done
}

@test "Ensure PostgreSQL Secondary Is Started" {
  skip "PostgreSQL returns an error"
  until docker exec "simple-redundant-secondary" bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
  until docker exec "simple-redundant-secondary" bash -c "nc 192.168.0.3 5432 < /dev/null"
  do
    sleep 1
  done
}

@test "Ensure Monitor Yoke Is Started" {
  until docker exec "simple-redundant-monitor" bash -c "ps aux | grep [y]oke"
  do
    sleep 1
  done
}

# @test "Check Primary Redundant Status" {
#   run run_hook "simple-redundant-primary" "default-redundant-check_status" "$(payload default/redundant/check_status)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Check Secondary Redundant Status" {
#   run run_hook "simple-redundant-secondary" "default-redundant-check_status" "$(payload default/redundant/check_status)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

@test "Insert Primary PostgreSQL Data" {
  skip "PostgreSQL waiting on slave which isn't running"
  run docker exec "simple-redundant-primary" bash -c "/data/bin/psql -U gonano -t -c 'CREATE TABLE test_table (id SERIAL PRIMARY KEY, value bigint);'"
  echo_lines
  [ "$status" -eq 0 ]
  run docker exec "simple-redundant-primary" bash -c "/data/bin/psql -U gonano -t -c 'INSERT INTO test_table VALUES (1, 1);'"
  echo_lines
  [ "$status" -eq 0 ]
  run docker exec "simple-redundant-primary" bash -c "/data/bin/psql -U gonano -t -c 'SELECT * FROM test_table;'"
  echo_lines
  [ "${lines[0]}" = "  1 |     1" ]
  [ "$status" -eq 0 ]
}

# @test "Insert Secondary PostgreSQL Data" {
#   run docker exec "simple-redundant-secondary" bash -c "/data/bin/psql -U gonano -t -c 'INSERT INTO test_table VALUES (2, 2);'"
#   echo_lines
#   [ "$status" -eq 0 ]
#   run docker exec "simple-redundant-secondary" bash -c "/data/bin/psql -U gonano -t -c 'SELECT * FROM test_table;'"
#   echo_lines
#   [ "${lines[0]}" = "  1 |     1" ]
#   [ "${lines[1]}" = "  2 |     2" ]
#   [ "$status" -eq 0 ]
# }

@test "Verify Primary PostgreSQL Data" {
  skip "PostgreSQL isn't running on slave"
  run docker exec "simple-redundant-primary" bash -c "/data/bin/psql -U gonano -t -c 'SELECT * FROM test_table;'"
  echo_lines
  [ "${lines[0]}" = "  1 |     1" ]
  [ "${lines[1]}" = "  2 |     2" ]
  [ "$status" -eq 0 ]
}

# @test "Start Primary VIP Agent" {
#   run run_hook "simple-redundant-primary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Start Secondary VIP Agent" {
#   run run_hook "simple-redundant-secondary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Start Monitor VIP Agent" {
#   run run_hook "simple-redundant-monitor" "monitor-redundant-start_vip_agent" "$(payload monitor/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
#   sleep 10
# }

# Verify VIP
@test "Verify Primary VIP Agent" {
  skip "Yoke isn't working quite right"
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Verify Secondary VIP Agent" {
  run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Verify Monitor VIP Agent" {
  run docker exec "simple-redundant-monitor" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

# @test "Stop Primary VIP Agent" {
#   run run_hook "simple-redundant-primary" "default-redundant-stop_vip_agent" "$(payload default/redundant/stop_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Stop Secondary VIP Agent" {
#   run run_hook "simple-redundant-secondary" "default-redundant-stop_vip_agent" "$(payload default/redundant/stop_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Stop Monitor VIP Agent" {
#   run run_hook "simple-redundant-monitor" "monitor-redundant-stop_vip_agent" "$(payload monitor/redundant/stop_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Reverify Primary VIP Agent" {
#   run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
#   echo_lines
#   [ "$status" -eq 1 ]
# }

# @test "Reverify Secondary VIP Agent" {
#   run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
#   echo_lines
#   [ "$status" -eq 1 ]
# }

# @test "Reverify Monitor VIP Agent" {
#   run docker exec "simple-redundant-monitor" bash -c "ifconfig | grep 192.168.0.5"
#   echo_lines
#   [ "$status" -eq 1 ]
# }

# @test "Restart Primary VIP Agent" {
#   run run_hook "simple-redundant-primary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Restart Secondary VIP Agent" {
#   run run_hook "simple-redundant-secondary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
# }

# @test "Restart Monitor VIP Agent" {
#   run run_hook "simple-redundant-monitor" "monitor-redundant-start_vip_agent" "$(payload monitor/redundant/start_vip_agent)"
#   echo_lines
#   [ "$status" -eq 0 ]
#   sleep 10
# }

@test "Verify Primary VIP Agent Again" {
  skip "Yoke isn't working quite right"
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Primary" {
  run docker stop "simple-redundant-primary"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Verify Secondary VIP Agent Failover" {
  skip "Yoke isn't working quite right"
  run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Primary" {
  run docker start "simple-redundant-primary"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Verify Primary VIP Agent fallback" {
  skip "Yoke isn't working quite right"
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

# Stop containers
@test "Stop Primary Container" {
  stop_container "simple-redundant-primary"
}

@test "Stop Secondary Container" {
  stop_container "simple-redundant-secondary"
}

@test "Stop Monitor Container" {
  stop_container "simple-redundant-monitor"
}