#!/bin/bash 
SCRIPTPATH=$HOME/.hex-cli

function local_database_init() {

    if [[ "$RUN_WITH_VERIFY" == true ]]; then

        echo "*** Are you sure you want to run database init jobs for your local $ENVIRONMENT_EXCHANGE_NAME db? (y/n) ***"

        read answer

      if [[ "$answer" = "${answer#[Yy]}" ]]; then
        echo "*** Exiting... ***"
        exit 0;
      fi

    fi
    
    if [[ "$1" == "start" ]]; then

      if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

        IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"

      fi

      echo "*** Running sequelize db:migrate ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:migrate

      echo "*** Running database triggers ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

      echo "*** Running sequelize db:seed:all ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:seed:all

      echo "*** Running InfluxDB migrations ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/createInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/migrateInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/initializeInflux.js


    elif [[ "$1" == 'upgrade' ]]; then

       if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

        IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"
        
      fi

      echo "*** Running sequelize db:migrate ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "*** Running database triggers ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "*** Running InfluxDB initialization ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js
    
    elif [[ "$1" == 'dev' ]]; then

      echo "*** Running sequelize db:migrate ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 sequelize db:migrate

      echo "*** Running database triggers ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/runTriggers.js

      echo "*** Running sequelize db:seed:all ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 sequelize db:seed:all

      echo "*** Running InfluxDB migrations ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/createInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/migrateInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/initializeInflux.js

    fi
}

function kubernetes_database_init() {

  # Checks the api container(s) get ready enough to run database upgrade jobs.
  while ! kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- echo "API is ready!" > /dev/null 2>&1;
      do echo "API container is not ready! Retrying..."
      sleep 10;
  done;

  echo "*** API container become ready to run Database initialization jobs! ***"
  sleep 10;

  if [[ "$1" == "launch" ]]; then

    echo "*** Running sequelize db:migrate ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "*** Running Database Triggers ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "*** Running sequelize db:seed:all ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:seed:all 

    echo "*** Running InfluxDB migrations ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/createInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/migrateInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js

  elif [[ "$1" == "upgrade" ]]; then

    echo "*** Running sequelize db:migrate ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "*** Running Database Triggers ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "*** Running InfluxDB migrations ***"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js

  fi

  echo "*** Restarting all containers to apply latest database changes... ***"
  kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

  echo "*** Waiting for the containers get fully ready... ***"
  sleep 30;

}

function local_code_test() {

    echo "*** Running mocha code test ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server-api_1 mocha --exit

    exit 0;
}

function check_kubernetes_dependencies() {

    # Checking kubectl and helm are installed on this machine.
    if command kubectl version > /dev/null 2>&1 && command helm version > /dev/null 2>&1; then

         echo "*** kubectl and helm detected ***"

    else

         echo "*** hex-cli failed to detect kubectl or helm installed on this machine. Please install it before running hex-cli. ***"
         exit 1;

    fi

}

 
function load_config_variables() {

  HEX_CONFIGMAP_VARIABLES=$(set -o posix ; set | grep "HEX_CONFIGMAP" | cut -c15-)
  HEX_SECRET_VARIABLES=$(set -o posix ; set | grep "HEX_SECRET" | cut -c12-)

  HEX_CONFIGMAP_VARIABLES_YAML=$(for value in ${HEX_CONFIGMAP_VARIABLES} 
  do 
      if [[ $value == *"'"* ]]; then
        printf "  ${value//=/: }\n";
      else
        printf "  ${value//=/: \'}'\n";
      fi

  done)

  HEX_SECRET_VARIABLES_BASE64=$(for value in ${HEX_SECRET_VARIABLES} 
  do
      printf "${value//$(cut -d "=" -f 2 <<< "$value")/$(cut -d "=" -f 2 <<< "$value" | tr -d '\n' | tr -d "'" | base64)} ";
  
  done)

  HEX_SECRET_VARIABLES_YAML=$(for value in ${HEX_SECRET_VARIABLES_BASE64} 
  do

      printf "  ${value/=/: }\n";

  done)

}

function generate_local_env() {

# Generate local env
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local <<EOL
DB_DIALECT=postgres

$(echo "$HEX_CONFIGMAP_VARIABLES" | tr -d '\'\')

$(echo "$HEX_SECRET_VARIABLES" | tr -d '\'\')
EOL

}

function generate_nginx_upstream() {
  
if [[ "$LOCAL_DEPLOYMENT_MODE" == "all" ]]; then 

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server:10010;
  }
  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server:10080;
  }
EOL

fi


#IFS=',' read -ra LOCAL_DEPLOYMENT_MODE <<< "$1"

if [[ "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ ! "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }
  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10080;
  }
EOL

elif [[ ! "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10010;
  }
  
  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10080;
  }
EOL

fi

if [[ "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

# Generate local nginx conf
cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }
  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10080;
  }
EOL

fi

}

