#!/usr/bin/env python3
import csv
import sys

csv_file = r"PickAndPlace_PCB5_2026_03_21.csv"

print(f"Reading {csv_file}...")
print("=" * 80)

try:
    with open(csv_file, 'r', encoding='utf-16') as f:
        reader = csv.DictReader(f, delimiter='\t')
        rows = list(reader)
        print(f"Total rows: {len(rows)}")
        print("\nFirst 10 rows with Designator:")
        for i, row in enumerate(rows[:10]):
            designator = row.get('Designator', 'N/A')
            device = row.get('Device', 'N/A')
            print(f"  Row {i}: Designator='{designator}' Device='{device}'")
        
        print("\nAll designators:")
        designators = [row.get('Designator', 'N/A') for row in rows]
        from collections import Counter
        counts = Counter(designators)
        
        for des, count in sorted(counts.items()):
            if count > 1:
                print(f"  ⚠️  '{des}': {count} times")
        
        print(f"\nTotal unique designators: {len(counts)}")
        print(f"Total rows: {len(rows)}")
        
        duplicates = [(k, v) for k, v in counts.items() if v > 1]
        if duplicates:
            print(f"\n⚠️  Found {len(duplicates)} duplicate designators:")
            for des, count in sorted(duplicates):
                print(f"  '{des}': {count}x")
        else:
            print("\n✓ No duplicate designators found")
            
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
