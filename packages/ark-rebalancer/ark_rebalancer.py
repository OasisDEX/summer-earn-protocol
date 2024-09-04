import time
from web3 import Web3
from collections import deque
import os
from dotenv import load_dotenv
import json

# Load environment variables
load_dotenv()

# Configuration
INFURA_URL = os.getenv("BASE_RPC_URL")
PRIVATE_KEY = os.getenv("DEPLOYER_PRIV_KEY")
FLEET_COMMANDER_ADDRESS = os.getenv("FLEET_COMMANDER_ADDRESS")

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(INFURA_URL))

# ABIs (replace with the full ABIs you provided)
FLEET_COMMANDER_ABI = json.loads('[{"inputs":[{"components":[{"internalType":"address","name":"configurationManager","type":"address"},{"internalType":"address","name":"accessManager","type":"address"},{"internalType":"address[]","name":"initialArks","type":"address[]"},{"internalType":"uint256","name":"initialMinimumFundsBufferBalance","type":"uint256"},{"internalType":"uint256","name":"initialRebalanceCooldown","type":"uint256"},{"internalType":"address","name":"asset","type":"address"},{"internalType":"string","name":"name","type":"string"},{"internalType":"string","name":"symbol","type":"string"},{"internalType":"Percentage","name":"initialMinimumPositionWithdrawal","type":"uint256"},{"internalType":"Percentage","name":"initialMaximumBufferWithdrawal","type":"uint256"},{"internalType":"uint256","name":"depositCap","type":"uint256"},{"internalType":"address","name":"bufferArk","type":"address"},{"internalType":"uint256","name":"initialTipRate","type":"uint256"}],"internalType":"struct FleetCommanderParams","name":"params","type":"tuple"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"arks","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"components":[{"internalType":"address","name":"fromArk","type":"address"},{"internalType":"address","name":"toArk","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"internalType":"struct RebalanceData[]","name":"rebalanceData","type":"tuple[]"}],"name":"rebalance","outputs":[],"stateMutability":"nonpayable","type":"function"}]')

ARK_ABI = json.loads('[{"type":"function","name":"rate","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"totalAssets","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"}]')

# Initialize contract
fleet_commander = w3.eth.contract(address=FLEET_COMMANDER_ADDRESS, abi=FLEET_COMMANDER_ABI)

# Initialize account
account = w3.eth.account.from_key(PRIVATE_KEY)

# Function to get ark rates
def get_ark_rates():
    arks = fleet_commander.functions.arks().call()
    rates = []
    for ark in arks:
        ark_contract = w3.eth.contract(address=ark, abi=ARK_ABI)
        try:
            rate = ark_contract.functions.rate().call()
            rates.append((ark, rate))
        except Exception as e:
            print(f"Error getting rate for ark {ark}: {e}")
    return sorted(rates, key=lambda x: x[1], reverse=True)

# Function to prepare rebalance data
def prepare_rebalance_data(sorted_rates):
    if not sorted_rates:
        print("No valid ark rates available. Cannot prepare rebalance data.")
        return []
    top_ark = sorted_rates[0][0]
    rebalance_data = []
    for ark, _ in sorted_rates[1:]:
        ark_contract = w3.eth.contract(address=ark, abi=ARK_ABI)
        try:
            amount = ark_contract.functions.totalAssets().call()
            if amount > 100:
                rebalance_data.append({"fromArk": ark, "toArk": top_ark, "amount": amount})
        except Exception as e:
            print(f"Error getting totalAssets for ark {ark}: {e}")
    print(f"Rebalance data prepared: {rebalance_data}")        
    return rebalance_data

# Main loop
rate_history = deque(maxlen=12)  # Store 2 minutes of rate history (12 * 10 seconds)
while True:
    try:
        sorted_rates = get_ark_rates()
        if sorted_rates:
            rate_history.append(sorted_rates[0])
            print(f"Current top ark: {sorted_rates[0][0]} with rate {sorted_rates[0][1]}")

            if len(rate_history) == 12 and all(ark == rate_history[0][0] for ark, _ in rate_history):
                rebalance_data = prepare_rebalance_data(sorted_rates)
                
                if rebalance_data:
                    print("Preparing to rebalance...")
                    print("Rebalance data:", rebalance_data)
                    
                    # Prepare transaction
                    transaction = fleet_commander.functions.rebalance(rebalance_data).build_transaction({
                        'from': account.address,
                        'gas': 2000000,  # Adjust as needed
                        'gasPrice': w3.eth.gas_price,
                    })

                    # Simulate the transaction
                    try:
                        result = w3.eth.call(transaction)
                        print("Transaction simulation successful")
                        
                        # If simulation is successful, proceed with actual transaction
                        transaction['nonce'] = w3.eth.get_transaction_count(account.address)
                        signed_txn = account.sign_transaction(transaction)
                        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
                        
                        print(f"Rebalance transaction sent: {tx_hash.hex()}")
                        
                        # Wait for transaction receipt
                        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                        print(f"Transaction status: {'Success' if tx_receipt['status'] == 1 else 'Failed'}")
                    except Exception as e:
                        print(f"Transaction would fail: {e}")
                else:
                    print("No rebalance data prepared. Skipping rebalance.")
        else:
            print("No valid ark rates available.")

        time.sleep(10)  # Wait for 10 seconds before next check
    except Exception as e:
        print(f"An error occurred in the main loop: {e}")
        time.sleep(60)  # Wait for 1 minute before retrying