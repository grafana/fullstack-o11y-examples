# Build stage: compile the Spring Boot fat jar.
FROM maven:3.9-eclipse-temurin-21@sha256:8f6ac126f7810bb5549c4cd122d2bf0e9cda5bdeb0838aa928f09e779fd8bef8 AS build
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
FROM eclipse-temurin:25-jre@sha256:f9e65324a37f28209ce7dd0e5149a7aa954520ed936fb87813cf6ded2400a112
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