function generate_nginx_config_for_plugin() {

  if [[ -f "$TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf" ]]; then

    rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
    touch $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
  
  fi
  
  IFS=',' read -ra PLUGINS <<< "$ENVIRONMENT_CUSTOM_PLUGINS_NAME"    #Convert string to array

  for i in "${PLUGINS[@]}"; do
    PLUGINS_UPSTREAM_NAME=$(echo $i | cut -f1 -d ",")

    CUSTOM_ENDPOINT=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_ENDPOINT_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_ENDPOINT_PORT=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_ENDPOINT_PORT_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_URL=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_URL_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_IS_WEBSOCKET=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_IS_WEBSOCKET_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")

    if [[ "$USE_KUBERNETES" ]]; then

      function websocket_upgrade() {
        if  [[ "$CUSTOM_IS_WEBSOCKET" == "true" ]]; then
          echo "nginx.org/websocket-services: '${CUSTOM_ENDPOINT}'"
        fi
      }

cat >> $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-${PLUGINS_UPSTREAM_NAME}
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    $(websocket_upgrade;)
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: ${CUSTOM_URL}
        backend:
          serviceName: ${CUSTOM_ENDPOINT}
          servicePort: ${CUSTOM_ENDPOINT_PORT}
          
tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}
EOL

    fi

    if [[ ! "$USE_KUBERNETES" ]]; then

      function websocket_upgrade() {
        if  [[ "$CUSTOM_IS_WEBSOCKET" == "true" ]]; then
          echo "proxy_http_version  1.1;
          proxy_set_header    Upgrade \$http_upgrade; 
          proxy_set_header    Connection \"upgrade\";"
        fi
      }
      
# Generate local nginx conf
cat >> $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

upstream $PLUGINS_UPSTREAM_NAME {
  server ${CUSTOM_ENDPOINT}:${CUSTOM_ENDPOINT_PORT};
}
EOL

cat >> $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf <<EOL
location ${CUSTOM_URL} {
  $(websocket_upgrade;)
  proxy_pass      http://$PLUGINS_UPSTREAM_NAME;
}

EOL
  
  fi

  done

}

function generate_local_docker_compose_for_dev() {

echo $HEX_CODEBASE_PATH
# Generate docker-compose
cat > $HEX_CODEBASE_PATH/.${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: redis:5.0.5-alpine
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HEX_SECRET_DB_NAME
      - POSTGRES_USER=$HEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HEX_SECRET_INFLUX_PASSWORD
      - INFLUXDB_HTTP_LOG_ENABLED=false
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=false
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=false
      - INFLUXDB_LOGGING_LEVEL=error
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-server:
    image: ${ENVIRONMENT_EXCHANGE_NAME}-server-pm2
    build:
      context: .
      dockerfile: ${HEX_CODEBASE_PATH}/tools/Dockerfile.pm2
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HEX_CODEBASE_PATH}/api:/app/api
      - ${HEX_CODEBASE_PATH}/config:/app/config
      - ${HEX_CODEBASE_PATH}/db:/app/db
      - ${HEX_CODEBASE_PATH}/mail:/app/mail
      - ${HEX_CODEBASE_PATH}/queue:/app/queue
      - ${HEX_CODEBASE_PATH}/ws:/app/ws
      - ${HEX_CODEBASE_PATH}/app.js:/app/app.js
      - ${HEX_CODEBASE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HEX_CODEBASE_PATH}/constants.js:/app/constants.js
      - ${HEX_CODEBASE_PATH}/messages.js:/app/messages.js
      - ${HEX_CODEBASE_PATH}/logs:/app/logs
      - ${HEX_CODEBASE_PATH}/test:/app/test
      - ${HEX_CODEBASE_PATH}/tools:/app/tools
      - ${HEX_CODEBASE_PATH}/utils:/app/utils
      - ${HEX_CODEBASE_PATH}/init.js:/app/init.js
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ${TEMPLATE_GENERATE_PATH}/nginx:/etc/nginx
      - ${TEMPLATE_GENERATE_PATH}/local/nginx/conf.d:/etc/nginx/conf.d
      - ${TEMPLATE_GENERATE_PATH}/local/logs/nginx:/var/log
      - ${TEMPLATE_GENERATE_PATH}/nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:

EOL

}


