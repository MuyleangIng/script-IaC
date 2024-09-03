#!/bin/bash

set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Gradle is installed
if ! command_exists gradle; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Create project structure
mkdir -p microservices-demo
cd microservices-demo

# Create README.md
cat << EOF > README.md
# Microservices Demo with Config Server and PostgreSQL

This project sets up a microservices infrastructure using Spring Boot, Spring Cloud Config, and PostgreSQL.

## Services

1. Eureka Server (Discovery Service)
2. Config Server (using GitHub)
3. API Gateway
4. User Service (with PostgreSQL)

## Setup

1. Ensure Java 17, Gradle, and PostgreSQL are installed on your system.
2. Create a GitHub repository for your configurations and update the Config Server's application.yml with your repository URL.
3. Create a PostgreSQL database named 'userdb'.
4. Run each service: \`./gradlew bootRun\`

Start the services in this order:
1. Eureka Server
2. Config Server
3. API Gateway
4. User Service

## Testing

To test the setup:

1. Check Eureka Dashboard: http://localhost:8761
2. Test User Service via API Gateway: 
   - Create user: POST http://localhost:8080/user-service/users
   - Get users: GET http://localhost:8080/user-service/users

EOF

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
    id 'org.springframework.boot' version '3.1.3'
    id 'io.spring.dependency-management' version '1.1.3'
    id 'java'
}

group = 'com.example'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

ext {
    set('springCloudVersion', "2022.0.4")
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
    touch src/main/resources/application.yml

    cd ..
}

# Create Eureka Server
create_project "eureka-server" "EurekaDiscoveryServer" "implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'"

# Create Config Server
create_project "config-server" "ConfigServerApplication" "implementation 'org.springframework.cloud:spring-cloud-config-server'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'"

# Create API Gateway
create_project "api-gateway" "ApiGatewayApplication" "implementation 'org.springframework.cloud:spring-cloud-starter-gateway'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    implementation 'org.springframework.cloud:spring-cloud-starter-config'"

# Create User Service
create_project "user-service" "UserServiceApplication" "implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    implementation 'org.springframework.cloud:spring-cloud-starter-config'
    implementation 'org.postgresql:postgresql'"

# Configure Eureka Server
cat << EOF > eureka-server/src/main/resources/application.yml
spring:
  application:
    name: eureka-server
  profiles:
    active: dev
server:
  port: 8761

eureka:
  instance:
    hostname: localhost
  client:
    registerWithEureka: false
    fetchRegistry: false
    serviceUrl:
      defaultZone: http://\${eureka.instance.hostname}:\${server.port}/eureka/
  server:
    waitTimeInMsWhenSyncEmpty: 0
    response-cache-update-interval-ms: 5000

management:
  endpoints:
    web:
      exposure:
        include: '*'
EOF

# Configure Config Server
cat << EOF > config-server/src/main/resources/application.yml
server:
  port: 8888

spring:
  application:
    name: config-server
  profiles:
    active: git
  cloud:
    config:
      server:
        git:
          uri: https://github.com/YourUsername/config-repo.git
          default-label: main
          clone-on-start: true

eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/
EOF

# Configure API Gateway
cat << EOF > api-gateway/src/main/resources/application.yml
server:
  port: 8080

spring:
  application:
    name: api-gateway
  cloud:
    gateway:
      discovery:
        locator:
          enabled: true
          lower-case-service-id: true
  config:
    import: optional:configserver:http://localhost:8888

eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/
EOF

# Configure User Service
cat << EOF > user-service/src/main/resources/application.yml
server:
  port: 8081

spring:
  application:
    name: user-service
  config:
    import: optional:configserver:http://localhost:8888
  datasource:
    url: jdbc:postgresql://localhost:5432/userdb
    username: admin
    password: admin@123
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/
EOF

# Update main application classes
sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;\
\
@EnableEurekaServer' eureka-server/src/main/java/com/example/eurekaserver/EurekaDiscoveryServer.java
rm eureka-server/src/main/java/com/example/eurekaserver/EurekaDiscoveryServer.java.bak

sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.config.server.EnableConfigServer;\
\
@EnableConfigServer' config-server/src/main/java/com/example/configserver/ConfigServerApplication.java
rm config-server/src/main/java/com/example/configserver/ConfigServerApplication.java.bak

# Add User entity and repository to User Service
cat << EOF > user-service/src/main/java/com/example/userservice/User.java
package com.example.userservice;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String email;

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
}
EOF

cat << EOF > user-service/src/main/java/com/example/userservice/UserRepository.java
package com.example.userservice;

import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {
}
EOF

# Add a controller to User Service
cat << EOF > user-service/src/main/java/com/example/userservice/UserController.java
package com.example.userservice;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/users")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @PostMapping
    public User createUser(@RequestBody User user) {
        return userRepository.save(user);
    }

    @GetMapping
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
}
EOF

echo "Microservices infrastructure with Config Server and PostgreSQL support has been set up successfully."
echo "Please refer to README.md for instructions on how to run and test the services."
echo "Don't forget to update the Config Server's GitHub repository URL and PostgreSQL credentials before running the services."