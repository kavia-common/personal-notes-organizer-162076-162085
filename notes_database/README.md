# notes_database

The MySQL database container for the Personal Notes Organizer. Refer to the workspace-level README one directory up for complete setup and run instructions. The key entry points are:
- startup.sh: starts MySQL on port 5000 and applies schema.sql
- schema.sql: creates users and notes tables
- db_connection.txt: generated connection helper
- db_visualizer/: optional Node-based database viewer

Quick start:
- bash startup.sh
- Use the printed mysql command in db_connection.txt to connect

For health checks and ports summary, see the parent README (personal-notes-organizer-162076-162085/README.md).
