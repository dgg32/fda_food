# Troubleshooting Guide - Neo4j FoodData Central Import

## Issue: Null Property Error for FoodCategory.id

### Error Message
```
Cannot merge the following node because of null property value for 'id': (:FoodCategory {id: null})
```

### Root Cause
The original scripts were written assuming the `foodCategory` object had `id` and `code` fields, but in the actual data, it only contains a `description` field:

**Expected (incorrect):**
```json
{
  "foodCategory": {
    "id": 16,
    "code": "1600",
    "description": "Legumes and Legume Products"
  }
}
```

**Actual data:**
```json
{
  "foodCategory": {
    "description": "Legumes and Legume Products"
  }
}
```

### Solution
All scripts have been updated to use `description` as the unique identifier for FoodCategory nodes instead of `id`.

## How to Fix Your Database

### Option 1: Clean Up and Re-import (Recommended)

If you've already tried importing with the old scripts, you need to clean up first:

#### Using Cypher:
```bash
# Run the cleanup script
cat cleanup_neo4j.cypher | cypher-shell -u neo4j -p your_password

# Then run the corrected import
cat import_to_neo4j_optimized.cypher | cypher-shell -u neo4j -p your_password
```

#### Using Python:
```bash
# The Python script now automatically cleans up before importing
python3 import_with_python.py
```

The Python script will:
1. Clean up existing data and constraints
2. Create new correct constraints
3. Import all data
4. Verify the import

### Option 2: Manual Cleanup in Neo4j Browser

If you prefer to clean up manually:

```cypher
// 1. Delete all relationships
MATCH ()-[r]->()
DELETE r;

// 2. Delete all nodes
MATCH (n)
DELETE n;

// 3. Drop old incorrect constraint
DROP CONSTRAINT category_id IF EXISTS;

// 4. Drop other constraints (they'll be recreated)
DROP CONSTRAINT food_fdc_id IF EXISTS;
DROP CONSTRAINT nutrient_id IF EXISTS;

// 5. Drop indexes
DROP INDEX food_description IF EXISTS;
DROP INDEX nutrient_name IF EXISTS;

// 6. Verify cleanup
MATCH (n) RETURN COUNT(n) AS RemainingNodes;
```

Then run the corrected import script.

## Issue: No Relationships Created

### Symptom
After running the import, you have Food, Nutrient, and FoodCategory nodes, but no relationships between them.

### Possible Causes

1. **Wrong constraint on FoodCategory**: If the old constraint on `category_id` exists, the MERGE operations fail silently
2. **Transaction timeout**: For large imports, relationships might not be created due to timeout
3. **APOC not configured correctly**: The `apoc.load.jsonArray` might not be working

### Solutions

#### 1. Check for Old Constraints
```cypher
SHOW CONSTRAINTS;
```

If you see `category_id` constraint, drop it:
```cypher
DROP CONSTRAINT category_id;
```

#### 2. Verify APOC is Working
```cypher
RETURN apoc.version();
```

If this fails, APOC is not installed or enabled.

#### 3. Use the Optimized Script
The optimized script uses batching which is more reliable:
```bash
cat import_to_neo4j_optimized.cypher | cypher-shell -u neo4j -p your_password
```

#### 4. Use the Python Script
The Python script is more robust and provides better error messages:
```bash
python3 import_with_python.py
```

## Verification After Import

After a successful import, verify your data:

```cypher
// Count nodes
MATCH (f:Food) RETURN COUNT(f) AS Foods;
// Expected: 340

MATCH (n:Nutrient) RETURN COUNT(n) AS Nutrients;
// Expected: ~150

MATCH (fc:FoodCategory) RETURN COUNT(fc) AS Categories;
// Expected: 19

// Count relationships
MATCH ()-[r:HAS_NUTRIENT]->() RETURN COUNT(r) AS NutrientRelationships;
// Expected: ~40,000

MATCH ()-[r:BELONGS_TO]->() RETURN COUNT(r) AS CategoryRelationships;
// Expected: 340

// Test a query
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN n.name, r.amount, n.unitName
LIMIT 5;
```

## Common Issues

### Issue: "File not found" Error

**Error:**
```
Couldn't load file: file:///FoodData_Central_foundation_food_json_2025-04-24.json
```

**Solution:**
1. Copy the JSON file to Neo4j's import directory:
   ```bash
   sudo cp FoodData_Central_foundation_food_json_2025-04-24.json /var/lib/neo4j/import/
   ```

2. Or use an HTTP URL in the script

### Issue: APOC Not Available

**Error:**
```
Unknown procedure: apoc.load.jsonArray
```

**Solution:**
1. Download APOC from https://neo4j.com/labs/apoc/
2. Place `apoc-*.jar` in `plugins/` directory
3. Edit `neo4j.conf`:
   ```
   dbms.security.procedures.unrestricted=apoc.*
   ```
4. Restart Neo4j

### Issue: Out of Memory

**Error:**
```
OutOfMemoryError: Java heap space
```

**Solution:**
Edit `neo4j.conf`:
```
dbms.memory.heap.initial_size=2g
dbms.memory.heap.max_size=4g
```

Then restart Neo4j.

### Issue: Python Driver Not Installed

**Error:**
```
ModuleNotFoundError: No module named 'neo4j'
```

**Solution:**
```bash
pip install neo4j
```

## Getting Help

If you continue to have issues:

1. Check Neo4j logs:
   ```bash
   tail -f /var/lib/neo4j/logs/neo4j.log
   ```

2. Run the Python script for better error messages

3. Verify your data structure:
   ```bash
   python3 << 'EOF'
   import json
   with open('FoodData_Central_foundation_food_json_2025-04-24.json', 'r') as f:
       data = json.load(f)
   print("Number of foods:", len(data['FoundationFoods']))
   print("First food category:", data['FoundationFoods'][0].get('foodCategory'))
   EOF
   ```

## Summary of Changes

The corrected scripts now:
- ✅ Use `description` as the unique identifier for FoodCategory
- ✅ Don't try to set `id` or `code` on FoodCategory (since they don't exist in the data)
- ✅ Include cleanup functionality to remove old incorrect data
- ✅ Provide better error messages and verification

All three import methods (basic Cypher, optimized Cypher, and Python) have been updated and tested.
