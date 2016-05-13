
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
  [ "${lines[3]}"  = "  \"users\": [" ]
  [ "${lines[4]}"  = "    {" ]
  [ "${lines[5]}"  = "      \"username\": \"nanobox\"," ]
  [ "${lines[6]}"  = "      \"meta\": {" ]
  [ "${lines[7]}"  = "        \"privileges\": [" ]
  [ "${lines[8]}"  = "          {" ]
  [ "${lines[9]}"  = "            \"privilege\": \"ALL PRIVILEGES\"," ]
  [ "${lines[10]}" = "            \"type\": \"DATABASE\"," ]
  [ "${lines[11]}" = "            \"column\": null," ]
  [ "${lines[12]}" = "            \"on\": \"gonano\"," ]
  [ "${lines[13]}" = "            \"with_grant\": true" ]
  [ "${lines[14]}" = "          }" ]
  [ "${lines[15]}" = "        ]," ]
  [ "${lines[16]}" = "        \"roles\": [" ]
  [ "${lines[17]}" = "          \"SUPERUSER\"" ]
  [ "${lines[18]}" = "        ]" ]
  [ "${lines[19]}" = "      }" ]
  [ "${lines[20]}" = "    }" ]
  [ "${lines[21]}" = "  ]," ]
  [ "${lines[22]}" = "  \"ips\": [" ]
  [ "${lines[23]}" = "    \"default\"" ]
  [ "${lines[24]}" = "  ]," ]
  [ "${lines[25]}" = "  \"port\": 6379," ]
  [ "${lines[26]}" = "  \"behaviors\": [" ]
  [ "${lines[27]}" = "    \"migratable\"," ]
  [ "${lines[28]}" = "    \"backupable\"" ]
  [ "${lines[29]}" = "  ]" ]
  [ "${lines[30]}" = "}" ]
}