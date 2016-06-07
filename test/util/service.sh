
service_name="PostgreSQL"
default_port=5432
multi_master="false"

wait_for_running() {
  container=$1
  until docker exec ${container} bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
}

wait_for_arbitrator_running() {
  container=$1
  until docker exec ${container} bash -c "ps aux | grep [y]oke"
  do
    sleep 1
  done
}

wait_for_listening() {
  container=$1
  ip=$2
  port=$3
  until docker exec ${container} bash -c "nc -q 1 ${ip} ${port} < /dev/null"
  do
    sleep 1
  done
}

wait_for_stop() {
  container=$1
  while docker exec ${container} bash -c "ps aux | grep [p]ostgres"
  do
    sleep 1
  done
}

verify_stopped() {
  container=$1
  run docker exec ${container} bash -c "ps aux | grep [p]ostgres"
  echo_lines
  [ "$status" -eq 1 ]
}

insert_test_data() {
  container=$1
  ip=$2
  port=$3
  key=$4
  data=$5
  run docker exec ${container} bash -c "/data/bin/psql -U gonano -t -c 'CREATE TABLE IF NOT EXISTS test_table (id text, value text);'"
  echo_lines
  [ "$status" -eq 0 ]
  run docker exec ${container} bash -c "/data/bin/psql -U gonano -t -c 'INSERT INTO test_table VALUES ('\"'\"'${key}'\"'\"', '\"'\"'${data}'\"'\"');'"
  echo_lines
  [ "$status" -eq 0 ]
}

update_test_data() {
  container=$1
  ip=$2
  port=$3
  key=$4
  data=$5
  run docker exec ${container} bash -c "/data/bin/psql -U gonano -t -c 'UPDATE test_table SET value = '\"'\"'${data}'\"'\"' WHERE id = '\"'\"'${key}'\"'\"';'"
  echo_lines
  [ "$status" -eq 0 ]

}

verify_test_data() {
  container=$1
  ip=$2
  port=$3
  key=$4
  data=$5
  run docker exec ${container} bash -c "/data/bin/psql -U gonano -t -c 'SELECT value FROM test_table WHERE id = '\"'\"'${key}'\"'\"';'"
  echo_lines
  count=$(echo ${lines[0]} | grep -c "$data")
  [ $count -eq 1 ]
  [ "$status" -eq 0 ]
}

verify_plan() {
  [ "${lines[0]}"  = "{" ]
  [ "${lines[1]}"  = "  \"redundant\": true," ]
  [ "${lines[2]}"  = "  \"horizontal\": false," ]
  [ "${lines[3]}"  = "  \"user\": \"nanobox\"" ]
  [ "${lines[4]}"  = "  \"users\": [" ]
  [ "${lines[5]}"  = "    {" ]
  [ "${lines[6]}"  = "      \"username\": \"nanobox\"," ]
  [ "${lines[7]}"  = "      \"meta\": {" ]
  [ "${lines[8]}"  = "        \"privileges\": [" ]
  [ "${lines[9]}"  = "          {" ]
  [ "${lines[10]}"  = "            \"privilege\": \"ALL PRIVILEGES\"," ]
  [ "${lines[11]}" = "            \"type\": \"DATABASE\"," ]
  [ "${lines[12]}" = "            \"column\": null," ]
  [ "${lines[13]}" = "            \"on\": \"gonano\"," ]
  [ "${lines[14]}" = "            \"with_grant\": true" ]
  [ "${lines[15]}" = "          }" ]
  [ "${lines[16]}" = "        ]," ]
  [ "${lines[17]}" = "        \"roles\": [" ]
  [ "${lines[18]}" = "          \"SUPERUSER\"" ]
  [ "${lines[19]}" = "        ]" ]
  [ "${lines[20]}" = "      }" ]
  [ "${lines[21]}" = "    }" ]
  [ "${lines[22]}" = "  ]," ]
  [ "${lines[23]}" = "  \"ips\": [" ]
  [ "${lines[24]}" = "    \"default\"" ]
  [ "${lines[25]}" = "  ]," ]
  [ "${lines[26]}" = "  \"port\": 6379," ]
  [ "${lines[27]}" = "  \"behaviors\": [" ]
  [ "${lines[28]}" = "    \"migratable\"," ]
  [ "${lines[29]}" = "    \"backupable\"" ]
  [ "${lines[30]}" = "  ]" ]
  [ "${lines[31]}" = "}" ]
}
