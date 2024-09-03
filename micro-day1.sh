#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Gradle is installed
if ! command_exists gradle; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Create parent directory
mkdir -p microservices-demo
cd microservices-demo

# Function to create a basic Spring Boot project
create_project() {
    local project_name=$1
    local main_class=$2
    local dependencies=$3

    mkdir -p "${project_name}"
    cd "${project_name}"

    # Create build.gradle
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
    ${dependencies}
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:\${springCloudVersion}"
    }
}

tasks.named('test') {
    useJUnitPlatform()
}
EOF

    # Create main application class
    mkdir -p src/main/java/com/example/${project_name//-/}
    cat << EOF > src/main/java/com/example/${project_name//-/}/${main_class}.java
package com.example.${project_name//-/};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${main_class} {
    public static void main(String[] args) {
        SpringApplication.run(${main_class}.class, args);
    }
}
EOF

    mkdir -p src/main/resources
    touch src/main/resources/application.properties

    cd ..
}

# Create Eureka Server
create_project "eureka-server" "EurekaServerApplication" "implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'"

# Configure Eureka Server
cat << EOF > eureka-server/src/main/resources/application.properties
server.port=8761
eureka.client.register-with-eureka=false
eureka.client.fetch-registry=false
spring.application.name=eureka-server
EOF

# Add @EnableEurekaServer annotation
sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;\
\
@EnableEurekaServer' eureka-server/src/main/java/com/example/eurekaserver/EurekaServerApplication.java
rm eureka-server/src/main/java/com/example/eurekaserver/EurekaServerApplication.java.bak

# Create Config Server
create_project "config-server" "ConfigServerApplication" "implementation 'org.springframework.cloud:spring-cloud-config-server'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'"

# Configure Config Server
cat << EOF > config-server/src/main/resources/application.properties
server.port=8888
spring.application.name=config-server
spring.cloud.config.server.git.uri=https://github.com/your-config-repo.git
spring.cloud.config.server.git.default-label=main
eureka.client.serviceUrl.defaultZone=http://localhost:8761/eureka/
EOF

# Add @EnableConfigServer and @EnableDiscoveryClient annotations
sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.config.server.EnableConfigServer;\
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;\
\
@EnableConfigServer\
@EnableDiscoveryClient' config-server/src/main/java/com/example/configserver/ConfigServerApplication.java
rm config-server/src/main/java/com/example/configserver/ConfigServerApplication.java.bak

# Create Gateway Service
create_project "gateway-service" "GatewayApplication" "implementation 'org.springframework.cloud:spring-cloud-starter-gateway'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    implementation 'org.springframework.cloud:spring-cloud-starter-config'"

# Configure Gateway Service
cat << EOF > gateway-service/src/main/resources/application.properties
server.port=8080
spring.application.name=gateway-service
spring.cloud.gateway.discovery.locator.enabled=true
spring.cloud.gateway.discovery.locator.lower-case-service-id=true
spring.config.import=optional:configserver:http://localhost:8888
eureka.client.serviceUrl.defaultZone=http://localhost:8761/eureka/
management.endpoints.web.exposure.include=*
EOF

# Add @EnableDiscoveryClient annotation
sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;\
\
@EnableDiscoveryClient' gateway-service/src/main/java/com/example/gatewayservice/GatewayApplication.java
rm gateway-service/src/main/java/com/example/gatewayservice/GatewayApplication.java.bak

echo "Microservices infrastructure has been set up successfully."
echo "To build the projects, navigate to each directory and run: gradle build"
echo "To run the applications, use: gradle bootRun"
echo "Start the services in this order: Eureka Server, Config Server, Gateway Service"