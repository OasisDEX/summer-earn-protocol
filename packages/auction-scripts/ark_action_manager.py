from web3 import Web3
from eth_account import Account
import asyncio
import os
from dotenv import load_dotenv
from typing import NamedTuple, List, Dict, Optional, Set, Tuple
from datetime import datetime
import aiohttp
import json
import sys
import logging
from multicall import Call, Multicall
from multicall.utils import await_awaitable

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("ARK Action Manager")

# Load environment variables
load_dotenv()

# Add this at the top of the file with other global variables
commander_processed_counts = {}
# Track auctions started in current run
current_run_auctions = {}

class ChainConfig(NamedTuple):
    name: str
    rpc_env_var: str
    chain_id: int
    raft_address: str
    subgraph_endpoint: str
    auctions_subgraph_endpoint: str
    interval: int  # seconds between runs
    multicall_address: str

# Chain configurations
CHAINS = {
    "mainnet": ChainConfig(
        name="Mainnet",
        rpc_env_var="MAINNET_RPC_URL",
        chain_id=1,
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol",
        auctions_subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions",
        interval=60*60,  # 1 hour
        multicall_address="0xcA11bde05977b3631167028862bE2a173976CA11"  # Multicall3 address
    ),
    "base": ChainConfig(
        name="Base",
        rpc_env_var="BASE_RPC_URL",
        chain_id=8453,
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-base",
        auctions_subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions-base",
        interval=60*60,  # 1 hour
        multicall_address="0xcA11bde05977b3631167028862bE2a173976CA11"  # Multicall3 address
    ),
    "arbitrum": ChainConfig(
        name="Arbitrum",
        rpc_env_var="ARBITRUM_RPC_URL",
        chain_id=42161,
        raft_address="0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-arbitrum",
        auctions_subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions-arbitrum",
        interval=60*60,  # 1 hour
        multicall_address="0xcA11bde05977b3631167028862bE2a173976CA11"  # Multicall3 address
    ),
    "sonic": ChainConfig(
        name="Sonic",
        rpc_env_var="SONIC_RPC_URL",
        chain_id=146,
        raft_address="0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-protocol-sonic",
        auctions_subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions-sonic",
        interval=60*60,  # 1 hour
        multicall_address="0x"  # No Multicall for Sonic
    )
}

# ARK action configuration
# Format: {pattern: action_type}
ARK_ACTIONS = {
    "morpho": "sweepAndStart",  # ARKs with "morpho" in their name
    "aave": "sweepAndStart",  # ARKs with "aave" in their name
    "euler": "sweepAndStart",  # ARKs with "euler" in their name
    "moonwell": "harvestAndStart", # ARKs with "moonwell" in their name
    "gearbox": "sweepAndStart", # ARKs with "gearbox" in their name
    "silo": "harvestAndStart", # ARKs with "silo" in their name
    "SkyRewards": "harvestAndStart" # ARKs with "SkyRewards" in their name
}

# Token configuration for each ARK type and chain
# Format: {pattern: {chain_id: [(token_address, threshold)]}}
ARK_TOKENS = {
    "morpho": {
        1: [  # Mainnet tokens
            ("0x58D97B57BB95320F9a05dC918Aef65434969c2B2", 30),  # MORPHO
            ("0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66", 200),  # syrup

        ],
        8453: [  # Base tokens
            ("0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842", 50),  # Base MORPHO
            ("0x1C7a460413dD4e964f96D8dFC56E7223cE88CD85", 500),  # Base SEAM
            ("0xA88594D404727625A9437C3f886C7643872296AE", 2000),  # Base WELL
        ]
    },
    "aave": {
        146: [('0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131', 500)] # aWS
    },
    "euler": {
        # 1: [("0xf3e621395fc714b90da337aa9108771597b4e696", 10)],
        # 8453: [("0xE08e1f00D388E201e48842E53fA96195568e6813", 10)],
        146: [('0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38', 100)] # wS
    },
    "gearbox": {
        1: [('0xBa3335588D9403515223F109EdC4eB7269a9Ab5D', 40000)] # gear
    }
}

