from web3 import Web3
from eth_account import Account
import asyncio
import os
from dotenv import load_dotenv
from typing import NamedTuple, List, Dict, Optional, Tuple, Set
from datetime import datetime
import aiohttp
import json
import sys
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("ANGL Auto Claimer")

# Load environment variables
load_dotenv()

class ChainConfig(NamedTuple):
    name: str
    rpc_env_var: str
    chain_id: int
    merkl_distributor: str
    subgraph_endpoint: str
    raft_address: str

# Chain configurations for ANGL
ANGL_CHAINS = {
    "mainnet": ChainConfig(
        name="Mainnet",
        rpc_env_var="MAINNET_RPC_URL",
        chain_id=1,
        merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol",
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E"
    ),
    "base": ChainConfig(
        name="Base",
        rpc_env_var="BASE_RPC_URL",
        chain_id=8453,
        merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-base",
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E"
    ),
    "arbitrum": ChainConfig(
        name="Arbitrum",
        rpc_env_var="ARBITRUM_RPC_URL",
        chain_id=42161,
        merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-arbitrum",
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E"
    ),
    "sonic": ChainConfig(
        name="Sonic",
        rpc_env_var="SONIC_RPC_URL",
        chain_id=146,
        merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-sonic",
        raft_address="0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204"
    )
}

# Blacklist configuration
# Format: {"chain_id": {"token_symbols": [], "token_addresses": [], "ark_addresses": [], "vault_ids": []}}
BLACKLIST = {
    1: {  # Mainnet
        "token_symbols": [],  # Skip claiming rEUL on Mainnet
        "token_addresses": ["0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"],  # USDC address
        "ark_addresses": ["0x2d0Afbf4f6bB188638E281c430EdED5610F0AF14"],
        "vault_ids": []
    },
    8453: {  # Base
        "token_symbols": [],
        "token_addresses": [],
        "ark_addresses": [],
        "vault_ids": []
    },
    42161: {  # Arbitrum
        "token_symbols": [],
        "token_addresses": [],
        "ark_addresses": [],
        "vault_ids": []
    },
    146: {  # Sonic
        "token_symbols": [],
        "token_addresses": [],
        "ark_addresses": [],
        "vault_ids": []
    }
}

# MINIMUM_CLAIM_VALUE in tokens - skip claims below this threshold
MINIMUM_CLAIM_VALUE = 0.1

# ABI for the ERC20 token
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

# ABI for the claim function
MERKL_ABI = [
    {
        "name": "claim",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"type": "address[]", "name": "users"},
            {"type": "address[]", "name": "tokens"},
            {"type": "uint256[]", "name": "amounts"},
            {"type": "bytes32[][]", "name": "proofs"}
        ],
        "outputs": []
    }
]

def setup_web3(chain_config: ChainConfig):
    w3 = Web3(Web3.HTTPProvider(os.getenv(chain_config.rpc_env_var)))
    account = Account.from_key(os.getenv('KEEPER_PRIVATE_KEY'))
    return w3, account

async def wait_for_transaction_receipt(w3, tx_hash, timeout=120):
    """Wait for a transaction receipt with timeout"""
    start_time = datetime.now()
    while True:
        try:
            receipt = w3.eth.get_transaction_receipt(tx_hash)
            if receipt is not None:
                return receipt
        except Exception:
            pass
        
        if (datetime.now() - start_time).total_seconds() > timeout:
            raise TimeoutError(f"Transaction {tx_hash.hex()} not mined after {timeout} seconds")
        
        await asyncio.sleep(2)  # Check every 2 seconds

