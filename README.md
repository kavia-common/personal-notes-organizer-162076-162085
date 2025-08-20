# Notes Database (MySQL)

This folder contains scripts and assets to run a local MySQL database for the Personal Notes Organizer application. It provisions the schema for users and notes and exposes MySQL on port 5000 by default.

Contents:
- notes_database/startup.sh: idempotent setup for MySQL, users, and schema
- notes_database/schema.sql: DDL for users and notes tables, including indexes
- notes_database/db_connection.txt: generated helper command to connect
- notes_database/db_visualizer/: optional Node-based DB viewer

Requirements:
- Linux environment with sudo to start mysqld (or an existing MySQL instance you manage yourself)
- MySQL 8.x (mysqld available)

Quick start:
1) Start MySQL and apply schema
   - cd personal-notes-organizer-162076-162085/notes_database
   - bash startup.sh
   The script will:
     - Start MySQL on port 5000
     - Set root password to dbuser123
     - Create DB myapp
     - Create app user appuser/dbuser123 with privileges to myapp
     - Apply schema.sql idempotently
     - Write a connection command to db_connection.txt
     - Generate a mysql.env file for the optional DB viewer

2) Connect to the DB
   - cat db_connection.txt
   - Example: mysql -u appuser -pdbuser123 -h localhost -P 5000 myapp

3) Optional DB viewer (multi-DB simple explorer)
   - source db_visualizer/mysql.env
   - cd db_visualizer && npm install && npm start
   - Open http://localhost:3000
   - Endpoints:
     - GET /api/databases
     - GET /api/mysql/tables
     - GET /api/mysql/tables/:table/data?limit=50

Ports:
- MySQL: 5000 (TCP)
- DB Viewer (optional): 3000 (HTTP)

Health/validation checks:
- Verify MySQL is accepting connections:
  - mysql -u appuser -pdbuser123 -h localhost -P 5000 -e "SELECT 1;" myapp
- Check that tables exist:
  - mysql -u appuser -pdbuser123 -h localhost -P 5000 -e "SHOW TABLES;" myapp
- For the viewer:
  - curl http://localhost:3000/api/databases

Notes for backend integration:
- Backend .env should reference:
    DB_HOST=127.0.0.1
    DB_PORT=5000
    DB_NAME=myapp
    DB_USER=appuser
    DB_PASSWORD=dbuser123

Minimal E2E test (DB perspective):
- After the backend is running and you register/login/create notes via the frontend, you can:
  - SELECT * FROM users;
  - SELECT * FROM notes;
  to confirm data is being written as expected.

Sources:
- schema and startup: notes_database/schema.sql, notes_database/startup.sh
- viewer: notes_database/db_visualizer/*
