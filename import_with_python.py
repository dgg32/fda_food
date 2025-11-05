#!/usr/bin/env python3
"""
Python script to import FoodData Central data into Neo4j
Alternative to the Cypher script, useful for more control over the import process
"""

import json
from neo4j import GraphDatabase
from typing import Dict, List
import time

# Configuration
NEO4J_URI = "bolt://localhost:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = "your_password"  # Change this!
JSON_FILE = "FoodData_Central_foundation_food_json_2025-04-24.json"

# Batch sizes
FOOD_BATCH_SIZE = 100
NUTRIENT_BATCH_SIZE = 1000


class FoodDataImporter:
    def __init__(self, uri: str, user: str, password: str):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self.driver.close()

    def create_constraints_and_indexes(self):
        """Create database constraints and indexes"""
        print("Creating constraints and indexes...")

        with self.driver.session() as session:
            # Constraints
            session.run(
                "CREATE CONSTRAINT food_fdc_id IF NOT EXISTS "
                "FOR (f:Food) REQUIRE f.fdcId IS UNIQUE"
            )
            session.run(
                "CREATE CONSTRAINT nutrient_id IF NOT EXISTS "
                "FOR (n:Nutrient) REQUIRE n.id IS UNIQUE"
            )
            session.run(
                "CREATE CONSTRAINT category_id IF NOT EXISTS "
                "FOR (c:FoodCategory) REQUIRE c.id IS UNIQUE"
            )

            # Indexes
            session.run(
                "CREATE INDEX food_description IF NOT EXISTS "
                "FOR (f:Food) ON (f.description)"
            )
            session.run(
                "CREATE INDEX nutrient_name IF NOT EXISTS "
                "FOR (n:Nutrient) ON (n.name)"
            )

        print("✓ Constraints and indexes created")

    def load_json_data(self, filepath: str) -> Dict:
        """Load JSON data from file"""
        print(f"Loading JSON data from {filepath}...")
        with open(filepath, 'r') as f:
            data = json.load(f)
        print(f"✓ Loaded {len(data['FoundationFoods'])} foods")
        return data

    def create_nutrients(self, foods: List[Dict]):
        """Pre-create all unique nutrients"""
        print("Creating nutrient nodes...")

        # Collect unique nutrients
        nutrients = {}
        for food in foods:
            for fn in food.get('foodNutrients', []):
                nutrient = fn['nutrient']
                nutrients[nutrient['id']] = nutrient

        print(f"Found {len(nutrients)} unique nutrients")

        # Create nutrients in batches
        with self.driver.session() as session:
            nutrient_list = list(nutrients.values())
            for i in range(0, len(nutrient_list), NUTRIENT_BATCH_SIZE):
                batch = nutrient_list[i:i + NUTRIENT_BATCH_SIZE]
                session.run("""
                    UNWIND $nutrients AS nutrient
                    MERGE (n:Nutrient {id: nutrient.id})
                    ON CREATE SET
                        n.name = nutrient.name,
                        n.number = nutrient.number,
                        n.unitName = nutrient.unitName,
                        n.rank = nutrient.rank
                """, nutrients=batch)

        print(f"✓ Created {len(nutrients)} nutrient nodes")

    def create_foods_and_categories(self, foods: List[Dict]):
        """Create food nodes and food categories"""
        print(f"Creating food and category nodes...")

        with self.driver.session() as session:
            for i in range(0, len(foods), FOOD_BATCH_SIZE):
                batch = foods[i:i + FOOD_BATCH_SIZE]

                session.run("""
                    UNWIND $foods AS food

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

                    // Create relationship
                    CREATE (f)-[:BELONGS_TO]->(fc)
                """, foods=batch)

                if (i + FOOD_BATCH_SIZE) % 100 == 0:
                    print(f"  Processed {i + FOOD_BATCH_SIZE} foods...")

        print(f"✓ Created {len(foods)} food nodes and categories")

    def create_nutrient_relationships(self, foods: List[Dict]):
        """Create relationships between foods and nutrients"""
        print("Creating nutrient relationships...")

        with self.driver.session() as session:
            for i, food in enumerate(foods):
                # Prepare nutrient relationships for this food
                nutrients_data = []
                for fn in food.get('foodNutrients', []):
                    nutrients_data.append({
                        'nutrient_id': fn['nutrient']['id'],
                        'amount': fn.get('amount'),
                        'dataPoints': fn.get('dataPoints'),
                        'derivationCode': fn.get('foodNutrientDerivation', {}).get('code'),
                        'derivationDescription': fn.get('foodNutrientDerivation', {}).get('description'),
                        'min': fn.get('min'),
                        'max': fn.get('max'),
                        'median': fn.get('median')
                    })

                # Create relationships
                session.run("""
                    MATCH (f:Food {fdcId: $fdcId})

                    UNWIND $nutrients AS nutrientData
                    MATCH (n:Nutrient {id: nutrientData.nutrient_id})

                    CREATE (f)-[r:HAS_NUTRIENT]->(n)
                    SET
                        r.amount = toFloat(nutrientData.amount),
                        r.dataPoints = nutrientData.dataPoints,
                        r.derivationCode = nutrientData.derivationCode,
                        r.derivationDescription = nutrientData.derivationDescription,
                        r.min = toFloat(nutrientData.min),
                        r.max = toFloat(nutrientData.max),
                        r.median = toFloat(nutrientData.median)
                """, fdcId=food['fdcId'], nutrients=nutrients_data)

                if (i + 1) % 50 == 0:
                    print(f"  Processed {i + 1} foods...")

        print(f"✓ Created nutrient relationships for {len(foods)} foods")

    def verify_import(self):
        """Verify the import by counting nodes and relationships"""
        print("\nVerifying import...")

        with self.driver.session() as session:
            # Count nodes
            result = session.run("MATCH (f:Food) RETURN COUNT(f) AS count")
            food_count = result.single()['count']

            result = session.run("MATCH (n:Nutrient) RETURN COUNT(n) AS count")
            nutrient_count = result.single()['count']

            result = session.run("MATCH (fc:FoodCategory) RETURN COUNT(fc) AS count")
            category_count = result.single()['count']

            # Count relationships
            result = session.run("MATCH ()-[r:HAS_NUTRIENT]->() RETURN COUNT(r) AS count")
            nutrient_rels = result.single()['count']

            result = session.run("MATCH ()-[r:BELONGS_TO]->() RETURN COUNT(r) AS count")
            category_rels = result.single()['count']

            print("\n" + "="*50)
            print("IMPORT SUMMARY")
            print("="*50)
            print(f"Foods:                    {food_count:,}")
            print(f"Nutrients:                {nutrient_count:,}")
            print(f"Food Categories:          {category_count:,}")
            print(f"Nutrient Relationships:   {nutrient_rels:,}")
            print(f"Category Relationships:   {category_rels:,}")
            print("="*50)

    def run_import(self, json_file: str):
        """Run the complete import process"""
        start_time = time.time()

        print("="*50)
        print("FoodData Central Import to Neo4j")
        print("="*50)

        try:
            # Load data
            data = self.load_json_data(json_file)
            foods = data['FoundationFoods']

            # Create schema
            self.create_constraints_and_indexes()

            # Import data
            self.create_nutrients(foods)
            self.create_foods_and_categories(foods)
            self.create_nutrient_relationships(foods)

            # Verify
            self.verify_import()

            elapsed_time = time.time() - start_time
            print(f"\n✓ Import completed in {elapsed_time:.2f} seconds")

        except Exception as e:
            print(f"\n✗ Error during import: {e}")
            raise


def main():
    """Main entry point"""
    print("\nNeo4j FoodData Central Importer")
    print("="*50)
    print(f"Neo4j URI:  {NEO4J_URI}")
    print(f"User:       {NEO4J_USER}")
    print(f"JSON File:  {JSON_FILE}")
    print("="*50)

    # Confirm before proceeding
    response = input("\nProceed with import? (yes/no): ")
    if response.lower() not in ['yes', 'y']:
        print("Import cancelled")
        return

    # Run import
    importer = FoodDataImporter(NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)
    try:
        importer.run_import(JSON_FILE)
    finally:
        importer.close()


if __name__ == "__main__":
    main()
