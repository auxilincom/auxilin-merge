#!/bin/bash

INCLUDE_API=false;
INCLUDE_WEB=false;
INCLUDE_LANDING=false;
INCLUDE_DRONE=false;
INCLUDE_GRAFANA=false;

API_VERSION="";
WEB_VERSION="";
LANDING_VERSION="";
DRONE_VERSION="";
GRAFANA_VERSION="";

AUXILIN_VERSION="";

rm -rf ./temp_repos
mkdir ./temp_repos
cd ./temp_repos

auxilinRepository="https://github.com/auxilincom/auxilin"
reactRepository="https://github.com/auxilincom/koa-react-starter"
apiRepository="https://github.com/auxilincom/koa-api-starter"
landingRepository="https://github.com/auxilincom/nextjs-landing-starter"
droneRepository="https://github.com/auxilincom/deploy-drone"
grafanaRepository="https://github.com/auxilincom/deploy-grafana"

auxilinPath="auxilin"
reactPath="koa-react-starter"
apiPath="koa-api-starter"
landingPath="nextjs-landing-starter"
dronePath="deploy-drone"
grafanaPath="deploy-grafana"

reactEnvironmentPath="src/server/config/environment"
apiEnvironmentPath="src/config/environment"
landingEnvironmentPath="src/server/config/environment"

filesToRemove=( ".drone.yml"
                "docker-compose.yml"
                "LICENSE"
                "CHANGELOG.md"
                "CODE_OF_CONDUCT.md"
                ".all-contributorsrc"
                "CONTRIBUTING.md"
                "README.md"
                "package-lock.json" )

