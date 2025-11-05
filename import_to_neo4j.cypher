// Neo4j Import Script for FoodData Central Foundation Foods
// This script uses APOC to load the JSON and create a knowledge graph
// that allows querying nutrient values by food or food category

// ============================================================
// STEP 1: Create Constraints and Indexes
// ============================================================

CREATE CONSTRAINT food_fdc_id IF NOT EXISTS
FOR (f:Food) REQUIRE f.fdcId IS UNIQUE;

CREATE CONSTRAINT nutrient_id IF NOT EXISTS
FOR (n:Nutrient) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT category_id IF NOT EXISTS
FOR (c:FoodCategory) REQUIRE c.id IS UNIQUE;

CREATE INDEX food_description IF NOT EXISTS
FOR (f:Food) ON (f.description);

CREATE INDEX nutrient_name IF NOT EXISTS
FOR (n:Nutrient) ON (n.name);

// ============================================================
// STEP 2: Load Foods and Create Food Category Nodes
// ============================================================

// Note: Replace 'file:///FoodData_Central_foundation_food_json_2025-04-24.json'
// with the appropriate path for your Neo4j installation.
// For local files, place the JSON in Neo4j's import directory.

CALL apoc.load.jsonArray('file:///FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods')
YIELD value AS food

// Create or merge Food Category
MERGE (fc:FoodCategory {id: food.foodCategory.id})
ON CREATE SET
  fc.code = food.foodCategory.code,
  fc.description = food.foodCategory.description

// Create Food node
CREATE (f:Food {fdcId: food.fdcId})
SET
  f.description = food.description,
  f.foodClass = food.foodClass,
  f.dataType = food.dataType,
  f.ndbNumber = food.ndbNumber,
  f.publicationDate = food.publicationDate

// Create relationship between Food and FoodCategory
CREATE (f)-[:BELONGS_TO]->(fc);

// ============================================================
// STEP 3: Create Nutrient Nodes and Relationships
// ============================================================

CALL apoc.load.jsonArray('file:///FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods')
YIELD value AS food

// Match the food node
MATCH (f:Food {fdcId: food.fdcId})

// Unwind nutrients array
UNWIND food.foodNutrients AS foodNutrient

// Create or merge Nutrient node
MERGE (n:Nutrient {id: foodNutrient.nutrient.id})
ON CREATE SET
  n.name = foodNutrient.nutrient.name,
  n.number = foodNutrient.nutrient.number,
  n.unitName = foodNutrient.nutrient.unitName,
  n.rank = foodNutrient.nutrient.rank

// Create relationship with nutrient amount
CREATE (f)-[r:HAS_NUTRIENT]->(n)
SET
  r.amount = toFloat(foodNutrient.amount),
  r.dataPoints = foodNutrient.dataPoints,
  r.derivationCode = foodNutrient.foodNutrientDerivation.code,
  r.derivationDescription = foodNutrient.foodNutrientDerivation.description,
  r.min = toFloat(foodNutrient.min),
  r.max = toFloat(foodNutrient.max),
  r.median = toFloat(foodNutrient.median);

// ============================================================
// QUERY EXAMPLES
// ============================================================

// Example 1: Find all nutrients for a specific food
// MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
// RETURN f.description AS Food, n.name AS Nutrient, r.amount AS Amount, n.unitName AS Unit
// ORDER BY n.rank;

// Example 2: Find average nutrient values for a food category
// MATCH (fc:FoodCategory {description: "Legumes and Legume Products"})<-[:BELONGS_TO]-(f:Food)
// MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
// RETURN fc.description AS Category,
//        n.name AS Nutrient,
//        AVG(r.amount) AS AvgAmount,
//        n.unitName AS Unit;

// Example 3: Find foods high in a specific nutrient
// MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
// WHERE r.amount > 10
// RETURN f.description AS Food, r.amount AS ProteinAmount, n.unitName AS Unit
// ORDER BY r.amount DESC
// LIMIT 10;

// Example 4: Find all nutrients for all foods in a category
// MATCH (fc:FoodCategory {description: "Vegetables and Vegetable Products"})<-[:BELONGS_TO]-(f:Food)
// MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient)
// RETURN f.description AS Food, n.name AS Nutrient, r.amount AS Amount, n.unitName AS Unit
// ORDER BY f.description, n.rank;

// Example 5: Compare nutrient profiles of two foods
// MATCH (f1:Food {description: "Hummus, commercial"})-[r1:HAS_NUTRIENT]->(n:Nutrient)<-[r2:HAS_NUTRIENT]-(f2:Food {description: "Beans, navy, mature seeds, raw"})
// RETURN n.name AS Nutrient,
//        r1.amount AS Food1Amount,
//        r2.amount AS Food2Amount,
//        n.unitName AS Unit
// ORDER BY n.rank;

// Example 6: Find foods by nutrient combination (high protein, low fat)
// MATCH (f:Food)-[rp:HAS_NUTRIENT]->(protein:Nutrient {name: "Protein"})
// MATCH (f)-[rf:HAS_NUTRIENT]->(fat:Nutrient {name: "Total lipid (fat)"})
// WHERE rp.amount > 20 AND rf.amount < 5
// RETURN f.description AS Food,
//        rp.amount AS ProteinAmount,
//        rf.amount AS FatAmount
// ORDER BY rp.amount DESC;
