# Build stage: compile the Spring Boot fat jar.
FROM maven:3.9-eclipse-temurin-21@sha256:99e61abcff91a9b1333463bd8451fb18495d6eba9250ac66a338b518f8278320 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# Runtime stage: JRE + OpenTelemetry Java agent for auto-instrumentation.
FROM eclipse-temurin:25-jre@sha256:8da0490fa9a3c26867012019565948eef0ee69438f5c75ac28146967bae984b5
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
# Pyroscope OTel extension: when loaded into the OTel agent it runs the embedded
# Pyroscope profiler and tags profiles with span IDs for trace ↔ profile
# correlation. Only downloaded here — enabling it is the deployment's choice via
# OTEL_JAVAAGENT_EXTENSIONS (set in docker-compose.yml), so consumers of this
# image that don't configure profiling (e.g. java/k8s) are unaffected.
ADD https://github.com/grafana/otel-profiling-java/releases/download/v2.1.0/pyroscope-otel-javaagent-extension.jar /otel/pyroscope-otel-javaagent-extension.jar
COPY --from=build /app/target/*.jar /app/app.jar
EXPOSE 8001
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
