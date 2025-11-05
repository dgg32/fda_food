// Optimized Neo4j Import Script for FoodData Central Foundation Foods
// This version uses batching for better performance with large datasets

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
// STEP 2: Pre-create all Nutrients (from first pass)
// This improves performance by avoiding MERGE in the main loop
// ============================================================

CALL apoc.load.jsonArray('file:///FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods')
YIELD value AS food
UNWIND food.foodNutrients AS foodNutrient
WITH DISTINCT foodNutrient.nutrient AS nutrient
MERGE (n:Nutrient {id: nutrient.id})
ON CREATE SET
  n.name = nutrient.name,
  n.number = nutrient.number,
  n.unitName = nutrient.unitName,
  n.rank = nutrient.rank;

// ============================================================
// STEP 3: Load Foods and Create Food Categories (Batched)
// ============================================================

CALL apoc.periodic.iterate(
  "CALL apoc.load.jsonArray('file:///FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods') YIELD value AS food RETURN food",
  "
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
  CREATE (f)-[:BELONGS_TO]->(fc)
  ",
  {batchSize: 100, parallel: false}
);

// ============================================================
// STEP 4: Create Nutrient Relationships (Batched)
// ============================================================

CALL apoc.periodic.iterate(
  "CALL apoc.load.jsonArray('file:///FoodData_Central_foundation_food_json_2025-04-24.json', '$.FoundationFoods') YIELD value AS food RETURN food",
  "
  // Match the food node
  MATCH (f:Food {fdcId: food.fdcId})

  // Process nutrients
  WITH f, food.foodNutrients AS nutrients
  UNWIND nutrients AS foodNutrient

  // Match existing Nutrient node (pre-created in Step 2)
  MATCH (n:Nutrient {id: foodNutrient.nutrient.id})

  // Create relationship with nutrient amount
  CREATE (f)-[r:HAS_NUTRIENT]->(n)
  SET
    r.amount = toFloat(foodNutrient.amount),
    r.dataPoints = foodNutrient.dataPoints,
    r.derivationCode = foodNutrient.foodNutrientDerivation.code,
    r.derivationDescription = foodNutrient.foodNutrientDerivation.description,
    r.min = toFloat(foodNutrient.min),
    r.max = toFloat(foodNutrient.max),
    r.median = toFloat(foodNutrient.median)
  ",
  {batchSize: 50, parallel: false}
);

// ============================================================
// STEP 5: Verify Import
// ============================================================

// Count nodes
MATCH (f:Food) WITH COUNT(f) AS foodCount
MATCH (n:Nutrient) WITH foodCount, COUNT(n) AS nutrientCount
MATCH (fc:FoodCategory) WITH foodCount, nutrientCount, COUNT(fc) AS categoryCount
MATCH ()-[r:HAS_NUTRIENT]->() WITH foodCount, nutrientCount, categoryCount, COUNT(r) AS nutrientRels
MATCH ()-[r2:BELONGS_TO]->() WITH foodCount, nutrientCount, categoryCount, nutrientRels, COUNT(r2) AS categoryRels
RETURN
  foodCount AS Foods,
  nutrientCount AS Nutrients,
  categoryCount AS Categories,
  nutrientRels AS NutrientRelationships,
  categoryRels AS CategoryRelationships;
