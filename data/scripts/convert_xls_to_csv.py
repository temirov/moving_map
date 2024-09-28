#!/usr/bin/env python3

import sys
import pandas as pd

def convert_xls_to_csv(xls_path, csv_path):
    try:
        # Read the first sheet of the XLS file
        df = pd.read_excel(xls_path, sheet_name=0)
        # Replace tabs with commas and handle any necessary formatting
        df.to_csv(csv_path, index=False, encoding='utf-8')
        print(f"Successfully converted {xls_path} to {csv_path}")
    except Exception as e:
        print(f"Error converting XLS to CSV: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: convert_xls_to_csv.py <input_xls> <output_csv>")
        sys.exit(1)
    xls_file = sys.argv[1]
    csv_file = sys.argv[2]
    convert_xls_to_csv(xls_file, csv_file)
