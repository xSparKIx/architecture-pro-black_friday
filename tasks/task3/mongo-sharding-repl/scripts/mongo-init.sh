#!/bin/bash

###
# Инициализируем бд
###

# Инициализируем реплики конфигурации
docker compose exec -T config1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "config1:27017" },
      { _id : 1, host : "config2:27017" },
      { _id : 2, host : "config3:27017" }
    ]
  }
);
exit()
EOF

until docker compose exec -T config1 mongosh --quiet --port 27017 --eval "db.hello().isWritablePrimary" | grep true; do
  echo "Waiting for PRIMARY..."
  sleep 2
done

# Инициализируем реплики шарда 1
docker compose exec -T shard1_a mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1_a:27018" },
        { _id : 1, host : "shard1_b:27018" },
        { _id : 2, host : "shard1_c:27018" }
      ]
    }
);
exit()
EOF

# Инициализируем реплики шарда 2
docker compose exec -T shard2_a mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2_a:27018" },
        { _id : 1, host : "shard2_b:27018" },
        { _id : 2, host : "shard2_c:27018" }
      ]
    }
);
exit()
EOF

# Инициализируем реплики шарда 3
docker compose exec -T shard3_a mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard3",
      members: [
        { _id : 0, host : "shard3_a:27018" },
        { _id : 1, host : "shard3_b:27018" },
        { _id : 2, host : "shard3_c:27018" }
      ]
    }
);
exit()
EOF

# Инцициализируйте роутер и наполняем его тестовыми данными
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1_a:27018,shard1_b:27018,shard1_c:27018")
sh.addShard("shard2/shard2_a:27018,shard2_b:27018,shard2_c:27018")
sh.addShard("shard3/shard3_a:27018,shard3_b:27018,shard3_c:27018")

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments() 

db.helloDoc.getShardDistribution()
exit()
EOF