function generate_local_docker_compose() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
EOL

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" == "true" ]]; then 

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: redis:5.0.5-alpine
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL
fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HEX_SECRET_DB_NAME
      - POSTGRES_USER=$HEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HEX_SECRET_INFLUX_PASSWORD
      - INFLUXDB_HTTP_LOG_ENABLED=false
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=false
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=false
      - INFLUXDB_LOGGING_LEVEL=error
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL
fi 

if [[ "$1" == "all" ]]; then

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-server:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log
      - ./nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL


elif [[ "$1" == "all" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" == "true" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]] ; then

 # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-server:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log
      - ./nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

else

#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE"

  for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
      - --only
      - ${i}
EOL

  if [[ "$i" == "api" ]]; then
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10010:10010
EOL

  elif [[ "$i" == "ws" ]]; then

  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10080:10080
EOL

  fi
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

done

fi

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:
  
EOL

}

function generate_kubernetes_configmap() {

# Generate Kubernetes Configmap
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-configmap.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-env
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  DB_DIALECT: postgres
${HEX_CONFIGMAP_VARIABLES_YAML}
EOL

}

function generate_kubernetes_secret() {

# Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-secret.yaml <<EOL
apiVersion: v1
kind: Secret
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-secret
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
type: Opaque
data:
${HEX_SECRET_VARIABLES_YAML}
EOL
}

function generate_kubernetes_ingress() {

# Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=5 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=order burst=3 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/order
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/admin
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-ws
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.org/websocket-services: "${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}-server-ws"
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-ws
          servicePort: 10080
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}
EOL

}

function generate_random_values() {

  python -c "import os; print os.urandom(16).encode('hex')"

}

function update_random_values_to_config() {


GENERATE_VALUES_LIST=( "HEX_SECRET_ADMIN_PASSWORD" "HEX_SECRET_SUPERVISOR_PASSWORD" "HEX_SECRET_SUPPORT_PASSWORD" "HEX_SECRET_KYC_PASSWORD" "HEX_SECRET_QUICK_TRADE_SECRET" "HEX_SECRET_API_KEYS" "HEX_SECRET_SECRET" )

for j in ${CONFIG_FILE_PATH[@]}; do

  if command grep -q "HEX_SECRET" $j > /dev/null ; then

    SECRET_CONFIG_FILE_PATH=$j

    if [[ ! -z "$HEX_SECRET_ADMIN_PASSWORD" ]] ; then
  
      echo "*** Pre-generated secrets are detected on your secert file! ***"
      echo "Are you sure you want to override them? (y/n)"

      read answer

      if [[ "$answer" == "${answer#[Nn]}" ]]; then

        for k in ${GENERATE_VALUES_LIST[@]}; do

          grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

          # Using special form to generate both API_KEYS keys and secret
          if [[ "$k" == "HEX_SECRET_API_KEYS" ]]; then

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values):$(generate_random_values)
EOL

          else 

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

          fi
        
        done

        unset k
        unset GENERATE_VALUES_LIST
        unset HEX_CONFIGMAP_VARIABLES
        unset HEX_SECRET_VARIABLES
        unset HEX_SECRET_VARIABLES_BASE64
        unset HEX_SECRET_VARIABLES_YAML
        unset HEX_CONFIGMAP_VARIABLES_YAML

        for i in ${CONFIG_FILE_PATH[@]}; do
            source $i
        done;

        load_config_variables;

      else

        echo "*** Skipping... ***"

      fi

    elif [[ -z "$HEX_SECRET_ADMIN_PASSWORD" ]] ; then

      for k in ${GENERATE_VALUES_LIST[@]}; do

          grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

          # Using special form to generate both API_KEYS keys and secret
          if [[ "$k" == "HEX_SECRET_API_KEYS" ]]; then

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values):$(generate_random_values)
EOL

          else 

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

          fi
        
        done

        unset k
        unset GENERATE_VALUES_LIST
        unset HEX_CONFIGMAP_VARIABLES
        unset HEX_SECRET_VARIABLES
        unset HEX_SECRET_VARIABLES_BASE64
        unset HEX_SECRET_VARIABLES_YAML
        unset HEX_CONFIGMAP_VARIABLES_YAML

        for i in ${CONFIG_FILE_PATH[@]}; do
            source $i
        done;

        load_config_variables;

    fi
    
  fi
done

