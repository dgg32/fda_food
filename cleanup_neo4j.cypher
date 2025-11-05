// Cleanup script to remove all nodes and relationships before re-import
// Use this if you need to start fresh

// WARNING: This will delete ALL data in your database
// Only run this if you're sure you want to clear everything!

// Delete all relationships first
MATCH ()-[r]->()
DELETE r;

// Delete all nodes
MATCH (n)
DELETE n;

// Drop constraints (they will be recreated during import)
DROP CONSTRAINT food_fdc_id IF EXISTS;
DROP CONSTRAINT nutrient_id IF EXISTS;
DROP CONSTRAINT category_description IF EXISTS;
DROP CONSTRAINT category_id IF EXISTS;  // Drop old incorrect constraint if it exists

// Drop indexes
DROP INDEX food_description IF EXISTS;
DROP INDEX nutrient_name IF EXISTS;

// Verify cleanup
MATCH (n) RETURN COUNT(n) AS RemainingNodes;
MATCH ()-[r]->() RETURN COUNT(r) AS RemainingRelationships;
