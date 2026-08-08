/*
=============================================================
Create Database
=============================================================
Script Purpose:
    This script creates a new database named 'datawarehouse' after checking if it already exists.
    If the database exists, it is dropped and recreated.

WARNING:
    Running this script will drop the entire 'datawarehouse' database if it exists.
    All data in the database will be permanently deleted. Proceed with caution
    and ensure you have proper backups before running this script.
*/

-- Drop and recreate the 'datawarehouse' database
DROP DATABASE IF EXISTS datawarehouse WITH (FORCE);

-- Create the 'datawarehouse' database
CREATE DATABASE datawarehouse;
