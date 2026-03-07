#!/bin/bash

# Auto-initialization script for DVWA
# This script will:
# 1. Wait for the database to be ready
# 2. Check if database is initialized
# 3. If not, auto-initialize the database

set -e

# Function to check if database is ready
wait_for_db() {
    echo "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if mysqladmin ping -h"${DB_SERVER}" -u"${DB_USER}" -p"${DB_PASSWORD}" --ssl=0 --silent 2>/dev/null; then
            echo "Database is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: Database not ready yet, waiting..."
        sleep 2
    done

    echo "ERROR: Database did not become ready in time"
    exit 1
}

# Function to check if database is initialized
is_db_initialized() {
    local result=$(mysql -h"${DB_SERVER}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_DATABASE}" --ssl=0 -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_DATABASE}' AND table_name='users';" 2>/dev/null)
    [ "$result" = "1" ]
}

# Function to initialize database via PHP script
init_database() {
    echo "Database not initialized. Running setup..."

    # Create a temporary PHP script to run the setup
    cat > /tmp/setup_db.php <<'EOFPHP'
<?php
define( 'DVWA_WEB_PAGE_TO_ROOT', '/var/www/html/' );

// Load config
require_once DVWA_WEB_PAGE_TO_ROOT . 'config/config.inc.php';

// Set up database connection
if( !@($GLOBALS["___mysqli_ston"] = mysqli_connect( $_DVWA[ 'db_server' ],  $_DVWA[ 'db_user' ],  $_DVWA[ 'db_password' ], "", $_DVWA[ 'db_port' ] )) ) {
    die("Could not connect to the database service.\n");
}

// Create database
$drop_db = "DROP DATABASE IF EXISTS {$_DVWA[ 'db_database' ]};";
if( !@mysqli_query($GLOBALS["___mysqli_ston"],  $drop_db ) ) {
    die("Could not drop existing database\n");
}

$create_db = "CREATE DATABASE {$_DVWA[ 'db_database' ]};";
if( !@mysqli_query($GLOBALS["___mysqli_ston"],  $create_db ) ) {
    die("Could not create database\n");
}
echo "Database has been created.\n";

// Create table 'users'
if( !@((bool)mysqli_query($GLOBALS["___mysqli_ston"], "USE " . $_DVWA[ 'db_database' ])) ) {
    die("Could not connect to database.\n");
}

$create_tb = "CREATE TABLE users (user_id int(6),first_name varchar(15),last_name varchar(15), user varchar(15), password varchar(32),avatar varchar(70), last_login TIMESTAMP, failed_login INT(3), PRIMARY KEY (user_id));";
if( !mysqli_query($GLOBALS["___mysqli_ston"],  $create_tb ) ) {
    die("Table could not be created\n");
}
echo "'users' table was created.\n";

// Insert some data into users
$base_dir= "/";
$avatarUrl  = $base_dir . 'hackable/users/';

$insert = "INSERT INTO users VALUES
    ('1','admin','admin','admin',MD5('password'),'{$avatarUrl}admin.jpg', NOW(), '0'),
    ('2','Gordon','Brown','gordonb',MD5('abc123'),'{$avatarUrl}gordonb.jpg', NOW(), '0'),
    ('3','Hack','Me','1337',MD5('charley'),'{$avatarUrl}1337.jpg', NOW(), '0'),
    ('4','Pablo','Picasso','pablo',MD5('letmein'),'{$avatarUrl}pablo.jpg', NOW(), '0'),
    ('5','Bob','Smith','smithy',MD5('password'),'{$avatarUrl}smithy.jpg', NOW(), '0');";
if( !mysqli_query($GLOBALS["___mysqli_ston"],  $insert ) ) {
    die("Data could not be inserted into 'users' table\n");
}
echo "Data inserted into 'users' table.\n";

// Add role column to users table
$alter_users = "ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'user';";
if( !mysqli_query($GLOBALS["___mysqli_ston"], $alter_users) ) {
    // Ignore error for older MySQL versions that don't support IF NOT EXISTS
}
echo "Added role column to users table.\n";

// Set admin user role
$update_admin = "UPDATE users SET role = 'admin' WHERE user = 'admin';";
if( !mysqli_query($GLOBALS["___mysqli_ston"], $update_admin) ) {
    // Ignore error
}
echo "Updated admin user role.\n";

// Create access_log table
$create_access_log = "CREATE TABLE access_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    target_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (target_id) REFERENCES users(user_id)
) ENGINE=InnoDB;";

if( !mysqli_query($GLOBALS["___mysqli_ston"], $create_access_log) ) {
    die("Could not create access_log table\n");
}
echo "'access_log' table was created.\n";

// Create security_log table
$create_security_log = "CREATE TABLE security_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    target_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (target_id) REFERENCES users(user_id)
) ENGINE=InnoDB;";

if( !mysqli_query($GLOBALS["___mysqli_ston"], $create_security_log) ) {
    die("Could not create security_log table\n");
}
echo "'security_log' table was created.\n";

// Create guestbook table
$create_tb_guestbook = "CREATE TABLE guestbook (comment_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT, comment varchar(300), name varchar(100), PRIMARY KEY (comment_id));";
if( !mysqli_query($GLOBALS["___mysqli_ston"],  $create_tb_guestbook) ) {
    die("Table could not be created\n");
}
echo "'guestbook' table was created.\n";

// Insert data into 'guestbook'
$insert = "INSERT INTO guestbook VALUES ('1','This is a test comment.','test');";
if( !mysqli_query($GLOBALS["___mysqli_ston"], $insert) ) {
    die("Data could not be inserted into 'guestbook' table\n");
}
echo "Data inserted into 'guestbook' table.\n";

// Copy .bak for a fun directory listing vuln
$conf = DVWA_WEB_PAGE_TO_ROOT . 'config/config.inc.php';
$bakconf = DVWA_WEB_PAGE_TO_ROOT . 'config/config.inc.php.bak';
if (file_exists($conf)) {
    @copy($conf, $bakconf);
}
echo "Backup file /config/config.inc.php.bak automatically created\n";

// Add account_enabled columns to users table
$alter_users_dept = "ALTER TABLE users
    ADD COLUMN IF NOT EXISTS account_enabled TINYINT(1) DEFAULT 1;";
if( !mysqli_query($GLOBALS["___mysqli_ston"], $alter_users_dept) ) {
    // Ignore error for older MySQL versions
}
echo "Added account_enabled columns to users table.\n";

echo "Setup successful!\n";
?>
EOFPHP

    php /tmp/setup_db.php
    rm /tmp/setup_db.php
}

# Main execution
echo "=== DVWA Auto-Initialization Script ==="

# Wait for database to be ready
wait_for_db

# Check if database is already initialized
if is_db_initialized; then
    echo "Database is already initialized. Skipping setup."
else
    # Initialize database
    init_database
fi

echo "=== Initialization Complete ==="
echo "Starting Apache..."

# Execute the main command (apache-foreground)
exec "$@"
