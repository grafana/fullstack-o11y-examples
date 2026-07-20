# Build stage: compile the Spring Boot fat jar.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# Runtime stage: JRE + OpenTelemetry Java agent for auto-instrumentation.
FROM eclipse-temurin:21.0.11_10-jre@sha256:273396ed5998598ed1091e8d72711c2d36980a0e65103859c55a4e977a41ffd3
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
COPY --from=build /app/target/*.jar /app/app.jar
EXPOSE 8003
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
