# --- Aşama 1: Derleme Ortamı ---
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /usr/src/app

# Build context'imiz artık proje kökü olduğu için,
# kopyalanacak dosyaların tam yolunu belirtiyoruz.
COPY backend/identity-java/pom.xml .
RUN mvn dependency:go-offline

COPY backend/identity-java/src ./src

RUN mvn package -DskipTests

# --- Aşama 2: Çalıştırma Ortamı ---
FROM eclipse-temurin:17-jre-jammy
WORKDIR /deployments
COPY --from=build /usr/src/app/target/quarkus-app/ ./
EXPOSE 8080
CMD ["java", "-jar", "quarkus-run.jar"]