async def fetch_ark_addresses_by_vault(session: aiohttp.ClientSession, subgraph_endpoint: str) -> Dict[str, List[str]]:
    """Fetch ARK addresses from the subgraph, grouped by vault ID"""
    query = """
    {
      vaults {
        id
        arks {
          id
        }
      }
    }
    """
    
    try:
        logger.info(f"Fetching ARK addresses from: {subgraph_endpoint}")
        async with session.post(
            subgraph_endpoint,
            json={"query": query},
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status != 200:
                logger.error(f"Error: Subgraph returned status {response.status}")
                return {}
            
            data = await response.json()
            vault_to_arks = {}
            ark_count = 0
            
            for vault in data.get("data", {}).get("vaults", []):
                vault_id = vault["id"]
                vault_to_arks[vault_id] = []
                
                for ark in vault.get("arks", []):
                    vault_to_arks[vault_id].append(ark["id"])
                    ark_count += 1
            
            logger.info(f"Found {ark_count} ARK addresses across {len(vault_to_arks)} vaults")
            return vault_to_arks
    except Exception as e:
        logger.error(f"Error fetching ARK addresses: {str(e)}")
        return {}

async def fetch_merkl_rewards(session: aiohttp.ClientSession, ark_address: str, chain_id: int):
    """Fetch rewards for an ARK address"""
    url = f"https://api.merkl.xyz/v4/users/{ark_address}/rewards?chainId={chain_id}"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return data
            logger.info(f"No rewards found for {ark_address} (status: {response.status})")
            return None
    except Exception as e:
        logger.error(f"Error fetching ANGL rewards for {ark_address}: {str(e)}")
        return None

async def claim_angl_rewards(w3, account, chain_config: ChainConfig, rewards_by_token: Dict[str, List[Dict]]):
    """Claim ANGL rewards for a chain"""
    try:
        # Prepare claim data
        all_users = []
        all_tokens = []
        all_amounts = []
        all_proofs = []
        
        for token_address, rewards in rewards_by_token.items():
            for reward in rewards:
                try:
                    all_users.append(Web3.to_checksum_address(reward['arkAddress']))
                    all_tokens.append(Web3.to_checksum_address(token_address))
                    all_amounts.append(int(reward['total']))
                    all_proofs.append(reward['proofs'])
                except Exception as e:
                    logger.error(f"Error processing reward data: {str(e)}")
                    logger.error(f"Token: {token_address}")
                    logger.error(f"ARK: {reward['arkAddress']}")
                    return None, None
        
        if not all_users:
            logger.info(f"{chain_config.name} - No rewards to claim")
            return None, None
            
        # Create MERKL distributor contract
        contract = w3.eth.contract(
            address=chain_config.merkl_distributor,
            abi=MERKL_ABI
        )
        
        # Get current gas price
        gas_price = w3.eth.gas_price
        
        # Estimate gas
        try:
            estimate = contract.functions.claim(
                all_users,
                all_tokens,
                all_amounts,
                all_proofs
            ).estimate_gas({
                'from': account.address,
                'gasPrice': gas_price
            })
            logger.info(f"{chain_config.name} - Estimated gas for claim: {estimate}")
        except Exception as e:
            logger.error(f"{chain_config.name} - Gas estimation failed: {str(e)}")
            logger.error(f"{chain_config.name} - Transaction would likely fail. Skipping.")
            return None, None
        
        tx = contract.functions.claim(
            all_users,
            all_tokens,
            all_amounts,
            all_proofs
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': int(estimate * 1.2),  # Add 20% buffer to gas estimate
            'gasPrice': int(gas_price * 1.2)
        })
        
        # Sign the transaction
        signed_tx = w3.eth.account.sign_transaction(tx, account.key)
        
        # Send the raw transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        logger.info(f"{chain_config.name} - Claim transaction sent: {tx_hash.hex()}")
        
        # Wait for transaction to be mined
        receipt = await wait_for_transaction_receipt(w3, tx_hash)
        logger.info(f"{chain_config.name} - Claim transaction confirmed: {receipt['status']}")
        
        return tx_hash, receipt
    except Exception as e:
        logger.error(f"{chain_config.name} - Error claiming ANGL rewards: {str(e)}")
        return None, None

def is_blacklisted(chain_id: int, token_address: str, token_symbol: str, ark_address: str, vault_id: str) -> bool:
    """Check if a token/ark/vault is blacklisted"""
    chain_blacklist = BLACKLIST.get(chain_id, {})
    
    # Check if token symbol is blacklisted
    if token_symbol in chain_blacklist.get("token_symbols", []):
        return True
        
    # Check if token address is blacklisted
    if token_address.lower() in [addr.lower() for addr in chain_blacklist.get("token_addresses", [])]:
        return True
        
    # Check if ARK address is blacklisted
    if ark_address.lower() in [addr.lower() for addr in chain_blacklist.get("ark_addresses", [])]:
        return True
        
    # Check if vault ID is blacklisted
    if vault_id in chain_blacklist.get("vault_ids", []):
        return True
        
    return False

