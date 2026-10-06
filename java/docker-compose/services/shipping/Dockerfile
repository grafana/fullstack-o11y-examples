# Build stage: compile the Spring Boot fat jar.
FROM maven:3.10-eclipse-temurin-21@sha256:1f4555322b25bc65c1ae2b87d0558047754ef766abf9bd8a0df8bd342d136eb5 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# Runtime stage: JRE + OpenTelemetry Java agent for auto-instrumentation.
FROM eclipse-temurin:25-jre@sha256:fcd7fd7b387f94bb2ac461478a7436ad8e349924c374ea8313919624dceae636
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
# Pyroscope OTel extension: when loaded into the OTel agent it runs the embedded
# Pyroscope profiler and tags profiles with span IDs for trace ↔ profile
# correlation. Only downloaded here — enabling it is the deployment's choice via
# OTEL_JAVAAGENT_EXTENSIONS (set in docker-compose.yml), so consumers of this
# image that don't configure profiling (e.g. java/k8s) are unaffected.
ADD https://github.com/grafana/otel-profiling-java/releases/download/v2.1.0/pyroscope-otel-javaagent-extension.jar /otel/pyroscope-otel-javaagent-extension.jar
COPY --from=build /app/target/*.jar /app/app.jar
EXPOSE 8003
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
