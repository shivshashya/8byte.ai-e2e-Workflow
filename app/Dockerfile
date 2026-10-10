# Stage 1: compile the code and package it into one runnable JAR.
# This stage has the full JDK and Maven; none of it ends up in the final image.
FROM eclipse-temurin:17-jdk AS build
WORKDIR /workspace


# Copy only the build definition first. Docker caches this layer, so the
# dependency download is repeated only when pom.xml changes, not on every
# source code change.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw -B dependency:go-offline

# Tests are skipped here because the pipeline runs them as a separate stage
# before any image is built.
COPY src src
RUN ./mvnw -B package -DskipTests

# Stage 2: the image that actually runs. It contains only a Java runtime and the JAR.
FROM eclipse-temurin:17-jre
WORKDIR /app

# Run as an unprivileged user instead of root.
RUN useradd --system --no-create-home petclinic
USER petclinic

COPY --from=build /workspace/target/spring-petclinic-*.jar app.jar

# Size the Java heap from the container's memory limit rather than the host's memory.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"

# The application listens on 8080 inside the container. The host port
# (8081 for staging, 8082 for production) is chosen when the container is started.
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