unset GENERATE_VALUES_LIST
 
}

function generate_nodeselector_values() {

INPUT_VALUE=$1
CONVERTED_VALUE=$(printf "${INPUT_VALUE/:/: }")

# Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-$2.yaml <<EOL
nodeSelector: $(echo $CONVERTED_VALUE)
EOL

}

# `helm_dynamic_trading_paris run` for running paris based on config file definition.
# `helm_dynamic_trading_paris terminate` for terminating installed paris on kubernetes.

function helm_dynamic_trading_paris() {

  IFS=',' read -ra PAIRS <<< "$HEX_CONFIGMAP_PAIRS"    #Convert string to array

  for i in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $i | cut -f1 -d ",")
    TRADE_PARIS_DEPLOYMENT_NAME=${TRADE_PARIS_DEPLOYMENT//-/}

    if [[ "$1" == "run" ]]; then

      #Running and Upgrading
      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --namespace $ENVIRONMENT_EXCHANGE_NAME --recreate-pods --set DEPLOYMENT_MODE="queue $TRADE_PARIS_DEPLOYMENT" --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server

    elif [[ "$1" == "scaleup" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=1 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "scaledown" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=0 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "terminate" ]]; then

      #Terminating
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME

    fi

  done

}

function check_empty_values_on_settings() {

  for i in ${HEX_CONFIGMAP_VARIABLES[@]}; do

    PARSED_CONFIGMAP_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_CONFIGMAP_VARIABLES ]]; then

      echo -e "\nWarning! Configmap - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files.\n"

    fi
  
  done

  GENERATE_VALUES_LIST=( "ADMIN_PASSWORD" "SUPERVISOR_PASSWORD" "SUPPORT_PASSWORD" "KYC_PASSWORD" "QUICK_TRADE_SECRET" "API_KEYS" "SECRET" )

  for i in ${HEX_SECRET_VARIABLES[@]}; do

    PARSED_SECRET_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_SECRET_VARIABLES ]]; then

      echo -e "\nWarning! Secret - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files."

      for k in "${GENERATE_VALUES_LIST[@]}"; do

          GENERATE_VALUES_FILTER=$(echo $i | cut -f1 -d '=')

          if [[ "$k" == "${GENERATE_VALUES_FILTER}" ]] ; then

              echo -n "\"$k\" is a value should be automatically generated by hex-cli."
              echo -e "\n"

          fi

      done

    fi
  
  done

}

function override_docker_image_version() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/$ENVIRONMENT_DOCKER_IMAGE_VERSION/$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