# Harvest method configuration for different ARK types
# Format: {pattern: {chain_id: {contract_address: address, abi: ABI, claimable_function: (function_name, [(arg_name, value)]), args_function: (function_name, [(arg_name, value)])}}}
HARVEST_CONFIGS = {
    "SkyRewards": {
        1: {
            "contract_address": "0x0650CAF159C5A49f711e8169D4336ECB9b950275",  # SkyRewards
            "abi": [
                {
                    "inputs": [{"internalType":"address","name":"user","type":"address"}],"name":"earned","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],
                    "stateMutability": "view",
                    "type": "function"
                }
            ],
            "claimable_function": ("earned", [
                ("user", "$ARK_ADDRESS")
            ]),
            "ark_data": {
                "0x3d8c278f05f655f26dcbf828c084e5182fd8d409": "0x3d8c278f05f655f26dcbf828c084e5182fd8d409"
            },
            "reward_threshold": 1000000000000000000000  # Minimum reward amount to trigger harvest (in token units)
        }
    },
    "moonwell": {
        8453: {
            "contract_address": "0xe9005b078701e2A0948D2EaC43010D35870Ad9d2",  # Moonwell rewards distributor
            "abi": [
                {
                    "inputs": [{"name":"mToken","type":"address"},{"name": "user", "type": "address"}],
                    "name": "getOutstandingRewardsForUser",
                    "outputs": [
                        {
                            "components": [
                            {
                                "internalType": "address",
                                "name": "emissionToken",
                                "type": "address"
                            },
                            {
                                "internalType": "uint256",
                                "name": "totalAmount",
                                "type": "uint256"
                            },
                            {
                                "internalType": "uint256",
                                "name": "supplySide",
                                "type": "uint256"
                            },
                            {
                                "internalType": "uint256",
                                "name": "borrowSide",
                                "type": "uint256"
                            }
                            ],
                            "internalType": "struct MultiRewardDistributorCommon.RewardInfo[]",
                            "name": "",
                            "type": "tuple[]"
                        }
                    ],
                    "stateMutability": "view",
                    "type": "function"
                }
            ],
            "claimable_function": ("getOutstandingRewardsForUser", [
                ("mToken", "$ARK_MTOKEN"),  # Placeholder for mToken address
                ("user", "$ARK_ADDRESS")    # Placeholder for ARK address
            ]),
            "ark_data": {
                "0xe2ad084b9639ccc689217704577e538ca2c251e5": "0xb682c840B5F4FC58B20769E691A6fa1305A501a2",  # ARK address -> mToken address
                "0x07e33789cf837b52821c7cded1247938969008ef": "0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22"
            },
            "reward_threshold": 1000  # Minimum reward amount to trigger harvest (in token units)
        }
    },
    "silo": {
        146: {
            "contract_address": "0x2d3d269334485d2d876df7363e1a50b13220a7d8",  # Silo rewards distributor
            "abi": [
                {
                    "inputs": [{"internalType":"address","name":"_user","type":"address"},{"internalType":"string[]","name":"_programNames","type":"string[]"}],
                    "name": "getRewardsBalance",
                    "outputs": [
                        {"name": "unclaimedRewards", "type": "uint256"}
                    ],
                    "stateMutability": "view",
                    "type": "function"
                }
            ],
            "claimable_function": ("getRewardsBalance", [
                ("_user", "$ARK_ADDRESS"),           # Placeholder for ARK address
                ("_programNames", "$ARK_PROGRAMS")   # Placeholder for program names
            ]),
            "ark_data": {
                "0x5c841955d7ee3e2f7a077aa0aca3a7d724b15da2": ["wS_sUSDC_0020"],  # ARK address -> program names
                "0x42aade02448fdaf56bbb153b2984e3d53dc531c1": ["wS_sUSDC_0008"]
            },
            "reward_threshold": 200  # Minimum reward amount to trigger harvest (in token units)
        }
    }
}

# ABI for sweep and start auction
SWEEP_AND_START_ABI = [
    {
        "name": "sweepAndStartAuction",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "ark", "type": "address"},
            {"name": "tokens", "type": "address[]"}
        ],
        "outputs": []
    }
]

# ABI for harvest and start auction (placeholder)
HARVEST_AND_START_ABI = [
    {
        "name": "harvestAndStartAuction",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"internalType":"address","name":"ark","type":"address"},
            {"internalType":"bytes","name":"rewardData","type":"bytes"}
        ],
        "outputs": []
    }
]

# ABI for the ERC20 token to get the balance and symbol
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
    },
    {
        "constant": True,
        "inputs": [],
        "name": "decimals",
        "outputs": [{"name": "", "type": "uint8"}],
        "payable": False,
        "stateMutability": "view",
        "type": "function"
    }
]

RAFT_ABI = [
    {
        "inputs":[
            {"internalType":"address","name":"ark","type":"address"},
            {"internalType":"address[]","name":"tokens","type":"address[]"}
        ],
        "name":"sweepAndStartAuction","outputs":[],
        "stateMutability":"nonpayable",
        "type":"function"},
            {
        "name": "harvestAndStartAuction",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"internalType":"address","name":"ark","type":"address"},
            {"internalType":"bytes","name":"rewardData","type":"bytes"}
        ],
        "outputs": []
    }
]

# Query to get ARKs with their names
ARK_QUERY = """
{
  vaults {
    id
    arks(where:{name_not_contains_nocase:"BufferArk"}){
      id
      name
    }
  }
}
"""

# Query to get active auctions
AUCTIONS_QUERY = """
{
  auctions(where: { isFinalized: false }) {
    id
    auctionId
    ark {
      id
      address
      commander
    }
    rewardToken {
      id
    }
    isFinalized
    startTimestamp
  }
}
"""

class ArkInfo(NamedTuple):
    address: str
    name: str
    commander: str
    vault_id: str
    action: str

class TokenInfo(NamedTuple):
    address: str
    symbol: str
    balance: float
    balance_raw: int
    decimals: int

def setup_web3(chain_config: ChainConfig):
    """Setup web3 connection and account"""
    w3 = Web3(Web3.HTTPProvider(os.getenv(chain_config.rpc_env_var)))
    account = Account.from_key(os.getenv('KEEPER_PRIVATE_KEY'))
    return w3, account

