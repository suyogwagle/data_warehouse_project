/*
=============================================================
Create Schema
=============================================================
Script Purpose:
    This script creates three schemas — 'bronze', 'silver', and 'gold' — within 
    the 'datawarehouse' database, representing the medallion architecture layers 
    used throughout this project.

Prerequisites:
    Run this script only after 'datawarehouse' has been created (see 
    01_create_database.sql). Ensure your Query Tool connection is set to 
    'datawarehouse', not 'postgres', before executing.

Note:
    Uses IF NOT EXISTS so the script can be safely rerun without erroring out 
    if the schemas already exist.
*/

-- Create Schemas
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
