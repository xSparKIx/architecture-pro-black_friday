#!/bin/bash

###
# Инициализируем бд
###

# Config server
docker compose exec -T config1 mongosh --port 27017 --quiet <<EOF
try {
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
      { _id: 0, host: "config1:27017" },
      { _id: 1, host: "config2:27017" },
      { _id: 2, host: "config3:27017" }
    ]
  });
} catch (e) {
  if (e.codeName !== 'AlreadyInitialized') {
    throw e;
  }
  print("Config server already initialized");
}
EOF

until docker compose exec -T config1 mongosh --quiet --port 27017 --eval "db.hello().isWritablePrimary" | grep true; do sleep 2; done

# Shard1
docker compose exec -T shard1_a mongosh --port 27018 --quiet <<EOF
try {
  rs.initiate({
    _id: "shard1",
    members: [
      { _id: 0, host: "shard1_a:27018" },
      { _id: 1, host: "shard1_b:27018" },
      { _id: 2, host: "shard1_c:27018" }
    ]
  });
} catch (e) {
  if (e.codeName !== 'AlreadyInitialized') {
    throw e;
  }
  print("Shard1 already initialized");
}
EOF

until docker compose exec -T shard1_a mongosh --quiet --port 27018 --eval "db.hello().isWritablePrimary" | grep true; do sleep 2; done

# Shard2
docker compose exec -T shard2_a mongosh --port 27019 --quiet <<EOF
try {
  rs.initiate({
    _id: "shard2",
    members: [
      { _id: 0, host: "shard2_a:27019" },
      { _id: 1, host: "shard2_b:27019" },
      { _id: 2, host: "shard2_c:27019" },
    ]
  });
} catch (e) {
  if (e.codeName !== 'AlreadyInitialized') {
    throw e;
  }
  print("Shard2 already initialized");
}
EOF

until docker compose exec -T shard2_a mongosh --quiet --port 27019 --eval "db.hello().isWritablePrimary" | grep true; do sleep 2; done

# Shard3
docker compose exec -T shard3_a mongosh --port 27020 --quiet <<EOF
try {
  rs.initiate({
    _id: "shard3",
    members: [
      { _id: 0, host: "shard3_a:27020" },
      { _id: 1, host: "shard3_b:27020" },
      { _id: 2, host: "shard3_c:27020" }
    ]
  });
} catch (e) {
  if (e.codeName !== 'AlreadyInitialized') {
    throw e;
  }
  print("Shard3 already initialized");
}
EOF

until docker compose exec -T shard3_a mongosh --quiet --port 27020 --eval "db.hello().isWritablePrimary" | grep true; do sleep 2; done


# Даем время на полную инициализацию
sleep 10

# Добавляем шарды через mongos
docker compose exec -T mongos_router mongosh --port 27021 --quiet <<EOF
// Добавляем шарды с проверкой
try {
  sh.addShard("shard1/shard1_a:27018,shard1_b:27018,shard1_c:27018");
} catch (e) {
  print("Shard1 might be already added: " + e);
}

try {
  sh.addShard("shard2/shard2_a:27019,shard2_b:27019,shard2_c:27019");
} catch (e) {
  print("Shard2 might be already added: " + e);
}

try {
  sh.addShard("shard3/shard3_a:27020,shard3_b:27020,shard3_c:27020");
} catch (e) {
  print("Shard3 might be already added: " + e);
}

// Включаем шардирование для базы данных
sh.enableSharding("somedb");

// Создаем коллекцию и шардируем ее
db.adminCommand({
  shardCollection: "somedb.helloDoc",
  key: { "name": "hashed" }
});

// Тестовые данные
use somedb

try {
  for(var i = 0; i < 1000; i++) {
    db.helloDoc.insert({age: i, name: "ly" + i});
  }
  print("Inserted " + db.helloDoc.countDocuments() + " documents");
} catch (e) {
  print("Insert error: " + e);
}

// Проверяем распределение
try {
  db.helloDoc.getShardDistribution();
} catch (e) {
  print("Distribution check error: " + e);
}
EOF