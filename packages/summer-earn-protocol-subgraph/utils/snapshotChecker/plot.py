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
    
    query = """
    {
      vaults {
        dailySnapshots {
          id
          timestamp
          calculatedApr
          pricePerShare
        }
        hourlySnapshots(first:1000) {
          id
          timestamp
          calculatedApr
          pricePerShare
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


def calculate_ema(data, span=20):
    # Ensure span isn't larger than the data length
    span = min(span, len(data) - 1)
    
    values = np.array(data)
    weights = np.exp(np.linspace(-1., 0., span))
    weights /= weights.sum()
    
    ema = np.convolve(values, weights, mode='full')[:len(values)]
    ema[:span] = ema[span]
    return ema

def plot_apr_over_time(snapshots, snapshot_type, version, network):
    # Extract timestamps and APR
    timestamps = [int(snapshot['timestamp']) for snapshot in snapshots]
    aprs = [float(snapshot['calculatedApr']) for snapshot in snapshots]
    
    # Convert timestamps to datetime objects
    dates = [datetime.fromtimestamp(ts) for ts in timestamps]
    
    # Calculate statistics
    avg_apr = np.mean(aprs)
    ema = calculate_ema(aprs, span=50)
    
    # Create the plot
    plt.figure(figsize=(12, 6))
    
    plt.plot(dates, aprs, marker='.', label='APR', alpha=0.5)
    plt.plot(dates, ema, label=f'EMA (20 periods)', linewidth=2)
    plt.axhline(y=avg_apr, color='r', linestyle='--', 
                label=f'Average APR ({avg_apr:.2f}%)')
    plt.ylim(0, 25)   
    plt.title(f'{snapshot_type} APR Over Time')
    plt.xlabel('Date')
    plt.ylabel('APR (%)')
    plt.grid(True)
    
    plt.xticks(rotation=45)
    plt.legend()
    plt.tight_layout()
    
    plt.savefig(f'apr_over_time_{network}_{version}_{snapshot_type.lower()}.png')
    plt.close()

    print(f"\n{snapshot_type} APR Statistics:")
    print(f"Average APR: {avg_apr:.2f}%")
    print(f"Min APR: {min(aprs):.2f}%")
    print(f"Max APR: {max(aprs):.2f}%")

def plot_price_over_time(snapshots, snapshot_type, version, network):
    # Extract timestamps and price
    timestamps = [int(snapshot['timestamp']) for snapshot in snapshots]
    prices = [float(snapshot['pricePerShare']) for snapshot in snapshots]
    
    # Convert timestamps to datetime objects
    dates = [datetime.fromtimestamp(ts) for ts in timestamps]
    
    # Calculate statistics
    avg_price = np.mean(prices)
    ema = calculate_ema(prices, span=50)
    
    # Create the plot
    plt.figure(figsize=(12, 6))
    
    plt.plot(dates, prices, marker='.', label='Price per Share', alpha=0.5)
    plt.plot(dates, ema, label=f'EMA (20 periods)', linewidth=2)
    plt.axhline(y=avg_price, color='r', linestyle='--', 
                label=f'Average Price ({avg_price:.6f})')
    
    plt.title(f'{snapshot_type} Price per Share Over Time')
    plt.xlabel('Date')
    plt.ylabel('Price per Share')
    plt.grid(True)
    
    plt.xticks(rotation=45)
    plt.legend()
    plt.tight_layout()
    
    plt.savefig(f'price_over_time_{network}_{version}_{snapshot_type.lower()}.png')
    plt.close()

    print(f"\n{snapshot_type} Price Statistics:")
    print(f"Average Price: {avg_price:.6f}")
    print(f"Min Price: {min(prices):.6f}")
    print(f"Max Price: {max(prices):.6f}")

def plot_price_and_apr_overlay(snapshots, version, network):
    # Extract data
    timestamps = [int(snapshot['timestamp']) for snapshot in snapshots]
    prices = [float(snapshot['pricePerShare']) for snapshot in snapshots]
    aprs = [float(snapshot['calculatedApr']) for snapshot in snapshots]
    
    # Convert timestamps to datetime objects
    dates = [datetime.fromtimestamp(ts) for ts in timestamps]
    
    # Calculate EMAs
    price_ema = calculate_ema(prices, span=50)
    apr_ema = calculate_ema(aprs, span=50)
    
    # Create figure and axis objects with a single subplot
    fig, ax1 = plt.subplots(figsize=(12, 6))
    
    # Plot price on primary y-axis
    color = 'tab:blue'
    ax1.set_xlabel('Date')
    ax1.set_ylabel('Price per Share', color=color)
    ax1.plot(dates, prices, color=color, alpha=0.3, label='Price')
    ax1.plot(dates, price_ema, color=color, label='Price EMA')
    ax1.tick_params(axis='y', labelcolor=color)
    
    # Create second y-axis that shares x-axis
    ax2 = ax1.twinx()
    
    # Plot APR on secondary y-axis
    color = 'tab:orange'
    ax2.set_ylabel('APR (%)', color=color)
    ax2.plot(dates, aprs, color=color, alpha=0.3, label='APR')
    ax2.plot(dates, apr_ema, color=color, label='APR EMA')
    ax2.tick_params(axis='y', labelcolor=color)
    
    # Add title and adjust layout
    plt.title('Hourly Price per Share and APR Over Time')
    
    # Add legends for both axes
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper left')
    
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    # Save the plot
    plt.savefig(f'price_and_apr_overlay_{network}_{version}_hourly.png')
    plt.close()
    
def plot_timestamps(version, network):
    # Fetch data from subgraph
    data = fetch_subgraph_data(version, network)
    
    # Plot daily snapshots
    daily_snapshots = data['data']['vaults'][0]['dailySnapshots']
    print(f"Number of daily snapshots: {len(daily_snapshots)}")
    plot_snapshot_intervals(daily_snapshots, "Daily", 24, version, network)
    plot_apr_over_time(daily_snapshots, "Daily", version, network)
    plot_price_over_time(daily_snapshots, "Daily", version, network)
    
    # Plot hourly snapshots
    hourly_snapshots = data['data']['vaults'][0]['hourlySnapshots']
    print(f"Number of hourly snapshots: {len(hourly_snapshots)}")
    plot_snapshot_intervals(hourly_snapshots, "Hourly", 1, version, network)
    plot_apr_over_time(hourly_snapshots, "Hourly", version, network)
    plot_price_over_time(hourly_snapshots, "Hourly", version, network)
    plot_price_and_apr_overlay(hourly_snapshots, version, network)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python plot.py <version> <network>")
        sys.exit(1)
    version = sys.argv[1]
    network = sys.argv[2]
    plot_timestamps(version, network)