# JSON generator
function join_array_to_json(){
  local arr=( "$@" );
  local len=${#arr[@]}

  if [[ ${len} -eq 0 ]]; then
          >&2 echo "Error: Length of input array needs to be at least 2.";
          return 1;
  fi

  if [[ $((len%2)) -eq 1 ]]; then
          >&2 echo "Error: Length of input array needs to be even (key/value pairs).";
          return 1;
  fi

  local data="";
  local foo=0;
  for i in "${arr[@]}"; do
          local char=","
          if [ $((++foo%2)) -eq 0 ]; then
          char=":";
          fi

          local first="${i:0:1}";  # read first charc

          local app="\"$i\""

          if [[ "$first" == "^" ]]; then
          app="${i:1}"  # remove first char
          fi

          data="$data$char$app";

  done

  data="${data:1}";  # remove first char
  echo "{$data}";    # add braces around the string
}

function add_coin_input() {

  echo "*** What is a symbol of your new coin? [Default: eth] ***"
  read answer

  COIN_SYMBOL=${answer:-eth}

  echo "*** What is a full name of your new coin? [Default: Ethereum] ***"
  read answer

  COIN_FULLNAME=${answer:-Ethereum}

  echo "*** Are you going to allow deposit to your new coin? (y/n) [Default: y] ***"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_DEPOSIT='false'
  
  else

    COIN_ALLOW_DEPOSIT='true'

  fi

  echo "*** Are you going to allow withdrawal to your new coin? (y/n) [Default: y] ***"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_WITHDRAWAL='false'
  
  else

    COIN_ALLOW_WITHDRAWAL='true'

  fi
  
  echo "*** What is the fee of new coin withdrawal? [Default: 0.001] ***"
  read answer

  COIN_WITHDRAWAL_FEE=${answer:-0.001}

  echo "*** What is the minimum price of the new coin? [Default: 0.001] ***"
  read answer

  COIN_MIN=${answer:-0.001}

  echo "*** What is the maximum price of the new coin? [Default: 10000] ***"
  read answer

  COIN_MAX=${answer:-10000}

  echo "*** What is the increment size of the new coin? [Default: 0.001] ***"
  read answer

  COIN_INCREMENT_UNIT=${answer:-0.001}

  # Checking user level setup on settings file is set or not
  if [[ ! "$HEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    echo "*** Warning: Settings value - HEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files. ***"
    exit 1;

  fi

  # Side-by-side printer 
  function print_deposit_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_DEPOSIT_LIMITS_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_DEPOSIT_LIMITS_LEVEL[i]}" "${VALUE_DEPOSIT_LIMITS_LEVEL[i]}"
    done
  }

  # Side-by-side printer 
  function print_withdrawal_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_WITHDRAWAL_LIMITS_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_WITHDRAWAL_LIMITS_LEVEL[i]}" "${VALUE_WITHDRAWAL_LIMITS_LEVEL[i]}"
    done
  }

  # Asking deposit limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "*** What is a deposit limit for user on LEVEL $i? ***" && read answer && export DEPOSIT_LIMITS_LEVEL_$i=$answer
  
  done;

  read -ra RANGE_DEPOSIT_LIMITS_LEVEL <<< $(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -c22 )
  read -ra VALUE_DEPOSIT_LIMITS_LEVEL <<< $(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -f2 -d "=" )

  COIN_DEPOSIT_LIMITS=$(join_array_to_json $(print_deposit_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "*** What is a withdrawal limit for user on LEVEL $i? ***" && read answer && export WITHDRAWAL_LIMITS_LEVEL_$i=$answer
  
  done;

  read -ra RANGE_WITHDRAWAL_LIMITS_LEVEL <<< $(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -c25 )
  read -ra VALUE_WITHDRAWAL_LIMITS_LEVEL <<< $(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -f2 -d "=" )

  COIN_WITHDRAWAL_LIMITS=$(join_array_to_json $(print_withdrawal_array_side_by_side))

  echo "*** Are you going to active the new coin you just configured? (y/n) [Default: y] ***"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ACTIVE='false'
  
  else

    COIN_ACTIVE='true'

  fi

  function print_coin_add_deposit_level(){ 

    for i in $(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_");

      do echo -e "$i"

    done;

  }

  function print_coin_add_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_");

      do echo -e "$i"

    done;

  }
  
  echo "*********************************************"
  echo "Symbol: $COIN_SYMBOL"
  echo "Full name: $COIN_FULLNAME"
  echo "Allow deposit: $COIN_ALLOW_DEPOSIT"
  echo "Allow withdrawal: $COIN_ALLOW_WITHDRAWAL"
  echo "Minimum price: $COIN_MIN"
  echo "Maximum price: $COIN_MAX"
  echo "Increment size: $COIN_INCREMENT_UNIT"
  echo -e "Deposit limits per level:\n$(print_coin_add_deposit_level;)"
  echo -e "Withdrawal limits per level:\n$(print_coin_add_withdrawal_level;)"
  echo "Activation: $COIN_ACTIVE"
  echo "*********************************************"

  echo "*** Are the values are all correct? (y/n) ***"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "*** You chose false. Please confirm the values and re-run the command. ***"
    exit 1;
  
  fi
}


function add_coin_exec() {

  if [[ "$USE_KUBERNETES" ]]; then


    function generate_kubernetes_add_coin_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml <<EOL
job:
  enable: true
  mode: add_coin
  env:
    coin_symbol: ${COIN_SYMBOL}
    coin_fullname: ${COIN_FULLNAME}
    coin_allow_deposit: ${COIN_ALLOW_DEPOSIT}
    coin_allow_withdrawal: ${COIN_ALLOW_WITHDRAWAL}
    coin_withdrawal_fee: ${COIN_WITHDRAWAL_FEE}
    coin_min: ${COIN_MIN}
    coin_max: ${COIN_MAX}
    coin_increment_unit: ${COIN_INCREMENT_UNIT}
    coin_deposit_limits: '${COIN_DEPOSIT_LIMITS}'
    coin_withdrawal_limits: '${COIN_WITHDRAWAL_LIMITS}'
    coin_active: ${COIN_ACTIVE}
EOL

    }

    generate_kubernetes_add_coin_values;

    echo "*** Adding new coin $COIN_SYMBOL on Kubernetes ***"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL --namespace $ENVIRONMENT_EXCHANGE_NAME --set job.enable="true" --set job.mode="add_coin" --set DEPLOYMENT_MODE="api" --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "*** Kubernetes Job has been created for adding new coin $COIN_SYMBOL. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      echo "*** Failed to create Kubernetes Job for adding new coin $COIN_SYMBOL, Please confirm your input values and try again. ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Coin $COIN_SYMBOL has been successfully added on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL
      
      echo "*** Upgrading exchange with latest settings... ***"
      hex upgrade --kube --no_verify

      echo "*** Removing created Kubernetes Job for adding new coin... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      echo "*** Updating settings file to add new $COIN_SYMBOL. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          HEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

    else

      echo "*** Failed to add new coin $COIN_SYMBOL! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

          IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"
          
      fi

      echo "*** Adding new coin $COIN_SYMBOL on local exchange ***"
      if command docker exec --env "COIN_FULLNAME=${COIN_FULLNAME}" \
                  --env "COIN_SYMBOL=${COIN_SYMBOL}" \
                  --env "COIN_ALLOW_DEPOSIT=${COIN_ALLOW_DEPOSIT}" \
                  --env "COIN_ALLOW_WITHDRAWAL=${COIN_ALLOW_WITHDRAWAL}" \
                  --env "COIN_WITHDRAWAL_FEE=${COIN_WITHDRAWAL_FEE}" \
                  --env "COIN_MIN=${COIN_MIN}" \
                  --env "COIN_MAX=${COIN_MAX}" \
                  --env "COIN_INCREMENT_UNIT=${COIN_INCREMENT_UNIT}" \
                  --env "COIN_DEPOSIT_LIMITS=${COIN_DEPOSIT_LIMITS}" \
                  --env "COIN_WITHDRAWAL_LIMITS=${COIN_WITHDRAWAL_LIMITS}" \
                  --env "COIN_ACTIVE=${COIN_ACTIVE}"  \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addCoin.js; then

        echo "*** Running database triggers ***"
        docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

        # Restarting containers after database init jobs.
        echo "*** Restarting containers to apply database changes. ***"
        docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        echo "*** Updating settings file to add new $COIN_SYMBOL. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
            sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done

      else

        echo "*** Failed to add new coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again. ***"
        exit 1;

      fi

      # Restarting containers after database init jobs.
      echo "Restarting containers to apply database changes."
      docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

  fi

}