async def process_rewards_for_chain(chain_config: ChainConfig):
    """Process rewards for a specific chain automatically"""
    logger.info(f"Processing {chain_config.name} ANGL rewards")
    w3, account = setup_web3(chain_config)
    
    async with aiohttp.ClientSession() as session:
        # Fetch all vault IDs and their ARK addresses
        vault_to_arks = await fetch_ark_addresses_by_vault(session, chain_config.subgraph_endpoint)
        
        if not vault_to_arks:
            logger.info(f"No ARK addresses found for {chain_config.name}")
            return
        
        # Collect all rewards data first (to match original script structure)
        all_rewards = []
        ark_to_vault_map = {}  # Map to track which vault each ARK belongs to
        
        for vault_id, arks in vault_to_arks.items():
            for ark in arks:
                # Store in lowercase to ensure case-insensitive matching
                ark_to_vault_map[ark.lower()] = vault_id
                rewards = await fetch_merkl_rewards(session, ark, chain_config.chain_id)
                if rewards:
                    all_rewards.append({'ark': ark, 'vault_id': vault_id, 'rewards': rewards})
        
        if not all_rewards:
            logger.info(f"No ANGL rewards found for any ARKs on {chain_config.name}")
            return
        
        # Combine all rewards for processing (similar to display_angl_rewards_summary function in original script)
        combined_rewards = []
        for reward_data in all_rewards:
            if reward_data['rewards']:
                combined_rewards.extend(reward_data['rewards'])

        # Group rewards by token (similar to display_angl_rewards_summary in original script)
        rewards_by_token = {}
        ark_to_tokens = {}  # Track which tokens belong to which ARK for reporting
        # print(all_rewards)
        for chain_data in combined_rewards:
            if chain_data['chain']['id'] == chain_config.chain_id and 'rewards' in chain_data:
                for reward in chain_data['rewards']:
                    ark_address = reward['recipient']
                    # Get the vault_id from our mapping, using lowercase for case-insensitive lookup
                    vault_id = ark_to_vault_map.get(ark_address.lower(), 'Unknown')
                    logger.info(f"Processing reward for ARK {ark_address} in vault {vault_id}")
                    
                    token_address = reward['token']['address']
                    token_symbol = reward['token'].get('symbol', 'Unknown')
                    
                    # Check if blacklisted
                    if is_blacklisted(chain_config.chain_id, token_address, token_symbol, ark_address, vault_id):
                        logger.info(f"Skipping blacklisted token {token_symbol} ({token_address}) for ARK {ark_address} in vault {vault_id}")
                        continue
                        
                    if token_address not in rewards_by_token:
                        rewards_by_token[token_address] = []
                    
                    # Track which ARK owns which tokens (for reporting)
                    if ark_address not in ark_to_tokens:
                        ark_to_tokens[ark_address] = set()
                    ark_to_tokens[ark_address].add(token_address)
                    
                    # Get amounts from the reward data
                    total_amount = int(reward.get('amount', '0'))
                    claimed_amount = int(reward.get('claimed', '0'))
                    pending_amount = int(reward.get('pending', '0'))
                    
                    # Calculate claimable amount (total - claimed)
                    claimable_amount = total_amount - claimed_amount
                    
                    if total_amount > 0:
                        # Calculate formatted amounts based on token decimals
                        token_decimals = reward['token'].get('decimals', 18)
                        total_formatted = float(total_amount) / (10 ** token_decimals)
                        claimed_formatted = float(claimed_amount) / (10 ** token_decimals)
                        claimable_formatted = float(claimable_amount) / (10 ** token_decimals)
                        
                        # Minimum threshold check
                        if claimable_formatted < MINIMUM_CLAIM_VALUE:
                            logger.info(f"Skipping small amount ({claimable_formatted} {token_symbol}) for {ark_address}")
                            continue
                        
                        rewards_by_token[token_address].append({
                            'arkAddress': ark_address,
                            'total': str(total_amount),  # Using total_amount exactly like the original script
                            'claimed': str(claimed_amount),
                            'claimable': str(claimable_amount),
                            'pending': str(pending_amount),
                            'totalFormatted': total_formatted,
                            'claimedFormatted': claimed_formatted,
                            'claimableFormatted': claimable_formatted,
                            'proofs': reward['proofs'],
                            'symbol': token_symbol
                        })
        
        # Remove tokens with no rewards
        for token_address in list(rewards_by_token.keys()):
            if not rewards_by_token[token_address]:
                del rewards_by_token[token_address]
        
        if not rewards_by_token:
            logger.info(f"No claimable rewards found for {chain_config.name}")
            return
            
        # Log reward summary
        logger.info(f"{chain_config.name} Rewards Summary:")
        for token_address, rewards in rewards_by_token.items():
            token_symbol = rewards[0]['symbol'] if rewards else 'Unknown'
            ark_count = len(set(r['arkAddress'] for r in rewards))
            total_claimable = sum(float(r['claimable']) / (10 ** 18) for r in rewards)
            logger.info(f"{token_symbol} ({token_address}): {total_claimable:.6f} claimable tokens across {ark_count} ARKs")
        
        # Claim rewards
        logger.info(f"Claiming rewards for {chain_config.name}...")
        tx_hash, receipt = await claim_angl_rewards(w3, account, chain_config, rewards_by_token)
        
        if tx_hash and receipt and receipt['status'] == 1:
            logger.info(f"Claim successful for {chain_config.name}")
            
            # Report which tokens were claimed for each ARK
            logger.info(f"Tokens claimed for ARKs on {chain_config.name}:")
            for ark, token_set in ark_to_tokens.items():
                token_symbols = []
                for token in token_set:
                    symbol = next((r['symbol'] for rs in rewards_by_token.values() 
                                  for r in rs if r['arkAddress'] == ark 
                                  and token_address == token), 'Unknown')
                    if symbol != 'Unknown':
                        token_symbols.append(symbol)
                
                if token_symbols:
                    logger.info(f"ARK {ark}: {', '.join(token_symbols)}")
        
        logger.info(f"Completed processing {chain_config.name}")

async def main():
    logger.info("Starting ANGL Auto Reward Claimer")
    
    # Process each chain sequentially
    for chain_name, chain_config in ANGL_CHAINS.items():
        logger.info(f"Processing chain: {chain_name}")
        try:
            await process_rewards_for_chain(chain_config)
        except Exception as e:
            logger.error(f"Error processing {chain_name}: {str(e)}")
    
    logger.info("All operations completed")

if __name__ == "__main__":
    asyncio.run(main()) 