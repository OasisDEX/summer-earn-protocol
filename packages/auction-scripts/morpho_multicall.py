from web3 import Web3
from eth_account import Account
import asyncio
import os
from dotenv import load_dotenv
from typing import NamedTuple, List, Dict, Tuple, Optional
import aiohttp
import json
import sys
import logging

# Setup logging
log_format = '[%(levelname)s] %(asctime)s|%(name)s|%(threadName)s|%(filename)s:%(lineno)d: %(message)s'
logger = logging.getLogger("Morpho Multicall")
logger.setLevel(logging.INFO)
logging.basicConfig(level=logging.INFO, format=log_format, stream=sys.stdout)

# Disable verbose logs from web3 components
logging.getLogger("web3.providers.HTTPProvider").disabled = True
logging.getLogger("web3._utils.request").disabled = True
logging.getLogger("urllib3.connectionpool").disabled = True
logging.getLogger("web3.RequestManager").disabled = True

# Load environment variables
load_dotenv()

class MorphoChainConfig(NamedTuple):
    name: str
    rpc_env_var: str
    rpc_urls: List[str]
    chain_id: int
    subgraph_endpoint: str
    raft_address: str
    multicall_address: str
    bundler_address: str

# Morpho chain configurations with multiple RPC endpoints
MORPHO_CHAINS = {
    "base": MorphoChainConfig(
        name="Base",
        rpc_env_var="BASE_RPC_URL",
        rpc_urls=[
            os.getenv("BASE_RPC_URL", "https://base.publicnode.com"),
            "https://base.llamarpc.com",
            "https://base.drpc.org"
        ],
        chain_id=8453,
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-base",
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E",
        multicall_address="0xcA11bde05977b3631167028862bE2a173976CA11",  # Base Multicall3 address
        bundler_address="0x23055618898e202386e6c13955a58D3C68200BFB"  # Base Morpho bundler
    ),
    "mainnet": MorphoChainConfig(
        name="Mainnet",
        rpc_env_var="MAINNET_RPC_URL",
        rpc_urls=[
            os.getenv("MAINNET_RPC_URL", "https://ethereum.publicnode.com"),
            "https://rpc.flashbots.net/",
            "https://eth.llamarpc.com"
        ],
        chain_id=1,
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol",
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E",
        multicall_address="0xcA11bde05977b3631167028862bE2a173976CA11",  # Ethereum Multicall3 address
        bundler_address="0x4095F064B8d3c3548A3bebfd0Bbfd04750E30077"  # Mainnet Morpho bundler
    )
}

# ABI for the claim function
CLAIM_ABI = [
    {
        "name": "claim",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "account", "type": "address"},
            {"name": "reward", "type": "address"},
            {"name": "claimable", "type": "uint256"},
            {"name": "proof", "type": "bytes32[]"}
        ],
        "outputs": [{"name": "amount", "type": "uint256"}]
    }
]

# ABI for the URD bundler
URD_BUNDLER_ABI = [
    {
        "name": "urdClaim",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "distributor", "type": "address"},
            {"name": "account", "type": "address"},
            {"name": "reward", "type": "address"},
            {"name": "amount", "type": "uint256"},
            {"name": "proof", "type": "bytes32[]"},
            {"name": "skipRevert", "type": "bool"}
        ],
        "outputs": []
    },
    {
        "name": "multicall",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "calls", "type": "bytes[]"}
        ],
        "outputs": [
            {"name": "results", "type": "bytes[]"}
        ]
    }
]