function remove_coin_input() {

  echo "*** What is a symbol of your want to remove? ***"
  read answer

  COIN_SYMBOL=$answer

  if [[ -z "$answer" ]]; then

    echo "*** Your value is empty. Please confirm your input and run the command again. ***"
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Symbol: $COIN_SYMBOL"
  echo "*********************************************"

  echo "*** Are the sure you want to remove this coin from your exchange? (y/n) ***"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "*** You chose false. Please confirm the values and run the command again. ***"
    exit 1;
  
  fi

}

function remove_coin_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

  echo "*** Removing existing coin $COIN_SYMBOL on Kubernetes ***"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_coin" \
                --set job.env.coin_symbol="$COIN_SYMBOL" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "*** Kubernetes Job has been created for removing existing coin $COIN_SYMBOL. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      echo "*** Failed to create Kubernetes Job for removing existing coin $COIN_SYMBOL, Please confirm your input values and try again. ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Coin $COIN_SYMBOL has been successfully removed on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      
      echo "*** Restarting containers... ***"
      kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

      echo "*** Removing created Kubernetes Job for removing existing coin... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "*** Updating settings file to remove $COIN_SYMBOL. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$COIN_SYMBOL" == "hex" ]]; then
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//$COIN_SYMBOL,}")
          else
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//,$COIN_SYMBOL}")
          fi
          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

    else

      echo "*** Failed to remove existing coin $COIN_SYMBOL! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

          IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"
          
      fi

      echo "*** Removing new coin $COIN_SYMBOL on local docker ***"
      if command docker exec --env "COIN_SYMBOL=${COIN_SYMBOL}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/removeCoin.js; then

      # Restarting containers after database init jobs.
      echo "Restarting containers to apply database changes."
      docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

      echo "*** Updating settings file to remove $COIN_SYMBOL. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$COIN_SYMBOL" == "hex" ]]; then
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//$COIN_SYMBOL,}")
          else
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//,$COIN_SYMBOL}")
          fi
          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      else

        echo "*** Failed to remove coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again. ***"
        exit 1;

      fi

  fi

}

