# Neo4j Knowledge Graph for FoodData Central

This repository contains scripts to import FoodData Central foundation foods into a Neo4j knowledge graph.

## Knowledge Graph Schema

### Nodes
- **Food**: Individual food items with properties like `fdcId`, `description`, `foodClass`
- **FoodCategory**: Food categories with `description` (19 unique categories)
- **Nutrient**: Nutrients with `id`, `name`, `number`, `unitName`, and `rank`

### Relationships
- `(Food)-[:BELONGS_TO]->(FoodCategory)`: Links foods to their categories
- `(Food)-[HAS_NUTRIENT]->(Nutrient)`: Links foods to nutrients with amount and metadata

The `HAS_NUTRIENT` relationship contains:
- `amount`: The nutrient value
- `dataPoints`: Number of data points used
- `min`, `max`, `median`: Statistical values
- `derivationCode` and `derivationDescription`: How the value was obtained

## Prerequisites

1. **Neo4j Database** (4.x or 5.x recommended)
2. **APOC Plugin** installed and enabled
   - Download from: https://neo4j.com/labs/apoc/
   - Place in `plugins/` directory
   - Add to `neo4j.conf`: `dbms.security.procedures.unrestricted=apoc.*`

## Installation Methods

### Method 1: Using Local File (Recommended)

1. Copy the JSON file to Neo4j's import directory:
   ```bash
   # Find your Neo4j import directory
   # Usually: /var/lib/neo4j/import/ or <NEO4J_HOME>/import/

   cp FoodData_Central_foundation_food_json_2025-04-24.json /var/lib/neo4j/import/
   ```

2. Run the Cypher script in Neo4j Browser or cypher-shell:
   ```bash
   cat import_to_neo4j.cypher | cypher-shell -u neo4j -p your_password
   ```

### Method 2: Using HTTP URL

If you host the JSON file on a web server, modify the script to use HTTP:

```cypher
CALL apoc.load.jsonArray('http://your-server.com/FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods')
```

### Method 3: Using Python Driver (Alternative)

For larger datasets or more control, see `import_with_python.py` (if needed).

## Import Process

The import script performs three steps:

1. **Create Constraints and Indexes**: Ensures data integrity and query performance
2. **Load Foods and Categories**: Creates Food and FoodCategory nodes
3. **Load Nutrients and Relationships**: Creates Nutrient nodes and HAS_NUTRIENT relationships

### Execution Time
- Expected time: 5-15 minutes for 340 foods with ~119 nutrients each
- Total nodes: ~340 foods + ~150 unique nutrients + ~30 categories
- Total relationships: ~40,000+ HAS_NUTRIENT relationships

## Example Queries

### 1. Find all nutrients for a specific food
```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN f.description AS Food,
       n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY n.rank;
```

### 2. Find average nutrient values for a food category
```cypher
MATCH (fc:FoodCategory {description: "Legumes and Legume Products"})<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
RETURN fc.description AS Category,
       n.name AS Nutrient,
       AVG(r.amount) AS AvgAmount,
       n.unitName AS Unit;
```

### 3. Find foods high in a specific nutrient
```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
WHERE r.amount > 10
RETURN f.description AS Food,
       r.amount AS ProteinAmount,
       n.unitName AS Unit
ORDER BY r.amount DESC
LIMIT 10;
```

### 4. Find all nutrients for foods in a category
```cypher
MATCH (fc:FoodCategory {description: "Vegetables and Vegetable Products"})<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN f.description AS Food,
       n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY f.description, n.rank;
```

### 5. Compare nutrient profiles of two foods
```cypher
MATCH (f1:Food {description: "Hummus, commercial"})-[r1:HAS_NUTRIENT]->(n:Nutrient)
      <-[r2:HAS_NUTRIENT]-(f2:Food {description: "Beans, navy, mature seeds, raw"})
RETURN n.name AS Nutrient,
       r1.amount AS Food1Amount,
       r2.amount AS Food2Amount,
       n.unitName AS Unit
ORDER BY n.rank;
```

### 6. Find foods by nutrient criteria (high protein, low fat)
```cypher
MATCH (f:Food)-[rp:HAS_NUTRIENT]->(protein:Nutrient {name: "Protein"})
MATCH (f)-[rf:HAS_NUTRIENT]->(fat:Nutrient {name: "Total lipid (fat)"})
WHERE rp.amount > 20 AND rf.amount < 5
RETURN f.description AS Food,
       rp.amount AS ProteinAmount,
       rf.amount AS FatAmount
ORDER BY rp.amount DESC;
```

### 7. Get all food categories
```cypher
MATCH (fc:FoodCategory)
RETURN fc.description AS Category
ORDER BY fc.description;
```

### 8. Count foods per category
```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
RETURN fc.description AS Category,
       COUNT(f) AS FoodCount
ORDER BY FoodCount DESC;
```

## Verification Queries

After import, verify the data:

```cypher
// Count nodes
MATCH (f:Food) RETURN COUNT(f) AS FoodCount;
MATCH (n:Nutrient) RETURN COUNT(n) AS NutrientCount;
MATCH (fc:FoodCategory) RETURN COUNT(fc) AS CategoryCount;

// Count relationships
MATCH ()-[r:HAS_NUTRIENT]->() RETURN COUNT(r) AS NutrientRelationships;
MATCH ()-[r:BELONGS_TO]->() RETURN COUNT(r) AS CategoryRelationships;

// Sample data
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN f.description, n.name, r.amount, n.unitName
LIMIT 10;
```

## Troubleshooting

### APOC Not Available
```
Error: Unknown procedure: apoc.load.jsonArray
```
**Solution**: Install APOC plugin and restart Neo4j

### File Not Found
```
Error: Couldn't load file
```
**Solution**: Ensure the JSON file is in Neo4j's import directory or use a full file path

### Memory Issues
If you encounter out-of-memory errors:
1. Increase Neo4j heap size in `neo4j.conf`:
   ```
   dbms.memory.heap.initial_size=2g
   dbms.memory.heap.max_size=4g
   ```
2. Process in smaller batches (modify the script to use LIMIT)

### Performance Optimization
For better performance:
1. Ensure indexes are created before loading data
2. Use `:auto USING PERIODIC COMMIT` for very large datasets
3. Monitor query execution with `PROFILE` or `EXPLAIN`

## Data Source

FoodData Central: https://fdc.nal.usda.gov/
- Dataset: Foundation Foods
- Date: 2025-04-24

## License

The FoodData Central data is public domain (USDA).
