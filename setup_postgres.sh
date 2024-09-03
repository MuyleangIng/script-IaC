#!/bin/bash

# Create a new directory for the project
mkdir postgres_docker_setup
cd postgres_docker_setup

# Create docker-compose.yml file
cat << EOF > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:14
    container_name: postgres-db
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin@123
      POSTGRES_DB: userdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
EOF

# Create init.sql file with 10 sample records
cat << EOF > init.sql
CREATE SEQUENCE user_id_seq;

CREATE TABLE users (
    id    bigint DEFAULT nextval('user_id_seq'::regclass) NOT NULL
        CONSTRAINT user_pkey PRIMARY KEY,
    name  varchar(255) NOT NULL,
    email varchar(255) NOT NULL
);

ALTER TABLE users OWNER TO admin;

-- Insert 10 sample records
INSERT INTO users (name, email) VALUES
('John Doe', 'john.doe@example.com'),
('Jane Smith', 'jane.smith@example.com'),
('Alice Johnson', 'alice.johnson@example.com'),
('Bob Williams', 'bob.williams@example.com'),
('Charlie Brown', 'charlie.brown@example.com'),
('Diana Davis', 'diana.davis@example.com'),
('Edward Evans', 'edward.evans@example.com'),
('Fiona Foster', 'fiona.foster@example.com'),
('George Green', 'george.green@example.com'),
('Hannah Harris', 'hannah.harris@example.com');
EOF

# Run Docker Compose
docker-compose up -d

echo "PostgreSQL Docker setup complete. Container is running in the background."
echo "You can connect to the database using:"
echo "Host: localhost"
echo "Port: 5432"
echo "Database: userdb"
echo "Username: admin"
echo "Password: admin@123"
echo "The database has been initialized with 10 sample user records."