function add_pair_input() {

  echo "*** What is a full name of your new trading pair? [Default: eth-usdt] ***"
  read answer

  PAIR_NAME=${answer:-eth-usdt}
  PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
  PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

  # Checking user level setup on settings file is set or not
  if [[ ! "$HEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    echo "*** Warning: Settings value - HEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files. ***"
    exit 1;

  fi

  # Side-by-side printer 
  function print_taker_fees_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_TAKER_FEES_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_TAKER_FEES_LEVEL[i]}" "${VALUE_TAKER_FEES_LEVEL[i]}"
    done
  }

  # Side-by-side printer 
  function print_maker_fees_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_MAKER_FEES_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_MAKER_FEES_LEVEL[i]}" "${VALUE_MAKER_FEES_LEVEL[i]}"
    done
  }

  # Asking deposit limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "*** What is a taker fee for user on LEVEL $i? ***" && read answer && export TAKER_FEES_LEVEL_$i=$answer
  
  done;

  read -ra RANGE_TAKER_FEES_LEVEL <<< $(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -c18 )
  read -ra VALUE_TAKER_FEES_LEVEL <<< $(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  TAKER_FEES=$(join_array_to_json $(print_taker_fees_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "*** What is a maker fee for user on LEVEL $i? ***" && read answer && export MAKER_FEES_LEVEL_$i=$answer
  
  done;

  read -ra RANGE_MAKER_FEES_LEVEL <<< $(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -c18 )
  read -ra VALUE_MAKER_FEES_LEVEL <<< $(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  MAKER_FEES=$(join_array_to_json $(print_maker_fees_array_side_by_side))

  echo "*** What is the minimum size for trading of the new pair? [Default: 0.001] ***"
  read answer

  MIN_SIZE=${answer:-0.001}

  echo "*** What is the maximum size for trading of the new pair? [Default: 20000000] ***"
  read answer

  MAX_SIZE=${answer:-20000000}

  echo "*** What is the minimum price of the new pair? [Default: 0.0001] ***"
  read answer

  MIN_PRICE=${answer:-0.0001}

  echo "*** What is the maximum price for trading of the new pair? [Default: 10] ***"
  read answer

  MAX_PRICE=${answer:-10}

  echo "*** What is the increment size of the new pair? [Default: 0.001] ***"
  read answer

  INCREMENT_SIZE=${answer:-0.001}

  echo "*** What is the increment price of the new pair? [Default: 1] ***"
  read answer

  INCREMENT_PRICE=${answer:-1}

  echo "*** Are you going to active the new pair you just configured? (y/n) [Default: y] ***"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    PAIR_ACTIVE=false
  
  else

    PAIR_ACTIVE=true

  fi

  function print_taker_fees_deposit_level(){ 

    for i in $(set -o posix ; set | grep "TAKER_FEES_LEVEL_");

      do echo -e "$i"

    done;

  }

  function print_maker_fees_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "MAKER_FEES_LEVEL_");

      do echo -e "$i"

    done;

  }
  
  echo "*********************************************"
  echo "Full name: $PAIR_NAME"
  echo "First currency: $PAIR_BASE"
  echo "Second currency: $PAIR_2"
  echo -e "Taker fees per level:\n$(print_taker_fees_deposit_level;)"
  echo -e "Maker limits per level:\n$(print_maker_fees_withdrawal_level;)"
  echo "Minimum size: $MIN_SIZE"
  echo "Maximum size: $MAX_SIZE"
  echo "Minimum price: $MIN_PRICE"
  echo "Maximum price: $MAX_PRICE"
  echo "Increment size: $INCREMENT_SIZE"
  echo "Increment price: $INCREMENT_PRICE"
  echo "Activation: $PAIR_ACTIVE"
  echo "*********************************************"

  echo "*** Are the values are all correct? (y/n) ***"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "*** You chose false. Please confirm the values and re-run the command. ***"
    exit 1;
  
  fi

}


function add_pair_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_add_pair_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml <<EOL
job:
  enable: true
  mode: add_pair
  env:
    pair_name: ${PAIR_NAME}
    pair_base: ${PAIR_BASE}
    pair_2: ${PAIR_2}
    taker_fees: '${TAKER_FEES}'
    maker_fees: '${MAKER_FEES}'
    min_size: ${MIN_SIZE}
    max_size: ${MAX_SIZE}
    min_price: ${MIN_PRICE}
    max_price: ${MAX_PRICE}
    increment_size: ${INCREMENT_SIZE}
    increment_price: ${INCREMENT_PRICE}
    pair_active: ${PAIR_ACTIVE}
EOL

      }

    generate_kubernetes_add_pair_values;

    echo "*** Adding new pair $PAIR_NAME on Kubernetes ***"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="add_pair" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "*** Kubernetes Job has been created for adding new pair $PAIR_NAME. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      echo "*** Failed to create Kubernetes Job for adding new pair $PAIR_NAME, Please confirm your input values and try again. ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Pair $PAIR_NAME has been successfully added on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "*** Updating settings file to add new $PAIR_NAME. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          HEX_CONFIGMAP_PAIRS_OVERRIDE="${HEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
          sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      # Reading variable again
      for i in ${CONFIG_FILE_PATH[@]}; do
        source $i
      done;
      
      source $SCRIPTPATH/tools_generator.sh
      load_config_variables;
      
      echo "*** Upgrading exchange with latest settings... ***"
      hex upgrade --kube --no_verify

      echo "*** Removing created Kubernetes Job for adding new coin... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

    else

      echo "*** Failed to add new pair $PAIR_NAME! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

          IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"
          
      fi

      echo "*** Adding new pair $PAIR_NAME on local exchange ***"
      if command docker exec --env "PAIR_NAME=${PAIR_NAME}" --env "PAIR_BASE=${PAIR_BASE}" --env "PAIR_2=${PAIR_2}" --env "TAKER_FEES=${TAKER_FEES}" --env "MAKER_FEES=${MAKER_FEES}" --env "MIN_SIZE=${MIN_SIZE}" --env "MAX_SIZE=${MAX_SIZE}" --env "MIN_PRICE=${MIN_PRICE}" --env "MAX_PRICE=${MAX_PRICE}" --env "INCREMENT_SIZE=${INCREMENT_SIZE}" --env "INCREMENT_PRICE=${INCREMENT_PRICE}"  --env "PAIR_ACTIVE=${PAIR_ACTIVE}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/addPair.js; then

         # Restarting containers after database init jobs.
        echo "Restarting containers to apply database changes."
        docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        echo "*** Updating settings file to add new $PAIR_NAME. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i
            HEX_CONFIGMAP_PAIRS_OVERRIDE="${HEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
            sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done

      else

        echo "*** Failed to add new pair $PAIR_NAME on local exchange. Please confirm your input values and try again. ***"
        exit 1;

      fi

  fi

}

