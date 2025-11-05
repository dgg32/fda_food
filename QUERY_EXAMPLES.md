# Neo4j Query Examples - FoodData Central Knowledge Graph

## Quick Start Queries

### 1. Explore the Data

#### View all food categories
```cypher
MATCH (fc:FoodCategory)
RETURN fc.description AS Category
ORDER BY fc.description;
```

#### Count foods per category
```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
RETURN fc.description AS Category, COUNT(f) AS FoodCount
ORDER BY FoodCount DESC;
```

#### List all foods
```cypher
MATCH (f:Food)
RETURN f.fdcId, f.description
ORDER BY f.description
LIMIT 20;
```

---

## Nutrient Queries

### 2. Find Nutrients for a Specific Food

```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE f.description = "Hummus, commercial"
RETURN n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY n.rank
LIMIT 20;
```

### 3. Find Foods High in a Specific Nutrient

#### High protein foods (>20g per 100g)
```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE n.name = "Protein" AND r.amount > 20
RETURN f.description AS Food,
       r.amount AS Protein_g,
       n.unitName AS Unit
ORDER BY r.amount DESC;
```

#### High vitamin C foods
```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE n.name = "Vitamin C, total ascorbic acid" AND r.amount > 50
RETURN f.description AS Food,
       r.amount AS VitaminC_mg,
       n.unitName AS Unit
ORDER BY r.amount DESC;
```

### 4. Find Foods by Multiple Nutrient Criteria

#### High protein, low fat foods
```cypher
MATCH (f:Food)-[rp:HAS_NUTRIENT]->(protein:Nutrient {name: "Protein"})
MATCH (f)-[rf:HAS_NUTRIENT]->(fat:Nutrient {name: "Total lipid (fat)"})
WHERE rp.amount > 15 AND rf.amount < 5
RETURN f.description AS Food,
       rp.amount AS Protein_g,
       rf.amount AS Fat_g
ORDER BY rp.amount DESC;
```

#### Low calorie, high fiber foods
```cypher
MATCH (f:Food)-[re:HAS_NUTRIENT]->(energy:Nutrient {name: "Energy", unitName: "kcal"})
MATCH (f)-[rf:HAS_NUTRIENT]->(fiber:Nutrient {name: "Fiber, total dietary"})
WHERE re.amount < 100 AND rf.amount > 5
RETURN f.description AS Food,
       re.amount AS Calories_kcal,
       rf.amount AS Fiber_g
ORDER BY rf.amount DESC;
```

---

## Category-Based Queries

### 5. Average Nutrient Values by Category

#### Average protein per food category
```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
RETURN fc.description AS Category,
       ROUND(AVG(r.amount), 2) AS AvgProtein_g,
       ROUND(MIN(r.amount), 2) AS MinProtein_g,
       ROUND(MAX(r.amount), 2) AS MaxProtein_g,
       COUNT(f) AS FoodCount
ORDER BY AvgProtein_g DESC;
```

#### Calories per category
```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Energy", unitName: "kcal"})
RETURN fc.description AS Category,
       ROUND(AVG(r.amount), 0) AS AvgCalories_kcal,
       COUNT(f) AS FoodCount
ORDER BY AvgCalories_kcal DESC;
```

### 6. All Nutrients for Foods in a Category

```cypher
MATCH (fc:FoodCategory {description: "Vegetables and Vegetable Products"})<-[:BELONGS_TO]-(f:Food)
MATCH (f)-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE n.name IN ["Protein", "Total lipid (fat)", "Carbohydrate, by difference", "Fiber, total dietary", "Energy"]
  AND n.unitName IN ["g", "kcal"]
RETURN f.description AS Food,
       n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY f.description, n.rank;
```

---

## Comparison Queries

### 7. Compare Two Foods

