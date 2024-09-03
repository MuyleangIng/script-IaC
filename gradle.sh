#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Gradle is installed
if ! command_exists gradle; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Create project directory
mkdir -p gateway-service/src/main/java/com/example/gateway
cd gateway-service || exit

# Create build.gradle file
cat << EOF > build.gradle
plugins {
    id 'org.springframework.boot' version '3.1.0'
    id 'io.spring.dependency-management' version '1.1.0'
    id 'java'
}

group = 'com.example'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

ext {
    set('springCloudVersion', "2022.0.3")
}

dependencies {
    implementation 'org.springframework.cloud:spring-cloud-starter-gateway'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}

tasks.named('test') {
    useJUnitPlatform()
}
EOF

# Create settings.gradle file
echo "rootProject.name = 'gateway-service'" > settings.gradle

# Create application.yml
mkdir -p src/main/resources
cat << EOF > src/main/resources/application.yml
server:
  port: 8080

spring:
  application:
    name: gateway-service
  cloud:
    gateway:
      discovery:
        locator:
          enabled: true
      routes:
        - id: example-service
          uri: lb://EXAMPLE-SERVICE
          predicates:
            - Path=/api/**

eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/
  instance:
    preferIpAddress: true

management:
  endpoints:
    web:
      exposure:
        include: "*"
EOF

# Create main application class
cat << EOF > src/main/java/com/example/gateway/GatewayApplication.java
package com.example.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
@EnableDiscoveryClient
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
EOF

echo "Gateway service project has been created successfully."
echo "To build the project, run: gradle build"
echo "To run the application, use: gradle bootRun"