function remove_pair_input() {

  echo "*** What is a name of your trading pair want to remove? ***"
  read answer

  PAIR_NAME=$answer

  if [[ -z "$answer" ]]; then

    echo "*** Your value is empty. Please confirm your input and run the command again. ***"
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Name: $PAIR_NAME"
  echo "*********************************************"

  echo "*** Are the sure you want to remove this trading pair from your exchange? (y/n) ***"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "*** You chose false. Please confirm the values and run the command again. ***"
    exit 1;
  
  fi

}

function remove_pair_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

    echo "*** Removing existing pair $PAIR_NAME on Kubernetes ***"
      
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_pair" \
                --set job.env.pair_name="$PAIR_NAME" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "*** Kubernetes Job has been created for removing existing pair $PAIR_NAME. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      echo "*** Failed to create Kubernetes Job for removing existing pair $PAIR_NAME, Please confirm your input values and try again. ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Pair $PAIR_NAME has been successfully removed on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Removing existing $PAIR_NAME container from Kubernetes ***"
      PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
      PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-queue-$PAIR_BASE$PAIR_2

      echo "*** Restarting containers... ***"
      kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

      echo "*** Removing created Kubernetes Job for removing existing pair... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Updating settings file to add new $PAIR_NAME. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$PAIR_NAME" == "hex-usdt" ]]; then
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//$PAIR_NAME,}")
            else
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//,$PAIR_NAME}")
          fi
          sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

    else

      echo "*** Failed to remove existing pair $PAIR_NAME! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      if [[ ! $ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE == "all" ]]; then

          IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE}"
          
      fi

      echo "*** Removing new pair $PAIR_NAME on local exchange ***"
      if command docker exec --env "PAIR_NAME=${PAIR_NAME}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/removePair.js; then

        # Restarting containers after database init jobs.
        echo "Restarting containers to apply database changes."
        docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        echo "*** Updating settings file to add new $PAIR_NAME. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i
            if [[ "$PAIR_NAME" == "hex-usdt" ]]; then
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//$PAIR_NAME,}")
            else
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//,$PAIR_NAME}")
            fi
            sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done

      else

        echo "*** Failed to remove trading pair $PAIR_NAME on local exchange. Please confirm your input values and try again. ***"
        exit 1;

      fi

  fi

}