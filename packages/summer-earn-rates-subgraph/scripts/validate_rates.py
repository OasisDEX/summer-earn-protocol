import requests
import json
from typing import Dict, List
from datetime import datetime
import sys

def fetch_hourly_rates(subgraph_url: str) -> Dict[str, float]:
    """
    Fetch all HourlyInterestRate entities from a subgraph
    """
    query = """
    {
        hourlyInterestRates(where: {product_: {name_contains_nocase: "morpho"}}, first: 10000) {
            id
            averageRate
        }
    }
    """
    
    response = requests.post(subgraph_url, json={'query': query})
    if response.status_code != 200:
        raise Exception(f"Query failed with status code {response.status_code}: {response.text}")
    
    data = response.json()
    if 'errors' in data:
        raise Exception(f"GraphQL errors: {data['errors']}")
    
    # Create a dictionary using the rate ID as key
    rates = {}
    for rate in data['data']['hourlyInterestRates']:
        rates[rate['id']] = float(rate['averageRate'])
    
    return rates

def compare_rates(rates1: Dict[str, float], rates2: Dict[str, float], tolerance: float = 0.0001) -> List[Dict]:
    """
    Compare rates between two subgraphs and return discrepancies
    """
    discrepancies = []
    
    # Check all keys in both dictionaries
    all_keys = set(rates1.keys()) | set(rates2.keys())
    
    for key in all_keys:
        if key not in rates1:
            discrepancies.append({
                'id': key,
                'status': 'missing_in_first',
                'rate1': None,
                'rate2': rates2[key]
            })
            continue
            
        if key not in rates2:
            discrepancies.append({
                'id': key,
                'status': 'missing_in_second',
                'rate1': rates1[key],
                'rate2': None
            })
            continue
        
        # Compare rates with tolerance
        if abs(rates1[key] - rates2[key]) > tolerance:
            discrepancies.append({
                'id': key,
                'status': 'mismatch',
                'rate1': rates1[key],
                'rate2': rates2[key],
                'difference': abs(rates1[key] - rates2[key])
            })
    
    return discrepancies

def main():
    if len(sys.argv) != 3:
        print("Usage: python validate_rates.py <subgraph_url_1> <subgraph_url_2>")
        sys.exit(1)
    
    subgraph_url_1 = sys.argv[1]
    subgraph_url_2 = sys.argv[2]
    
    print(f"Fetching rates from first subgraph: {subgraph_url_1}")
    rates1 = fetch_hourly_rates(subgraph_url_1)
    print(f"Found {len(rates1)} rates in first subgraph")
    
    print(f"Fetching rates from second subgraph: {subgraph_url_2}")
    rates2 = fetch_hourly_rates(subgraph_url_2)
    print(f"Found {len(rates2)} rates in second subgraph")
    
    print("\nComparing rates...")
    discrepancies = compare_rates(rates1, rates2)
    
    if not discrepancies:
        print("✅ All rates match between the two subgraphs!")
    else:
        print(f"\n❌ Found {len(discrepancies)} discrepancies:")
        for disc in discrepancies:
            print(f"\nID: {disc['id']}")
            print(f"Status: {disc['status']}")
            if disc['status'] == 'mismatch':
                print(f"Rate 1: {disc['rate1']}")
                print(f"Rate 2: {disc['rate2']}")
                print(f"Difference: {disc['difference']}")

if __name__ == "__main__":
    main() 