async def fetch_arks_with_names(session: aiohttp.ClientSession, subgraph_endpoint: str) -> Dict[str, ArkInfo]:
    """Fetch ARKs with their names from the subgraph"""
    try:
        logger.info(f"Fetching ARKs from: {subgraph_endpoint}")
        async with session.post(
            subgraph_endpoint,
            json={"query": ARK_QUERY},
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status != 200:
                logger.error(f"Error: Subgraph returned status {response.status}")
                return {}
            
            data = await response.json()
            arks_by_address = {}
            ark_count = 0
            vaults = data.get("data", {}).get("vaults", [])
            for vault in vaults:
                vault_id = vault["id"]
                
                for ark in vault.get("arks", []):
                    ark_address = ark["id"]
                    ark_name = ark.get("name", "")
                    commander = vault_id
                    
                    # Determine action based on ARK name
                    action = "none"
                    for pattern, action_type in ARK_ACTIONS.items():
                        if pattern.lower() in ark_name.lower():
                            action = action_type
                            break
                    
                    arks_by_address[ark_address] = ArkInfo(
                        address=ark_address,
                        name=ark_name,
                        commander=commander,
                        vault_id=vault_id,
                        action=action
                    )
                    ark_count += 1
                    logger.debug(f"Added ARK {ark_address} to arks_by_address with action '{action}'")
            
            logger.info(f"Found {ark_count} ARKs")
            return arks_by_address
    except Exception as e:
        logger.error(f"Error fetching ARKs: {str(e)}")
        return {}

async def fetch_active_auctions(session: aiohttp.ClientSession, auctions_subgraph_endpoint: str) -> Dict[str, List[Dict]]:
    """Fetch active auctions from the auctions subgraph"""
    try:
        logger.info(f"Fetching active auctions from: {auctions_subgraph_endpoint}")
        async with session.post(
            auctions_subgraph_endpoint,
            json={"query": AUCTIONS_QUERY},
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status != 200:
                logger.error(f"Error: Auctions subgraph returned status {response.status}")
                return {}
            
            data = await response.json()
            auctions_by_commander = {}
            
            for auction in data.get("data", {}).get("auctions", []):
                commander = auction.get("ark", {}).get("commander")
                if commander:
                    if commander not in auctions_by_commander:
                        auctions_by_commander[commander] = []
                    auctions_by_commander[commander].append(auction)
            
            logger.info(f"Found {sum(len(auctions) for auctions in auctions_by_commander.values())} active auctions across {len(auctions_by_commander)} commanders")
            return auctions_by_commander
    except Exception as e:
        logger.error(f"Error fetching auctions: {str(e)}")
        return {}

def from_wei(value, decimals=18):
    """Convert raw token amount to float based on decimals"""
    return float(value) / (10 ** decimals)

async def get_token_balance(w3: Web3, token_address: str, ark_address: str) -> TokenInfo:
    """Get the balance and information of a token for an ARK address"""
    try:
        token_address = Web3.to_checksum_address(token_address)
        ark_address = Web3.to_checksum_address(ark_address)
        
        contract = w3.eth.contract(address=token_address, abi=ERC20_ABI)
        
        # Get token data
        symbol = await asyncio.to_thread(contract.functions.symbol().call)
        balance_raw = await asyncio.to_thread(contract.functions.balanceOf(ark_address).call)
        decimals = await asyncio.to_thread(contract.functions.decimals().call)
        
        # Calculate formatted balance
        balance = float(balance_raw) / (10 ** decimals)
        
        return TokenInfo(
            address=token_address,
            symbol=symbol,
            balance=balance,
            balance_raw=balance_raw,
            decimals=decimals
        )
    except Exception as e:
        logger.error(f"Error getting balance for token {token_address}: {str(e)}")
        return TokenInfo(
            address=token_address,
            symbol="Unknown",
            balance=0.0,
            balance_raw=0,
            decimals=18
        )

async def get_ark_token_balances_multicall(
    w3: Web3, 
    arks: List[ArkInfo], 
    chain_id: int,
    multicall_address: str
) -> Dict[str, Dict[str, TokenInfo]]:
    """
    Get token balances for multiple ARKs using Multicall
    
    Returns a dictionary mapping ARK addresses to token balances
    """
    if not multicall_address or multicall_address == "0x":
        logger.info("Multicall address not set for this chain, falling back to individual queries")
        return {}
    
    # Collect all tokens for all ARK patterns on this chain
    chain_tokens: Dict[str, List[Tuple[str, float]]] = {}
    for pattern, chain_tokens_map in ARK_TOKENS.items():
        if chain_id in chain_tokens_map:
            chain_tokens[pattern] = chain_tokens_map[chain_id]
    
    if not chain_tokens:
        logger.info(f"No tokens configured for chain ID {chain_id}")
        return {}
    
    # Build a mapping of ARK address to token addresses to check
    ark_to_tokens = {}
    for ark in arks:
        ark_to_tokens[ark.address] = []
        for pattern, tokens in chain_tokens.items():
            if pattern.lower() in ark.name.lower():
                ark_to_tokens[ark.address].extend(tokens)
    
    if not any(tokens for tokens in ark_to_tokens.values()):
        logger.info("No ARKs match token patterns")
        return {}

    # Prepare multicall data for balances, symbols, and decimals
    calls = []
    # For each ARK, check each token's balance, symbol, and decimals
    for ark_address, token_tuples in ark_to_tokens.items():
        for token_address, threshold in token_tuples:
            try:
                token_address = Web3.to_checksum_address(token_address)
                ark_address_checksum = Web3.to_checksum_address(ark_address)

                # Add balance call
                calls.append(
                    Call(
                        token_address,
                        ['balanceOf(address)(uint256)', ark_address_checksum],
                        [[f'{ark_address}_{token_address}_balance', None]]
                    )
                )
                
                # Add symbol call
                calls.append(
                    Call(
                        token_address,
                        'symbol()(string)',
                        [[f'{token_address}_symbol', None]]
                    )
                )
                
                # Add decimals call
                calls.append(
                    Call(
                        token_address,
                        'decimals()(uint8)',
                        [[f'{token_address}_decimals', None]]
                    )
                )
            except Exception as e:
                logger.error(f"Error preparing multicall for token {token_address}: {str(e)}")
    
    # Execute multicall
    try:
        logger.info(f"Executing multicall with {len(calls)} calls")
        
        # Create the Multicall object
        multicall = Multicall(
            calls=calls,
            _w3=w3,  # Pass the existing Web3 instance
        )
        
        # For async environments, use await_awaitable
        results = await asyncio.to_thread(lambda: multicall())

        # Process results
        ark_token_balances = {}
        for ark_address, token_tuples in ark_to_tokens.items():
            ark_token_balances[ark_address] = {}
            
            for token_address, threshold in token_tuples:
                try:
                    token_address_checksum = Web3.to_checksum_address(token_address)
                    
                    # Get balance, symbol, and decimals
                    balance_key = f'{ark_address}_{token_address}_balance'
                    symbol_key = f'{token_address}_symbol'
                    decimals_key = f'{token_address}_decimals'
                    if balance_key not in results or symbol_key not in results or decimals_key not in results:
                        continue
                    
                    # Check for None values and provide defaults if necessary
                    if results[balance_key] is None:
                        logger.warning(f"Received None for balance of token {token_address} for ARK {ark_address}, skipping")
                        continue
                        
                    if results[symbol_key] is None:
                        logger.warning(f"Received None for symbol of token {token_address}, using 'UNKNOWN'")
                        symbol = "UNKNOWN"
                    else:
                        symbol = results[symbol_key]
                        
                    if results[decimals_key] is None:
                        logger.warning(f"Received None for decimals of token {token_address}, using default 18")
                        decimals = 18
                    else:
                        decimals = int(results[decimals_key])
                    
                    balance_raw = int(results[balance_key])
                    
                    # Calculate formatted balance
                    balance = from_wei(balance_raw, decimals)
                    
                    # Only include tokens that exceed their threshold
                    if balance > threshold:
                        # Add to results
                        ark_token_balances[ark_address][token_address] = TokenInfo(
                            address=token_address_checksum,
                            symbol=symbol,
                            balance=balance,
                            balance_raw=balance_raw,
                            decimals=decimals
                        )
                        
                        logger.info(f"ARK {ark_address} has {balance} {symbol} (above threshold {threshold})")
                    else:
                        logger.info(f"Skipping {symbol} with balance {balance} (below threshold {threshold})")
                    
                except Exception as e:
                    logger.error(f"Error processing multicall result for token {token_address}: {str(e)}")
        
        # Remove ARKs with no token balances
        return {ark: tokens for ark, tokens in ark_token_balances.items() if tokens}
        
    except Exception as e:
        logger.error(f"Error executing multicall: {str(e)}")
        return {}

def to_checksum_address(address: str) -> str:
    """Convert an address to checksum format."""
    return Web3.to_checksum_address(address)

def checksum_dict(d: dict) -> dict:
    """Recursively convert all addresses in a dictionary to checksum format."""
    if isinstance(d, dict):
        return {k: checksum_dict(v) for k, v in d.items()}
    elif isinstance(d, list):
        return [checksum_dict(x) for x in d]
    elif isinstance(d, tuple) and len(d) == 2 and isinstance(d[0], str) and d[0].startswith('0x'):
        return (to_checksum_address(d[0]), d[1])
    elif isinstance(d, str) and d.startswith('0x'):
        return to_checksum_address(d)
    return d

# Convert all addresses to checksum format
ARK_TOKENS = checksum_dict(ARK_TOKENS)

async def get_ark_token_balances(
    w3: Web3, 
    ark_info: ArkInfo, 
    chain_id: int
) -> Dict[str, TokenInfo]:
    """Get balances for all tokens relevant to an ARK based on its name"""
    token_balances = {}
    
    # Find any ARK pattern match in the name
    matched_patterns = []
    for pattern in ARK_TOKENS.keys():
        if pattern.lower() in ark_info.name.lower():
            matched_patterns.append(pattern)
    
    if not matched_patterns:
        logger.info(f"No token configuration found for ARK {ark_info.name}")
        return token_balances
    
    # Get tokens for each matched pattern
    for pattern in matched_patterns:
        # Check if this chain has tokens defined for this pattern
        if chain_id not in ARK_TOKENS[pattern]:
            logger.info(f"No tokens defined for pattern '{pattern}' on chain {chain_id}")
            continue
        
        # Get tokens for this pattern and chain
        tokens = ARK_TOKENS[pattern][chain_id]
        logger.info(f"Checking {len(tokens)} tokens for ARK {ark_info.name} (pattern: {pattern})")
        
        # Check balance for each token
        for token_address, threshold in tokens:
            # Skip if we already checked this token
            if token_address in token_balances:
                continue
                
            token_info = await get_token_balance(w3, token_address, ark_info.address)
            
            # Only include tokens that exceed their threshold
            if token_info.balance > threshold:
                logger.info(f"Found balance for {token_info.symbol}: {token_info.balance} (threshold: {threshold})")
                token_balances[token_address] = token_info
            else:
                logger.info(f"Skipping {token_info.symbol} with balance {token_info.balance} (below threshold {threshold})")
    
    return token_balances

async def check_ark_tokens_for_action(
    w3: Web3, 
    arks: List[ArkInfo], 
    chain_config: ChainConfig
) -> Dict[str, Dict[str, TokenInfo]]:
    """
    Check token balances for a list of ARKs and return those with balances
    
    Returns a dictionary mapping ARK address to a dictionary of token balances
    """
    # For Sonic chain, use individual queries
    if chain_config.chain_id == 146 or not chain_config.multicall_address:
        logger.info(f"Using individual token balance queries for {chain_config.name}")
        arks_with_tokens = {}
        
        for ark_info in arks:
            # Get token balances for this ARK
            token_balances = await get_ark_token_balances(
                w3, 
                ark_info, 
                chain_config.chain_id
            )
            
            # If ARK has tokens with balances, add to results
            if token_balances:
                arks_with_tokens[ark_info.address] = token_balances
                token_symbols = [info.symbol for info in token_balances.values()]
                total_value = sum(info.balance for info in token_balances.values())
                logger.info(f"ARK {ark_info.name} has {len(token_balances)} tokens with balances: {', '.join(token_symbols)} (Total: ~{total_value:.6f})")
    else:
        # Use multicall for other chains
        logger.info(f"Using multicall for token balance queries on {chain_config.name}")
        arks_with_tokens = await get_ark_token_balances_multicall(
            w3,
            arks,
            chain_config.chain_id,
            chain_config.multicall_address
        )
        
        # Log results
        for ark_address, token_balances in arks_with_tokens.items():
            ark_info = next((a for a in arks if a.address == ark_address), None)
            if ark_info:
                token_symbols = [info.symbol for info in token_balances.values()]
                total_value = sum(info.balance for info in token_balances.values())
                logger.info(f"ARK {ark_info.name} has {len(token_balances)} tokens with balances: {', '.join(token_symbols)} (Total: ~{total_value:.6f})")
    
    return arks_with_tokens

async def can_process_ark(
    ark_info: ArkInfo, 
    active_auctions: Dict[str, List[Dict]],
    arks_by_vault: Dict[str, List[str]]
) -> bool:
    """
    Check if an ARK can be processed based on auction status and time-based limits
    
    This function ensures:
    1. The ARK doesn't already have an active auction
    2. The commander hasn't started more than 2 auctions in the last 24 hours
    """
    # monkey fix for sonic vault - to allow multiple auctions per day
    if ark_info.vault_id.lower() == "0x507A2D9E87DBD3076e65992049C41270b47964f8".lower():
        return True
    # Check if there's already an active auction for this ARK
    commander_auctions = active_auctions.get(ark_info.commander, [])
    for auction in commander_auctions:
        if auction['ark']['address'].lower() == ark_info.address.lower():
            logger.info(f"ARK {ark_info.address} ({ark_info.name}) already has an active auction")
            return False
    
    # Check number of auctions started in the last 24 hours
    current_time = int(datetime.now().timestamp())
    twenty_four_hours_ago = current_time - (24 * 60 * 60)
    
    # Count auctions from subgraph data
    recent_auctions = [
        auction for auction in commander_auctions 
        if int(auction['startTimestamp']) > twenty_four_hours_ago
    ]
    
    # Count auctions started in current run
    current_run_count = len(current_run_auctions.get(ark_info.commander, []))
    
    # Total recent auctions = subgraph auctions + current run auctions
    total_recent_auctions = len(recent_auctions) + current_run_count
    
    if total_recent_auctions >= 1:
        logger.info(f"Commander {ark_info.commander} has already started {total_recent_auctions} auctions in the last 24 hours (limit: 2)")
        return False
    
    logger.info(f"Commander {ark_info.commander} has {total_recent_auctions} auctions in the last 24 hours")
    
    return True

async def get_ark_claimable_rewards_multicall(
    w3: Web3,
    arks: List[ArkInfo],
    chain_id: int,
    multicall_address: str
) -> Dict[str, Dict[str, float]]:
    """
    Get claimable rewards for multiple ARKs using Multicall or individual calls
    
    Returns a dictionary mapping ARK addresses to reward amounts by token
    """
    # Identify which ARKs belong to which harvest configs
    ark_to_config = {}
    for ark in arks:
        for pattern, chain_configs in HARVEST_CONFIGS.items():
            if pattern.lower() in ark.name.lower() and chain_id in chain_configs:
                ark_to_config[ark.address] = (pattern, chain_configs[chain_id])
    
    if not ark_to_config:
        logger.info(f"No harvestable ARKs found for chain ID {chain_id}")
        return {}
    
    # If no multicall address, fall back to individual calls
    if 1 == 1:
        logger.info("Multicall address not set for this chain, falling back to individual queries")
        ark_rewards = {}
        
        for ark_address, (pattern, config) in ark_to_config.items():
            try:
                # Check if we have data for this ARK
                if ark_address not in config["ark_data"]:
                    logger.info(f"No data found for ARK {ark_address} in {pattern} config, skipping")
                    continue
                ark_address_checksum = Web3.to_checksum_address(ark_address)
                contract_address = Web3.to_checksum_address(config["contract_address"])
                # Create contract instance
                contract = w3.eth.contract(address=contract_address, abi=config["abi"])
                # Get function name and args
                func_name, func_args = config["claimable_function"]
                # Prepare call arguments
                call_args = []
                for arg_name, arg_value in func_args:
                    if arg_value == "$ARK_ADDRESS":
                        call_args.append(ark_address_checksum)
                    elif arg_value == "$ARK_MTOKEN":
                        # Get mToken address from ark_data
                        mtoken_address = config["ark_data"][ark_address]
                        call_args.append(Web3.to_checksum_address(mtoken_address))
                    elif arg_value == "$ARK_PROGRAMS":
                        # Get program names from ark_data
                        program_names = config["ark_data"][ark_address]
                        call_args.append(program_names)
                    else:
                        call_args.append(arg_value)
                # Call the function
                if func_name == "getRewardsBalance":
                    # For Silo, we need to pass ARK address first, then program names
                    print(call_args)
                    result = await asyncio.to_thread(contract.functions[func_name](*call_args).call)
                elif call_args:
                    result = await asyncio.to_thread(contract.functions[func_name](*call_args).call)
                else:
                    result = await asyncio.to_thread(contract.functions[func_name](ark_address_checksum).call)
                # Process result based on function type
                if func_name == "getRewardsBalance":
                    # For Silo's getRewardsBalance
                    amount = result
                    if amount > 0:
                        ark_rewards[ark_address] = {
                            contract_address: {
                                "amount": float(amount) / 1e18,
                                "amount_raw": amount,
                                "symbol": "SILO",
                                "decimals": 18
                            }
                        }
                else:
                    # Initialize rewards dictionary for this ARK
                    if ark_address not in ark_rewards:
                        ark_rewards[ark_address] = {}
                    
                    # For Moonwell's getOutstandingRewardsForUser
                    has_rewards = False  # Track if any rewards were added
                    for reward_info in result:
                        try:
                            token_address = reward_info[0]  # emissionToken
                            if token_address != "0xA88594D404727625A9437C3f886C7643872296AE":
                                continue
                            amount = reward_info[1]  # totalAmount
                            # Get token decimals and symbol
                            decimals = 18
                            symbol = "WELL"
                            # Format amount
                            formatted_amount = float(amount) / (10 ** decimals)
                            # Skip if below threshold
                            if formatted_amount < config.get("reward_threshold", 0):
                                continue
                            
                            # Add to results
                            ark_rewards[ark_address][token_address] = {
                                "amount": formatted_amount,
                                "amount_raw": amount,
                                "symbol": symbol,
                                "decimals": decimals
                            }
                            has_rewards = True
                            
                        except Exception as e:
                            logger.error(f"Error processing token {token_address} reward: {str(e)}")
                            # Don't add anything when an exception occurs
                            # Just log the error and continue
                    
                    # If no rewards were found, remove this ARK from the results
                    if not has_rewards and ark_address in ark_rewards:
                        del ark_rewards[ark_address]
                
            except Exception as e:
                logger.error(f"Error getting rewards for ARK {ark_address}: {str(e)}")
                continue
        
        return ark_rewards
    
    # Multicall implementation
    try:
        # Prepare multicall data
        calls = []
        
        # For each ARK, add calls to check claimable rewards
        for ark_address, (pattern, config) in ark_to_config.items():
            try:
                # Check if we have data for this ARK
                if ark_address not in config["ark_data"]:
                    logger.info(f"No data found for ARK {ark_address} in {pattern} config, skipping")
                    continue
                
                ark_address_checksum = Web3.to_checksum_address(ark_address)
                contract_address = Web3.to_checksum_address(config["contract_address"])
                
                # Get function name and args
                func_name, func_args = config["claimable_function"]
                
                # Prepare call arguments
                call_args = []
                for arg_name, arg_value in func_args:
                    if arg_value == "$ARK_ADDRESS":
                        call_args.append(ark_address_checksum)
                    elif arg_value == "$ARK_MTOKEN":
                        # Get mToken address from ark_data
                        mtoken_address = config["ark_data"][ark_address]
                        call_args.append(Web3.to_checksum_address(mtoken_address))
                    elif arg_value == "$ARK_PROGRAMS":
                        # Get program names from ark_data
                        program_names = config["ark_data"][ark_address]
                        call_args.append(program_names)
                    else:
                        call_args.append(arg_value)
                # Build function call spec
                if call_args:
                    if func_name == "getRewardsBalance":
                        # For Silo's getRewardsBalance
                        call_spec = [f"{func_name}(address,string[])(uint256)", *call_args]
                    else:
                        # For Moonwell's getOutstandingRewardsForUser
                        call_spec = [f"{func_name}(address,address)(tuple[])", *call_args]
                else:
                    call_spec = f"{func_name}(address)(address[],uint256[])"
                    call_args = [ark_address_checksum]
                
                # Add the call
                calls.append(
                    Call(
                        contract_address,
                        call_spec,
                        [[f"{ark_address}_rewards", None]]
                    )
                )
                
            except Exception as e:
                logger.error(f"Error preparing claimable rewards multicall for ARK {ark_address}: {str(e)}")
        
        if not calls:
            logger.info("No valid multicall requests could be prepared")
            return {}
        
        # Execute multicall
        logger.info(f"Executing rewards multicall with {len(calls)} calls")
        print("calls",calls)
        # Create the Multicall object
        multicall = Multicall(
            calls=calls,
            _w3=w3
        )
        
        # For async environments, use await_awaitable
        results = await asyncio.to_thread(lambda: multicall())
        print("results",results)
        # Process results
        ark_rewards = {}
        
        for ark_address, (pattern, config) in ark_to_config.items():
            # Get results key
            result_key = f"{ark_address}_rewards"
            
            # Check if this ARK has results
            if result_key not in results:
                continue
            
            # Get the result
            result = results[result_key]
            
            # Skip if no rewards
            if not result:
                continue
            
            # Create rewards dictionary for this ARK
            ark_rewards[ark_address] = {}
            
            # Process result based on function type
            if config["claimable_function"][0] == "getRewardsBalance":
                # For Silo's getRewardsBalance
                amount = result
                if amount > 0:
                    ark_rewards[ark_address][config["contract_address"]] = {
                        "amount": float(amount) / 1e18,
                        "amount_raw": amount,
                        "symbol": "SILO",
                        "decimals": 18
                    }
            else:
                # For Moonwell's getOutstandingRewardsForUser
                has_rewards = False  # Track if any rewards were added
                for reward_info in result:
                    try:
                        token_address = reward_info[0]  # emissionToken
                        amount = reward_info[1]  # totalAmount
                        
                        # Try to get token info
                        token_contract = w3.eth.contract(address=Web3.to_checksum_address(token_address), abi=ERC20_ABI)
                        
                        # Get token decimals and symbol
                        decimals = await asyncio.to_thread(token_contract.functions.decimals().call)
                        symbol = await asyncio.to_thread(token_contract.functions.symbol().call)
                        
                        # Format amount
                        formatted_amount = float(amount) / (10 ** decimals)
                        
                        # Skip if below threshold
                        if formatted_amount < config.get("reward_threshold", 0):
                            continue
                        
                        # Add to results
                        ark_rewards[ark_address][token_address] = {
                            "amount": formatted_amount,
                            "amount_raw": amount,
                            "symbol": symbol,
                            "decimals": decimals
                        }
                        has_rewards = True
                        
                    except Exception as e:
                        logger.error(f"Error processing token {token_address} reward: {str(e)}")
                        # Don't add anything when an exception occurs
                        # Just log the error and continue
                    
                    # If no rewards were found, remove this ARK from the results
                    if not has_rewards and ark_address in ark_rewards:
                        del ark_rewards[ark_address]
        
        return ark_rewards
        
    except Exception as e:
        logger.error(f"Error executing rewards multicall: {str(e)}")
        return {}

async def check_ark_rewards_for_harvest(
    w3: Web3,
    arks: List[ArkInfo],
    chain_config: ChainConfig
) -> Dict[str, Dict[str, Dict]]:
    """
    Check claimable rewards for a list of ARKs and return those with claimable rewards
    
    Returns a dictionary mapping ARK address to a dictionary of token rewards
    """
    logger.info(f"Checking claimable rewards for {len(arks)} ARKs on {chain_config.name}")
    # Get rewards using multicall
    arks_with_rewards = await get_ark_claimable_rewards_multicall(
        w3,
        arks,
        chain_config.chain_id,
        chain_config.multicall_address
    )
    
    # Filter out ARKs with empty rewards dictionaries
    filtered_rewards = {
        ark_address: token_rewards 
        for ark_address, token_rewards in arks_with_rewards.items() 
        if token_rewards
    }
    
    # Log results
    for ark_address, token_rewards in filtered_rewards.items():
        ark_info = next((a for a in arks if a.address == ark_address), None)
        if ark_info:
            reward_tokens = [f"{info['amount']} {info['symbol']}" for info in token_rewards.values()]
            logger.info(f"ARK {ark_info.name} has {len(token_rewards)} claimable rewards: {', '.join(reward_tokens)}")
    
    return filtered_rewards

async def process_chain(chain_config: ChainConfig):
    """Process a single chain"""
    logger.info(f"Processing chain: {chain_config.name}")
    w3, account = setup_web3(chain_config)
    
    # Reset the commander processed counts at the start of each chain processing
    global commander_processed_counts
    commander_processed_counts = {}
    
    # Reset current run auctions at the start of each chain
    global current_run_auctions
    current_run_auctions = {}
    
    async with aiohttp.ClientSession() as session:
        # Fetch all ARKs with their names
        arks_by_address = await fetch_arks_with_names(session, chain_config.subgraph_endpoint)
        
        if not arks_by_address:
            logger.info(f"No ARKs found for {chain_config.name}")
            return
        
        # Group ARKs by vault
        arks_by_vault = {}
        for ark_info in arks_by_address.values():
            if ark_info.vault_id not in arks_by_vault:
                arks_by_vault[ark_info.vault_id] = []
            arks_by_vault[ark_info.vault_id].append(ark_info.address)
        
        # Get active auctions to check against
        active_auctions = await fetch_active_auctions(session, chain_config.auctions_subgraph_endpoint)
        
        # Categorize ARKs by action
        arks_by_action = {
            "sweepAndStart": [],
            "harvestAndStart": [],
            "none": []
        }
        
        # First categorize ARKs by action type
        for ark_address, ark_info in arks_by_address.items():
            if ark_info.action == "none":
                arks_by_action["none"].append(ark_info)
            else:
                arks_by_action[ark_info.action].append(ark_info)
        
        # Log initial action summary
        logger.info(f"Initial action summary for {chain_config.name}:")
        logger.info(f"- sweepAndStart: {len(arks_by_action['sweepAndStart'])} ARKs")
        logger.info(f"- harvestAndStart: {len(arks_by_action['harvestAndStart'])} ARKs")
        logger.info(f"- none: {len(arks_by_action['none'])} ARKs")
        
        # Process ARKs by action type
        for action_type, arks in arks_by_action.items():
            if action_type == "none" or not arks:
                continue
                
            logger.info(f"Checking tokens for {len(arks)} ARKs for {action_type}:")
            
            if action_type == "sweepAndStart":
                # For sweepAndStart, first check token balances
                arks_with_tokens = await check_ark_tokens_for_action(w3, arks, chain_config)
                
                if arks_with_tokens:
                    logger.info(f"Found {len(arks_with_tokens)} ARKs with token balances for sweepAndStart")
                    # Now check auction limits only for ARKs that have tokens
                    for ark_address, token_balances in arks_with_tokens.items():
                        ark_info = arks_by_address[ark_address]
                        # Check if this ARK can be processed based on auction limits
                        if await can_process_ark(ark_info, active_auctions, arks_by_vault):
                            # Track this ARK as being processed in current run
                            if ark_info.commander not in current_run_auctions:
                                current_run_auctions[ark_info.commander] = []
                            current_run_auctions[ark_info.commander].append({
                                'ark_address': ark_info.address,
                                'timestamp': int(datetime.now().timestamp())
                            })
                            
                            token_addresses = list(token_balances.keys())
                            token_symbols = [info.symbol for info in token_balances.values()]
                            
                            logger.info(f"ARK {ark_info.name} has tokens: {', '.join(token_symbols)}")
                            
                            # Here you would call the actual sweep function
                            await perform_sweep_and_start(w3, account, ark_info, token_addresses, chain_config)
                        else:
                            logger.info(f"Skipping ARK {ark_info.name} due to auction limits")
                else:
                    logger.info("No ARKs with token balances found for sweepAndStart")
            
            elif action_type == "harvestAndStart":
                # For harvestAndStart, first check claimable rewards
                logger.info(f"Checking claimable rewards for {len(arks)} ARKs")
                arks_with_rewards = await check_ark_rewards_for_harvest(w3, arks, chain_config)
                
                if arks_with_rewards:
                    logger.info(f"Found {len(arks_with_rewards)} ARKs with claimable rewards")
                    # Now check auction limits only for ARKs that have rewards
                    for ark_address, token_rewards in arks_with_rewards.items():
                        ark_info = arks_by_address[ark_address]
                        # Only process if there are actual rewards
                        if token_rewards:
                            # Check if this ARK can be processed based on auction limits
                            if await can_process_ark(ark_info, active_auctions, arks_by_vault):
                                # Track this ARK as being processed in current run
                                if ark_info.commander not in current_run_auctions:
                                    current_run_auctions[ark_info.commander] = []
                                current_run_auctions[ark_info.commander].append({
                                    'ark_address': ark_info.address,
                                    'timestamp': int(datetime.now().timestamp())
                                })
                                
                                reward_descriptions = [f"{info['amount']} {info['symbol']}" for info in token_rewards.values()]
                                
                                logger.info(f"ARK {ark_info.name} has claimable rewards: {', '.join(reward_descriptions)}")
                                
                                # Call harvest function
                                await perform_harvest_and_start(w3, account, ark_info.address, chain_config)
                            else:
                                logger.info(f"Skipping ARK {ark_info.name} due to auction limits")
                else:
                    logger.info("No ARKs with claimable rewards found for harvestAndStart")

async def perform_sweep_and_start(w3, account, ark_info: ArkInfo, token_addresses: List[str], chain_config: ChainConfig):
    try:
        ark_address = ark_info.address
        raft_address= chain_config.raft_address
        chain_name = chain_config.name
        contract = w3.eth.contract(
            address=raft_address,
            abi=RAFT_ABI
        )
        
        # Convert addresses to checksum format
        ark_address_checksum = Web3.to_checksum_address(ark_address)
        reward_addresses_checksum = [Web3.to_checksum_address(addr) for addr in token_addresses]
        
        tx = contract.functions.sweepAndStartAuction(
            ark_address_checksum,
            reward_addresses_checksum
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 5000000,  # Higher gas limit for this operation
        })
        try:
            estimated_gas = w3.eth.estimate_gas({
                'from': account.address,
                'to': contract.address,
                'data': tx['data']
            })
            print(f"{chain_name} - Estimated gas: {estimated_gas}")
            
            # Update transaction with estimated gas
            tx['gas'] = int(estimated_gas * 1.2)  # Add 20% buffer
        except Exception as e:
            print(f"{chain_name} - Transaction would fail! Simulation error: {str(e)}")
            return False    

        # Sign the transaction
        signed_tx = w3.eth.account.sign_transaction(tx, account.key)

        # Send the raw transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"{chain_name} - Sweep and start auction transaction sent: {tx_hash.hex()}")
        
        # Wait for transaction to be mined
        receipt = await wait_for_transaction_receipt(w3, tx_hash)
        print(f"{chain_name} - Sweep transaction confirmed: {receipt['status']}")
        
        return tx_hash, receipt
    except Exception as e:
        print(f"{chain_name} - Error sweeping rewards: {str(e)}")
        return None, None

async def perform_harvest_and_start(w3, account, ark_address: str, chain_config: ChainConfig):
    try:
        raft_address= chain_config.raft_address
        chain_name = chain_config.name
        contract = w3.eth.contract(
            address=raft_address,
            abi=RAFT_ABI
        )
        
        # Convert addresses to checksum format
        ark_address_checksum = Web3.to_checksum_address(ark_address)

        tx = contract.functions.harvestAndStartAuction(
            ark_address_checksum,
            bytes('', 'utf-8')  # Empty bytes instead of empty string
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 5000000,  # Higher gas limit for this operation
        })
        try:
            estimated_gas = w3.eth.estimate_gas({
                'from': account.address,
                'to': contract.address,
                'data': tx['data']
            })
            print(f"{chain_name} - Estimated gas: {estimated_gas}")
            
            # Update transaction with estimated gas
            tx['gas'] = int(estimated_gas * 1.2)  # Add 20% buffer
        except Exception as e:
            print(f"{chain_name} - Transaction would fail! Simulation error: {str(e)}")
            return False    

        # Sign the transaction
        signed_tx = w3.eth.account.sign_transaction(tx, account.key)

        # Send the raw transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"{chain_name} - Harvest and start auction transaction sent: {tx_hash.hex()}")
        
        # Wait for transaction to be mined
        receipt = await wait_for_transaction_receipt(w3, tx_hash)
        print(f"{chain_name} - Harvest transaction confirmed: {receipt['status']}")
        
        return tx_hash, receipt
    except Exception as e:
        print(f"{chain_name} - Error harvesting rewards: {str(e)}")
        return None, None

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

async def main():
    """Main function to run the ARK action manager"""
    logger.info("Starting ARK Action Manager")
    
    for chain_name, chain_config in CHAINS.items():
        try:
            await process_chain(chain_config)
        except Exception as e:
            logger.error(f"Error processing chain {chain_name}: {str(e)}")
    
    logger.info("Completed processing all chains. Terminating...")

if __name__ == "__main__":
    asyncio.run(main()) 