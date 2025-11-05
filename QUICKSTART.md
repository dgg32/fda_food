# Quick Start Guide - Fixed Version

## What Was Wrong

The original scripts tried to use `foodCategory.id` which doesn't exist in your data.
Your JSON only has `foodCategory.description`.

## What's Fixed

✅ All scripts now use `description` as the unique identifier for FoodCategory
✅ Python script automatically cleans up old data before importing
✅ Added cleanup script for manual cleanup
✅ All documentation updated

## How to Import Now

### Option 1: Python Script (Recommended - Easiest)

```bash
# 1. Install Python driver if needed
pip install neo4j

# 2. Edit the script to set your password
nano import_with_python.py
# Change line 12: NEO4J_PASSWORD = "your_actual_password"

# 3. Run the import (it will auto-cleanup first)
python3 import_with_python.py
```

When prompted, type `yes` to proceed.

**Expected output:**
```
Foods:                    340
Nutrients:                ~150
Food Categories:          19
Nutrient Relationships:   ~40,000
Category Relationships:   340
```

### Option 2: Cypher Script (If you prefer)

```bash
# 1. Copy JSON to Neo4j import directory
sudo cp FoodData_Central_foundation_food_json_2025-04-24.json /var/lib/neo4j/import/

# 2. Clean up old data first
cat cleanup_neo4j.cypher | cypher-shell -u neo4j -p your_password

# 3. Run the optimized import
cat import_to_neo4j_optimized.cypher | cypher-shell -u neo4j -p your_password
```

## Test Your Import

Run this query in Neo4j Browser:

```cypher
// Should return nutrients for Hummus
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY n.rank
LIMIT 10;
```

If this works, you're all set! 🎉

## Common Queries

### Find all food categories
```cypher
MATCH (fc:FoodCategory)
RETURN fc.description AS Category
ORDER BY fc.description;
```

### Find high protein foods
```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
WHERE r.amount > 20
RETURN f.description AS Food, r.amount AS Protein_g
ORDER BY r.amount DESC;
```

### Get nutrients for a specific food
```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE f.description CONTAINS "Hummus"
RETURN n.name AS Nutrient, r.amount AS Amount, n.unitName AS Unit
ORDER BY n.rank
LIMIT 20;
```

### Average protein per category
```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
RETURN fc.description AS Category,
       ROUND(AVG(r.amount), 2) AS AvgProtein_g
ORDER BY AvgProtein_g DESC;
```

## More Examples

See `QUERY_EXAMPLES.md` for 20+ example queries!

## If Something Goes Wrong

See `TROUBLESHOOTING.md` for detailed help.

## Files Summary

- ✅ **import_with_python.py** - Python script (recommended, auto-cleanup)
- ✅ **import_to_neo4j_optimized.cypher** - Optimized Cypher (batched)
- ✅ **import_to_neo4j.cypher** - Basic Cypher (simple)
- ✅ **cleanup_neo4j.cypher** - Manual cleanup script
- 📖 **QUERY_EXAMPLES.md** - 20+ example queries
- 📖 **README_NEO4J_IMPORT.md** - Full documentation
- 🔧 **TROUBLESHOOTING.md** - Detailed troubleshooting guide