```cypher
MATCH (f1:Food {description: "Hummus, commercial"})-[r1:HAS_NUTRIENT]->(n:Nutrient)
      <-[r2:HAS_NUTRIENT]-(f2:Food {description: "Beans, navy, mature seeds, raw"})
WHERE n.name IN ["Protein", "Total lipid (fat)", "Carbohydrate, by difference", "Fiber, total dietary", "Energy"]
RETURN n.name AS Nutrient,
       r1.amount AS Food1_Amount,
       r2.amount AS Food2_Amount,
       n.unitName AS Unit
ORDER BY n.rank;
```

### 8. Find Similar Foods by Nutrient Profile

Find foods similar to "Hummus, commercial" based on macronutrients:

```cypher
MATCH (target:Food {description: "Hummus, commercial"})-[rt:HAS_NUTRIENT]->(nut:Nutrient)
WHERE nut.name IN ["Protein", "Total lipid (fat)", "Carbohydrate, by difference"]

WITH target, COLLECT({name: nut.name, amount: rt.amount}) AS targetNutrients

MATCH (other:Food)-[ro:HAS_NUTRIENT]->(nut:Nutrient)
WHERE nut.name IN ["Protein", "Total lipid (fat)", "Carbohydrate, by difference"]
  AND other <> target

WITH target, targetNutrients, other, COLLECT({name: nut.name, amount: ro.amount}) AS otherNutrients

// Simple similarity check (you can improve this with more sophisticated scoring)
WITH target, other,
     [n IN targetNutrients | n.amount] AS t_amounts,
     [n IN otherNutrients | n.amount] AS o_amounts

// Calculate absolute difference
WITH target, other,
     REDUCE(diff = 0, i IN RANGE(0, SIZE(t_amounts)-1) |
       diff + ABS(t_amounts[i] - o_amounts[i])
     ) AS totalDiff

RETURN other.description AS SimilarFood,
       totalDiff AS Difference
ORDER BY totalDiff
LIMIT 10;
```

---

## Advanced Queries

### 9. Nutrient Density Analysis

Find foods with highest nutrient density (nutrients per calorie):

```cypher
MATCH (f:Food)-[re:HAS_NUTRIENT]->(energy:Nutrient {name: "Energy", unitName: "kcal"})
MATCH (f)-[rn:HAS_NUTRIENT]->(nutrient:Nutrient {name: "Protein"})
WHERE re.amount > 0
RETURN f.description AS Food,
       rn.amount AS Protein_g,
       re.amount AS Calories_kcal,
       ROUND(rn.amount / re.amount * 100, 2) AS ProteinPerCalorie
ORDER BY ProteinPerCalorie DESC
LIMIT 10;
```

### 10. Micronutrient Profile

Get all vitamins and minerals for a food:

```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE n.name =~ ".*Vitamin.*" OR
      n.name IN ["Calcium, Ca", "Iron, Fe", "Magnesium, Mg", "Phosphorus, P",
                 "Potassium, K", "Sodium, Na", "Zinc, Zn", "Copper, Cu",
                 "Manganese, Mn", "Selenium, Se"]
RETURN n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY n.rank;
```

### 11. Statistical Analysis

Get nutrient statistics including min, max, median:

```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE r.min IS NOT NULL
RETURN n.name AS Nutrient,
       r.amount AS Amount,
       r.min AS Min,
       r.max AS Max,
       r.median AS Median,
       r.dataPoints AS DataPoints,
       n.unitName AS Unit
ORDER BY n.rank
LIMIT 20;
```

### 12. Find Foods Missing Specific Nutrients

Find foods that don't have vitamin C data:

```cypher
MATCH (f:Food)
WHERE NOT EXISTS {
  MATCH (f)-[:HAS_NUTRIENT]->(n:Nutrient {name: "Vitamin C, total ascorbic acid"})
}
RETURN f.description AS Food
LIMIT 10;
```

---

## Macronutrient Queries

### 13. Get Macronutrient Breakdown

