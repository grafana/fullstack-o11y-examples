# Build stage: compile the Spring Boot fat jar.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# Runtime stage: JRE + OpenTelemetry Java agent for auto-instrumentation.
FROM eclipse-temurin:21-jre
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
COPY --from=build /app/target/*.jar /app/app.jar
EXPOSE 8002
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
