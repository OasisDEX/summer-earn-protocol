import matplotlib.pyplot as plt
import os
from datetime import datetime
import numpy as np
import requests
import sys

def fetch_subgraph_data(version, network):
    subgraph_key = os.getenv('SUBGRAPH_READ_KEY')
    if not subgraph_key:
        raise ValueError("SUBGRAPH_READ_KEY environment variable is not set")
        
    url = f"https://subgraph.satsuma-prod.com/{subgraph_key}/summer-fi/summer-protocol-{network}/version/{version}/api"
    print(url)
    query = """
    {
      vaults {
        dailySnapshots {
          id
          timestamp
          calculatedApr
        }
        hourlySnapshots(first:1000) {
          id
          timestamp
        }
      }
    }
    """
    
    response = requests.post(url, json={'query': query})
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Query failed with status code: {response.status_code}")

def plot_snapshot_intervals(snapshots, snapshot_type, target_hours, version, network):
    # Extract timestamps
    timestamps = [int(snapshot['timestamp']) for snapshot in snapshots]
    
    # Convert timestamps to datetime objects
    dates = [datetime.fromtimestamp(ts) for ts in timestamps]
    
       # Calculate time differences between consecutive snapshots (in hours)
    time_diffs = []
    for i in range(1, len(timestamps)):
        diff_hours = (timestamps[i] - timestamps[i-1]) / 3600
        time_diffs.append(diff_hours)
    
    # Calculate average and median
    avg_diff = sum(time_diffs)/len(time_diffs)
    median_diff = np.median(time_diffs)
    
    # Create the plot
    plt.figure(figsize=(12, 6))
    
    # Plot time differences
    plt.plot(dates[1:], time_diffs, marker='o', label='Intervals')
    
    # Add reference lines
    plt.axhline(y=target_hours, color='r', linestyle='--', label=f'{target_hours} Hour Target')
    plt.axhline(y=avg_diff, color='g', linestyle='--', label=f'Average ({avg_diff:.2f} hours)')
    plt.axhline(y=median_diff, color='b', linestyle='--', label=f'Median ({median_diff:.2f} hours)')
    
    if snapshot_type.lower() == "hourly":
        plt.ylim(0.98, 1.016)    
    # Customize the plot
    plt.title(f'Time Differences Between {snapshot_type} Snapshots')
    plt.xlabel('Date')
    plt.ylabel('Hours Between Snapshots')
    plt.grid(True)
    
    plt.xticks(rotation=45)
    plt.legend()
    plt.tight_layout()
    
    # Save the plot
    plt.savefig(f'snapshot_intervals_{network}_{version}_{snapshot_type.lower()}.png')
    plt.close()

    # Print statistics
    print(f"\n{snapshot_type} Snapshot Statistics:")
    print(f"Average time difference: {avg_diff:.2f} hours")
    print(f"Median time difference: {median_diff:.2f} hours")
    print(f"Min time difference: {min(time_diffs):.2f} hours")
    print(f"Max time difference: {max(time_diffs):.2f} hours")


def plot_timestamps(version, network):
    # Fetch data from subgraph
    data = fetch_subgraph_data(version, network)
    
    # Plot daily snapshots
    daily_snapshots = data['data']['vaults'][0]['dailySnapshots']
    plot_snapshot_intervals(daily_snapshots, "Daily", 24, version, network)
    
    # Plot hourly snapshots
    hourly_snapshots = data['data']['vaults'][0]['hourlySnapshots']
    plot_snapshot_intervals(hourly_snapshots, "Hourly", 1, version, network)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python plot.py <version> <network>")
        sys.exit(1)
    version = sys.argv[1]
    network = sys.argv[2]
    plot_timestamps(version, network)