# ABI for the ERC20 token to get the symbol
ERC20_ABI = [
    {
        "constant": True,
        "inputs": [],
        "name": "symbol",
        "outputs": [{"name": "", "type": "string"}],
        "payable": False,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [{"name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "payable": False,
        "stateMutability": "view",
        "type": "function"
    }
]

def setup_web3(chain_config: MorphoChainConfig) -> Web3:
    """Setup a Web3 instance for the given chain"""
    for rpc_url in chain_config.rpc_urls:
        if rpc_url:  # Skip empty URLs
            try:
                w3 = Web3(Web3.HTTPProvider(rpc_url))
                if w3.is_connected():
                    print(f"Connected to {chain_config.name} using {rpc_url}")
                    return w3
            except Exception as e:
                print(f"Error connecting to {rpc_url}: {str(e)}")
                continue
    
    raise Exception(f"Failed to connect to any RPC for {chain_config.name}")

async def fetch_ark_addresses(session: aiohttp.ClientSession, subgraph_endpoint: str) -> List[str]:
    """Fetch ARK addresses from the subgraph"""
    query = """
    {
      vaults {
        arks(where:{name_contains_nocase:"morpho"}){
          id
        }
      }
    }
    """
    
    try:
        print(f"Fetching ARK addresses from: {subgraph_endpoint}")
        async with session.post(
            subgraph_endpoint,
            json={"query": query},
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status != 200:
                print(f"Error: Subgraph returned status {response.status}")
                return []
            
            data = await response.json()
            ark_addresses = []
            
            for vault in data.get("data", {}).get("vaults", []):
                for ark in vault.get("arks", []):
                    ark_addresses.append(ark["id"])
            
            print(f"Found {len(ark_addresses)} ARK addresses")
            return ark_addresses
    except Exception as e:
        print(f"Error fetching ARK addresses: {str(e)}")
        return []

async def fetch_morpho_rewards(session: aiohttp.ClientSession, ark_address: str):
    """Fetch rewards for an ARK address"""
    url = f"https://rewards.morpho.org/v1/users/{ark_address}/rewards"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return data
            print(f"No rewards found for {ark_address} (status: {response.status})")
            return None
    except Exception as e:
        print(f"Error fetching rewards for {ark_address}: {str(e)}")
        return None

async def fetch_claimable_distributions(session: aiohttp.ClientSession, ark_address: str):
    """Fetch claimable distributions for an ARK address"""
    url = f"https://rewards.morpho.org/v1/users/{ark_address}/distributions"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                return await response.json()
            return None
    except Exception as e:
        print(f"Error fetching distributions for {ark_address}: {str(e)}")
        return None

async def get_token_symbol(w3: Web3, token_address: str) -> str:
    """Fetch the token symbol from the ERC20 contract"""
    try:
        contract = w3.eth.contract(address=Web3.to_checksum_address(token_address), abi=ERC20_ABI)
        symbol = contract.functions.symbol().call()
        return symbol
    except Exception as e:
        print(f"Error fetching symbol for token {token_address}: {str(e)}")
        return "Unknown"

async def prepare_bundled_claim(chain_config: MorphoChainConfig, w3: Web3, account_address: str) -> Tuple[Optional[List[bytes]], List[Dict]]:
    """Prepare bundled claim calls for all rewards on a chain"""
    async with aiohttp.ClientSession() as session:
        ark_addresses = await fetch_ark_addresses(session, chain_config.subgraph_endpoint)
        
        if not ark_addresses:
            print(f"No ARK addresses found for {chain_config.name}")
            return None, []
        
        # Collect all claim data
        all_encoded_claims = []
        all_claims = []
        
        for ark in ark_addresses:
            # First get the rewards data
            rewards_data = await fetch_morpho_rewards(session, ark)
            if not rewards_data or not rewards_data.get('data'):
                continue
            
            # Filter rewards for current chain
            chain_rewards = [r for r in rewards_data['data'] if r['asset']['chain_id'] == chain_config.chain_id]
            if not chain_rewards:
                continue
            
            # Get distributions data
            distributions = await fetch_claimable_distributions(session, ark)
            if not distributions or not distributions.get('data'):
                continue
            
            print(f"\n{chain_config.name} - Found claimable rewards for {ark}")
            
            # Group distributions by asset address for easier lookup
            distributions_by_asset = {}
            for dist in distributions.get('data', []):
                if dist['asset']['chain_id'] != chain_config.chain_id:
                    continue
                asset_address = dist['asset']['address']
                if asset_address not in distributions_by_asset:
                    distributions_by_asset[asset_address] = []
                distributions_by_asset[asset_address].append(dist)
            
            # Process each reward
            for reward in chain_rewards:
                asset_address = reward['asset']['address']
                reward_type = reward.get('type', 'unknown')
                
                # Check if there's any claimable_now amount
                claimable_now = 0
                if reward_type == 'uniform-reward' and 'amount' in reward:
                    claimable_now = float(reward['amount']['claimable_now']) / 1e18
                elif reward_type == 'vault-reward' and 'for_supply' in reward:
                    claimable_now = float(reward['for_supply']['claimable_now']) / 1e18
                elif reward_type == 'market-reward' and 'for_supply' in reward:
                    claimable_now = float(reward['for_supply']['claimable_now']) / 1e18
                
                # Skip if no claimable amount
                if claimable_now <= 0:
                    continue
                
                # Get matching distributions
                matching_distributions = distributions_by_asset.get(asset_address, [])
                if not matching_distributions:
                    continue
                
                # Get token symbol for better readability
                symbol = await get_token_symbol(w3, asset_address)
                print(f"- Found claimable amount: {claimable_now:.6f} {symbol} ({asset_address})")
                
                # Process each distribution for this reward
                for dist in matching_distributions:
                    # Create a contract for the bundler
                    bundler_contract = w3.eth.contract(
                        address=Web3.to_checksum_address(chain_config.bundler_address),
                        abi=URD_BUNDLER_ABI
                    )
                    
                    # Encode the urdClaim call
                    encoded_claim = bundler_contract.encode_abi(
                        fn_name="urdClaim",
                        args=[
                            Web3.to_checksum_address(dist['distributor']['address']),  # distributor
                            Web3.to_checksum_address(ark),                             # account
                            Web3.to_checksum_address(asset_address),                   # reward
                            int(dist['claimable']),                                    # amount
                            dist['proof'],                                             # proof
                            True                                                       # skipRevert
                        ]
                    )
                    
                    all_encoded_claims.append(encoded_claim)
                    
                    # Add to all claims for summary
                    all_claims.append({
                        'ark_address': ark,
                        'reward_address': asset_address,
                        'symbol': symbol,
                        'amount': float(dist['claimable']) / 1e18,
                        'distributor_address': dist['distributor']['address']
                    })
        
        return all_encoded_claims, all_claims

async def display_claims_summary(all_claims: List[Dict]):
    """Display a summary of all claims to be made"""
    if not all_claims:
        print("No claims to make")
        return
    
    # Group by token symbol
    claims_by_symbol = {}
    for claim in all_claims:
        symbol = claim['symbol']
        if symbol not in claims_by_symbol:
            claims_by_symbol[symbol] = []
        claims_by_symbol[symbol].append(claim)
    
    print("\n=== Claims Summary ===")
    total_claims = 0
    
    for symbol, claims in claims_by_symbol.items():
        total_amount = sum(c['amount'] for c in claims)
        total_claims += len(claims)
        print(f"{symbol}: {total_amount:.6f} across {len(claims)} ARKs")
    
    print(f"\nTotal: {total_claims} claims across {len(claims_by_symbol)} tokens")
    print("=====================")

async def execute_bundled_claim(chain_config: MorphoChainConfig, account, encoded_claims: List[bytes]):
    """Execute a bundled claim for a chain"""
    if not encoded_claims:
        print(f"No claims to execute for {chain_config.name}")
        return
    
    # Setup Web3
    w3 = setup_web3(chain_config)
    
    print(f"\nExecuting bundled claim on {chain_config.name}")
    print(f"Number of claims in this bundle: {len(encoded_claims)}")
    
    # # Ask for confirmation
    # print("Proceed with this bundled claim? (y/N) ", end="")
    # response = await asyncio.to_thread(sys.stdin.readline)
    # if response.strip().lower() != 'y':
    #     print("Skipping this bundled claim")
    #     return
    
    try:
        # Create contract for the bundler
        bundler_contract = w3.eth.contract(
            address=Web3.to_checksum_address(chain_config.bundler_address),
            abi=URD_BUNDLER_ABI
        )
        
        # Encode the multicall transaction
        tx_data = bundler_contract.encode_abi(
            fn_name="multicall",
            args=[encoded_claims]
        )
        gas_price = w3.eth.gas_price
        # Build transaction
        tx = {
            'from': account.address,
            'to': Web3.to_checksum_address(chain_config.bundler_address),
            'data': tx_data,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 5000000,  # Initial gas estimate, will be updated
            'chainId': chain_config.chain_id,
            'gasPrice': gas_price * 2

        }
        
        # Try to estimate gas
        try:
            estimated_gas = w3.eth.estimate_gas({
                'from': account.address,
                'to': Web3.to_checksum_address(chain_config.bundler_address),
                'data': tx_data
            })
            print(f"Estimated gas: {estimated_gas}")
            
            # Update with 20% buffer
            tx['gas'] = int(estimated_gas * 1.2)
        except Exception as e:
            print(f"Gas estimation failed: {str(e)}")
            print("Using default gas limit. Transaction may fail.")
        
        # Sign transaction
        signed_tx = w3.eth.account.sign_transaction(tx, private_key=account.key)
        
        # Send transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        tx_hash_hex = tx_hash.hex()
        print(f"Transaction sent: {tx_hash_hex}")
        
        # Wait for confirmation
        print("Waiting for transaction confirmation...")
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        if receipt.status == 1:
            print(f"Transaction confirmed successfully!")
            print(f"Gas used: {receipt.gasUsed}")
        else:
            print(f"Transaction failed! Status: {receipt.status}")
        
        print(f"Transaction receipt: {receipt}")
        
    except Exception as e:
        print(f"Error executing bundled claim: {str(e)}")

async def process_chain(chain_config: MorphoChainConfig):
    """Process rewards for a chain using bundled claims"""
    print(f"\nProcessing {chain_config.name} rewards...")
    
    # Setup Web3
    w3 = setup_web3(chain_config)
    
    # Setup account
    account = Account.from_key(os.getenv('KEEPER_PRIVATE_KEY'))
    print(f"Using account: {account.address}")
    
    # Prepare bundled claim
    encoded_claims, all_claims = await prepare_bundled_claim(
        chain_config, 
        w3, 
        account.address
    )
    
    # Display claims summary
    await display_claims_summary(all_claims)
    
    # Execute bundled claim if any
    if encoded_claims:
        await execute_bundled_claim(chain_config, account, encoded_claims)
    else:
        print(f"No claimable rewards found for {chain_config.name}")

async def main():
    print("Morpho Bundled Claim Tool")
    
    # Process each chain
    for chain_name in MORPHO_CHAINS:
        print(f"\nProcessing {chain_name}...")
        await process_chain(MORPHO_CHAINS[chain_name])
    
    print("\nAll operations completed")

if __name__ == "__main__":
    asyncio.run(main()) 