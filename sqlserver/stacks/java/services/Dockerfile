# Build stage: compile the Spring Boot fat jar.
FROM maven:3.10-eclipse-temurin-21@sha256:af3a049b2808ffaeccd31e2c2eba0d47776468d1e4f2fd6c1f9fd2f89aabf602 AS build
ARG SERVICE
WORKDIR /app
COPY ${SERVICE}/pom.xml .
RUN mvn -q -B dependency:go-offline
COPY ${SERVICE}/src ./src
RUN mvn -q -B -DskipTests package

ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /tmp/rds.pem
RUN cp "$JAVA_HOME/lib/security/cacerts" /tmp/cacerts \
    && awk '/BEGIN CERTIFICATE/{n++} {print > ("/tmp/rds-" n ".pem")}' /tmp/rds.pem \
    && for cert in /tmp/rds-*.pem; do \
         keytool -importcert -noprompt -trustcacerts -alias "$(basename "$cert")" \
           -file "$cert" -keystore /tmp/cacerts -storepass changeit; \
       done

# Runtime stage: JRE + OpenTelemetry Java agent for auto-instrumentation.
FROM eclipse-temurin:25-jre@sha256:4ed132f6832e9804b123e89a849a7b4502756ae64a4ee08ebab939d9d5d0a9fa
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.33.1/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
# Pyroscope OTel extension: when loaded into the OTel agent it runs the embedded
# Pyroscope profiler and tags profiles with span IDs for trace ↔ profile
# correlation. Only downloaded here — enabling it is the deployment's choice via
# OTEL_JAVAAGENT_EXTENSIONS (set in docker-compose.yml), so consumers of this
# image that don't configure profiling (e.g. java/k8s) are unaffected.
ADD https://github.com/grafana/otel-profiling-java/releases/download/v2.1.0/pyroscope-otel-javaagent-extension.jar /otel/pyroscope-otel-javaagent-extension.jar
COPY --from=build /app/target/*.jar /app/app.jar
COPY --from=build /tmp/cacerts /opt/java/openjdk/lib/security/cacerts
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
