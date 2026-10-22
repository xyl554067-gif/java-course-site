#!/usr/bin/env bash
# 将本地 KingBase JDBC 驱动安装进 Maven 本地仓库
# 目的：避免 system scope（不进 BOOT-INF/lib），也无需联网下载
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAR="$ROOT/backend/lib/kingbase8-8.6.0.jar"
MVN="$ROOT/tools/apache-maven-3.9.9/bin/mvn"

if [ ! -f "$JAR" ]; then
  echo "!! 找不到驱动 jar: $JAR"
  exit 1
fi

echo "==> 安装 KingBase 驱动到本地 Maven 仓库"
"$MVN" -q -B install:install-file \
  -Dfile="$JAR" \
  -DgroupId=cn.com.kingbase \
  -DartifactId=kingbase8 \
  -Dversion=8.6.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

echo "==> 完成，依赖坐标: cn.com.kingbase:kingbase8:8.6.0"
