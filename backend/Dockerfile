FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Kingbase JDBC driver is a local vendor JAR, so install it in the build image.
COPY backend/lib/kingbase8-8.6.0.jar /tmp/kingbase8-8.6.0.jar
RUN mvn -B org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
    -Dfile=/tmp/kingbase8-8.6.0.jar \
    -DgroupId=cn.com.kingbase -DartifactId=kingbase8 \
    -Dversion=8.6.0 -Dpackaging=jar -DgeneratePom=true

COPY backend/pom.xml backend/pom.xml
COPY backend/src backend/src
RUN mvn -B -f backend/pom.xml -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/backend/target/javacourse-server-1.0.0.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

