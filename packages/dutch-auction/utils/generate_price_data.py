import json
import matplotlib.pyplot as plt

# Constants
START_PRICE = 100 * 10**18  # 100 ether in Wei
END_PRICE = 50 * 10**18     # 50 ether in Wei
AUCTION_DURATION = 86400    # 1 day in seconds

# Function to calculate linear decay price
def calculate_linear_price(time_elapsed):
    price_difference = START_PRICE - END_PRICE
    return START_PRICE - (price_difference * time_elapsed) // AUCTION_DURATION

# Function to calculate quadratic decay price
def calculate_quadratic_price(time_elapsed):
    price_difference = START_PRICE - END_PRICE
    return END_PRICE + (price_difference * (AUCTION_DURATION - time_elapsed) ** 2) // AUCTION_DURATION ** 2

def generate_intervals(num_intervals):
    return [i * AUCTION_DURATION // (num_intervals - 1) for i in range(num_intervals)]

def generate_price_data(num_intervals):
    intervals = generate_intervals(num_intervals)
    price_data = {
        "linear": {},
        "quadratic": {}
    }

    for time in intervals:
        price_data["linear"][time] = int(calculate_linear_price(time))
        price_data["quadratic"][time] = int(calculate_quadratic_price(time))

    return price_data

def write_price_data_to_json(price_data, filename='expected_prices.json'):
    with open(filename, 'w') as json_file:
        json.dump(price_data, json_file, indent=4)

def plot_price_decays(price_data):
    intervals = list(price_data["linear"].keys())
    linear_prices = list(price_data["linear"].values())
    quadratic_prices = list(price_data["quadratic"].values())

    # Convert prices from Wei to Ether for easier visualization
    linear_prices_ether = [price / 10**18 for price in linear_prices]
    quadratic_prices_ether = [price / 10**18 for price in quadratic_prices]

    # Convert time from seconds to hours for better readability
    intervals_hours = [t / 3600 for t in intervals]

    plt.figure(figsize=(10, 6))
    plt.plot(intervals_hours, linear_prices_ether, label="Linear Decay", marker='o')
    plt.plot(intervals_hours, quadratic_prices_ether, label="Quadratic Decay", marker='x')
    
    plt.title("Price Decay in Dutch Auction")
    plt.xlabel("Time (hours)")
    plt.ylabel("Price (Ether)")
    plt.legend()
    plt.grid(True)
    plt.xticks(intervals_hours)  # Ensure we label the x-axis with the exact intervals
    plt.tight_layout()
    
    plt.savefig('price_decay_comparison.png')
    print("Plot saved as price_decay_comparison.png")

def main():
    num_intervals = 10  # Change this to configure the number of intervals
    price_data = generate_price_data(num_intervals)
    write_price_data_to_json(price_data)
    print(f"Expected prices for {num_intervals} intervals written to expected_prices.json")

    plot_price_decays(price_data)

if __name__ == "__main__":
    main()
