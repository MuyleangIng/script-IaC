#!/bin/bash

# Function to check if a command exists
command_exists () {
    command -v "$1" >/dev/null 2>&1 ;
}

# Check if Java is installed
if ! command_exists java ; then
    echo "Java is not installed. Please install Java before running this script."
    exit 1
fi

# Check if Gradle is installed
if ! command_exists gradle ; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Function to create a Spring Boot project with Gradle
create_service() {
    SERVICE_NAME=$1
    DEPENDENCIES=$2

    mkdir $SERVICE_NAME
    cd $SERVICE_NAME || exit

    # Initialize the Gradle project
    gradle init --type java-application

    # Modify the build.gradle to include Spring Boot dependencies
    cat <<EOF > build.gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.0.0'
    id 'io.spring.dependency-management' version '1.0.15.RELEASE'
}

group = 'com.example'
version = '1.0.0'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

dependencies {
    $DEPENDENCIES
}

test {
    useJUnitPlatform()
}
EOF

    # Create the main application class
    PACKAGE_NAME="com.example.${SERVICE_NAME}"
    mkdir -p src/main/java/${PACKAGE_NAME//.//}

    cat <<EOF > src/main/java/${PACKAGE_NAME//.//}/Application.java
package $PACKAGE_NAME;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
EOF

    # Generate the application.properties file
    mkdir -p src/main/resources
    cat <<EOF > src/main/resources/application.properties
spring.application.name=$SERVICE_NAME
server.port=0
EOF

    cd ..
}

# Function to create a simple controller
create_controller() {
    SERVICE_NAME=$1
    PACKAGE_NAME="com.example.${SERVICE_NAME}"
    CONTROLLER_NAME=$2

    mkdir -p $SERVICE_NAME/src/main/java/${PACKAGE_NAME//.//}/controller

    cat <<EOF > $SERVICE_NAME/src/main/java/${PACKAGE_NAME//.//}/controller/${CONTROLLER_NAME}.java
package $PACKAGE_NAME.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ${CONTROLLER_NAME} {

    @GetMapping("/hello")
    public String sayHello() {
        return "Hello from $SERVICE_NAME!";
    }
}
EOF
}

# Create services

# 1. Spring Cloud Gateway
create_service "gateway-service" "implementation 'org.springframework.cloud:spring-cloud-starter-gateway'"

# 2. Spring Cloud Config Server
create_service "config-server" "implementation 'org.springframework.cloud:spring-cloud-config-server'"

# Create basic microservices
create_service "service1" "implementation 'org.springframework.boot:spring-boot-starter-web'"
create_service "service2" "implementation 'org.springframework.boot:spring-boot-starter-web'"
create_service "service3" "implementation 'org.springframework.boot:spring-boot-starter-web'"

# Create simple controllers for each service
create_controller "service1" "Service1Controller"
create_controller "service2" "Service2Controller"
create_controller "service3" "Service3Controller"

# Config Server application.properties setup
cat <<EOF > config-server/src/main/resources/application.properties
spring.application.name=config-server
server.port=8888
spring.profiles.active=native
spring.cloud.config.server.native.search-locations=classpath:/config
EOF

cat <<EOF > config-server/src/main/resources/bootstrap.properties
spring.cloud.config.server.git.uri=https://github.com/your-repo/config-repo
spring.cloud.config.server.git.clone-on-start=true
EOF

# Gateway application.properties setup
cat <<EOF > gateway-service/src/main/resources/application.properties
spring.application.name=gateway-service
server.port=8080

spring.cloud.gateway.routes[0].id=service1
spring.cloud.gateway.routes[0].uri=http://localhost:8081
spring.cloud.gateway.routes[0].predicates[0]=Path=/service1/**
spring.cloud.gateway.routes[0].filters[0]=StripPrefix=1

spring.cloud.gateway.routes[1].id=service2
spring.cloud.gateway.routes[1].uri=http://localhost:8082
spring.cloud.gateway.routes[1].predicates[0]=Path=/service2/**
spring.cloud.gateway.routes[1].filters[0]=StripPrefix=1

spring.cloud.gateway.routes[2].id=service3
spring.cloud.gateway.routes[2].uri=http://localhost:8083
spring.cloud.gateway.routes[2].predicates[0]=Path=/service3/**
spring.cloud.gateway.routes[2].filters[0]=StripPrefix=1

eureka.client.serviceUrl.defaultZone=http://localhost:8761/eureka/
EOF

echo "Spring Boot microservices have been created successfully."

echo "To run the services, navigate to each service directory and execute: gradle bootRun"