repositoryActions() {
  declare -a files=("${!4}")
  cd ./$1
  
  echo "### $1 ###"

  if [ "$2" != "master" ]
  then
    git checkout tags/$2
  fi

  echo "=== START REMOVE UNNECESSARY FILES FROM HISTORY ==="
  
  git filter-branch --tree-filter "
    GLOBIGNORE='n*';
    rm ${files[*]};
    mv AUXILIN_README.md README.md
    sed -i '/all-contributor/d' package.json
    sed -zri 's/,\n  }/\n  }/g' package.json
    mkdir -p ../temp_path;
    mv * ../temp_path;
    mkdir $3;
    mv ../temp_path/* $3/;
    unset GLOBIGNORE;
  " --force --prune-empty HEAD
  
  git branch -D master
  git checkout -b master
  echo "=== DONE REMOVE FILES FROM HISTORY ==="

  cd ../
}

repositoryActions2() {
  declare -a files=("${!4}")
  cd ./$1
  
  echo "### $1 ###"

  if [ "$2" != "master" ]
  then
    git checkout tags/$2
  fi

  echo "=== START REMOVE UNNECESSARY FILES FROM HISTORY ==="
  
  GLOBIGNORE='n*';
  rm -f ${files[*]};
  mv AUXILIN_README.md README.md
  sed -i '/all-contributor/d' package.json
  sed -zri 's/,\n  }/\n  }/g' package.json
  mkdir -p ../temp_path;
  mv * ../temp_path;
  mkdir -p $3;
  mv ../temp_path/* $3/;
  unset GLOBIGNORE;
  
  echo "=== DONE REMOVE FILES FROM HISTORY ==="

  cd ../
}

cloneRepository() {
  echo "=== CLONE REPOSITORY $1 ==="
  git clone $1
  echo "=== DONE CLONE REPOSITORY $1 ==="
}

copyCommitsToAuxilin() {
  echo "=== START COPY COMMITS TO THE AUXILIN REPOSITORY from $1 ==="
  cd ./$auxilinPath
      
  git remote add repo-$1 ../$1/.git
  git pull repo-$1 master --allow-unrelated-histories --no-edit
  git remote rm repo-$1

  echo "=== END COPY COMMITS ==="
  cd ../
}

copyFileToAuxilin() {
  echo "=== START COPY FILES TO THE AUXILIN REPOSITORY FROM $1 ==="
  
  rm -rf ./$1/$2/.git
  rm -rf ./$auxilinPath/$2
  mv ./$1/$2 ./$auxilinPath/$3
  
  echo "=== END COPY FILES ==="
}

copyStagingEnvironmentFile() {
  echo "=== COPY STAGING ENVIRONMENT FILE ==="
  cp ../staging.js "./$1/$2/staging.js"
  echo "=== DONE COPY STAGING ENVIRONMENT FILE ==="
}

commitFiles() {
  echo "=== START COMMIT $1 FILES==="

  cd ./$auxilinPath
  git add -A;
  git commit -m "Merge $1. Version $2"

  echo "=== END COMMIT FILES ==="
  cd ../
}

parseYaml() {
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

regeneratePackageLock() {
  cd ./$1
  # Remove all contributors from package-lock.json
  rm -f package-lock.json
  npm i --quiet
  rm -rf ./node_modules

  cd ../../
}

changeRepository() {
  repositoryActions2 $1 $2 $3 filesToRemove[@]
  copyStagingEnvironmentFile "$1/$3" $4
  regeneratePackageLock "$1/$3"
  copyFileToAuxilin $1 $3 ""
  commitFiles $1 $2
}

changeDeployRepository() {
  cd ./$1/$2
  rm package.json
  cd ../../../
}

cloneRepository $auxilinRepository

echo "=== PARSE release.yml FILE ==="
cd ../
eval $(parseYaml release.yml "config_")
cd ./temp_repos

INCLUDE_API=$config_services_api_include;
INCLUDE_WEB=$config_services_web_include;
INCLUDE_LANDING=$config_services_landing_include;
INCLUDE_DRONE=$config_services_drone_include;
INCLUDE_GRAFANA=$config_services_monitoring_include;

AUXILIN_VERSION=$config_services_auxilin_version;
API_VERSION=$config_services_api_version;
WEB_VERSION=$config_services_web_version;
LANDING_VERSION=$config_services_landing_version;
DRONE_VERSION=$config_services_drone_version;
GRAFANA_VERSION=$config_services_monitoring_version;

echo "=== END PARSE FILE ==="

# cd ./$auxilinPath
# git filter-branch --tree-filter "rm -rf ./api ./web ./landing;" --force --prune-empty HEAD
# cd ../

if [ "$INCLUDE_API" = true ]
then
  cloneRepository $apiRepository

  if [ "$API_VERSION" = "latest" ]
  then
    cd ./$apiPath
    API_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
    cd ../
  fi

  # repositoryActions $apiPath $API_VERSION "api" filesToRemove[@]
  # copyCommitsToAuxilin $apiPath
  changeRepository $apiPath $API_VERSION "api" $apiEnvironmentPath
fi

if [ "$INCLUDE_WEB" = true ]
then
  cloneRepository $reactRepository

  if [ "$WEB_VERSION" = "latest" ]
  then
    cd ./$reactPath
    WEB_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
    cd ../
  fi

  # repositoryActions $reactPath $WEB_VERSION "web" filesToRemove[@]
  # copyCommitsToAuxilin $reactPath
  changeRepository $reactPath $WEB_VERSION "web" $reactEnvironmentPath
fi

if [ "$INCLUDE_LANDING" = true ]
then
  cloneRepository $landingRepository

  if [ "$LANDING_VERSION" = "latest" ]
  then
    cd ./$landingPath
    LANDING_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
    cd ../
  fi

  # repositoryActions $landingPath $LANDING_VERSION "landing" filesToRemove[@]
  # copyCommitsToAuxilin $landingPath
  changeRepository $landingPath $LANDING_VERSION "landing" $landingEnvironmentPath
fi

if [ "$INCLUDE_DRONE" = true ]
then
  cloneRepository $droneRepository

  if [ "$DRONE_VERSION" = "latest" ]
  then
    cd ./$dronePath
    DRONE_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
    cd ../
  fi

  repositoryActions2 $dronePath $DRONE_VERSION "deploy/drone-ci" filesToRemove[@]
  changeDeployRepository $dronePath "deploy/drone-ci"
  copyFileToAuxilin $dronePath "deploy/drone-ci" "deploy"
  commitFiles $dronePath $DRONE_VERSION
fi

if [ "$INCLUDE_GRAFANA" = true ]
then
  cloneRepository $grafanaRepository

  if [ "$GRAFANA_VERSION" = "latest" ]
  then
    cd ./$grafanaPath
    GRAFANA_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
    cd ../
  fi

  repositoryActions2 $grafanaPath $GRAFANA_VERSION "deploy/monitoring" filesToRemove[@]
  changeDeployRepository $grafanaPath "deploy/monitoring"
  copyFileToAuxilin $grafanaPath "deploy/monitoring" "deploy"
  commitFiles $grafanaPath $GRAFANA_VERSION
fi

cd ./$auxilinPath

sed -i "1s/^/  5) deploy grafana version [$GRAFANA_VERSION](https:\/\/github.com\/auxilincom\/deploy-grafana\/releases\/tag\/$GRAFANA_VERSION)\n\n/" CHANGELOG.md
sed -i "1s/^/  4) deploy drone version [$DRONE_VERSION](https:\/\/github.com\/auxilincom\/deploy-drone\/releases\/tag\/$DRONE_VERSION)\n\n/" CHANGELOG.md
sed -i "1s/^/  3) web version [$WEB_VERSION](https:\/\/github.com\/auxilincom\/koa-react-starter\/releases\/tag\/$WEB_VERSION)\n/" CHANGELOG.md
sed -i "1s/^/  2) landing version [$LANDING_VERSION](https:\/\/github.com\/auxilincom\/nextjs-landing-starter\/releases\/tag\/$LANDING_VERSION)\n/" CHANGELOG.md
sed -i "1s/^/  1) api version [$API_VERSION](https:\/\/github.com\/auxilincom\/koa-api-starter\/releases\/tag\/$API_VERSION)\n/" CHANGELOG.md
sed -i "1s/^/* New release of auxilin with the following components:\n/" CHANGELOG.md

releaseDate=`date '+%B %d, %Y'`;
sed -i "1s/^/## $AUXILIN_VERSION ($releaseDate)\n\n/" CHANGELOG.md

git add -A;
git commit -m "Version $AUXILIN_VERSION";
git tag $AUXILIN_VERSION;

# git remote set-url origin git@github.com:auxilincom/auxilin