```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE n.name IN ["Protein", "Total lipid (fat)", "Carbohydrate, by difference",
                 "Fiber, total dietary", "Water", "Ash", "Energy"]
RETURN n.name AS Nutrient,
       r.amount AS Amount,
       n.unitName AS Unit
ORDER BY
  CASE n.name
    WHEN "Energy" THEN 1
    WHEN "Water" THEN 2
    WHEN "Protein" THEN 3
    WHEN "Total lipid (fat)" THEN 4
    WHEN "Carbohydrate, by difference" THEN 5
    WHEN "Fiber, total dietary" THEN 6
    WHEN "Ash" THEN 7
  END;
```

### 14. Calculate Calories from Macronutrients

```cypher
MATCH (f:Food)-[rp:HAS_NUTRIENT]->(protein:Nutrient {name: "Protein"})
MATCH (f)-[rf:HAS_NUTRIENT]->(fat:Nutrient {name: "Total lipid (fat)"})
MATCH (f)-[rc:HAS_NUTRIENT]->(carb:Nutrient {name: "Carbohydrate, by difference"})
MATCH (f)-[re:HAS_NUTRIENT]->(energy:Nutrient {name: "Energy", unitName: "kcal"})
RETURN f.description AS Food,
       rp.amount AS Protein_g,
       rf.amount AS Fat_g,
       rc.amount AS Carb_g,
       re.amount AS TotalCalories,
       ROUND(rp.amount * 4 + rf.amount * 9 + rc.amount * 4, 0) AS CalculatedCalories
ORDER BY TotalCalories DESC
LIMIT 20;
```

---

## Graph Visualization Queries

### 15. Visualize Food Category Network

```cypher
MATCH (fc:FoodCategory)<-[:BELONGS_TO]-(f:Food)
RETURN fc, f
LIMIT 50;
```

### 16. Visualize Food-Nutrient Network for a Specific Food

```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
WHERE r.amount > 0
RETURN f, r, n
LIMIT 30;
```

### 17. Visualize High-Protein Foods Network

```cypher
MATCH (f:Food)-[r:HAS_NUTRIENT]->(n:Nutrient {name: "Protein"})
WHERE r.amount > 20
RETURN f, r, n
LIMIT 30;
```

---

## Search Queries

### 18. Search Foods by Name Pattern

```cypher
MATCH (f:Food)
WHERE f.description =~ "(?i).*bean.*"
RETURN f.description AS Food, f.fdcId
ORDER BY f.description;
```

### 19. Search Nutrients by Name

```cypher
MATCH (n:Nutrient)
WHERE n.name =~ "(?i).*iron.*"
RETURN n.name AS Nutrient, n.unitName AS Unit, n.number AS NutrientNumber
ORDER BY n.name;
```

---

## Export Queries

### 20. Export Food Nutrient Profile to JSON

```cypher
MATCH (f:Food {description: "Hummus, commercial"})-[r:HAS_NUTRIENT]->(n:Nutrient)
RETURN {
  food: f.description,
  fdcId: f.fdcId,
  nutrients: COLLECT({
    name: n.name,
    amount: r.amount,
    unit: n.unitName
  })
} AS nutritionData;
```

---

## Tips

1. **Use LIMIT**: Always use LIMIT when exploring data to avoid overwhelming results
2. **Case-Insensitive Search**: Use `=~ "(?i).*pattern.*"` for case-insensitive pattern matching
3. **Filter Nulls**: Use `WHERE r.amount IS NOT NULL` to filter out missing data
4. **Round Numbers**: Use `ROUND(value, decimals)` for cleaner output
5. **Index Usage**: The queries will be faster because we created indexes on common fields
6. **Profile Queries**: Use `PROFILE` or `EXPLAIN` before your query to see execution plan

## Performance Notes

- Queries filtering by category or food description will be fast due to indexes
- Queries scanning all foods/nutrients may take longer on large datasets
- Use `LIMIT` during development to test queries quickly
- Consider creating additional indexes if you frequently filter on specific properties
