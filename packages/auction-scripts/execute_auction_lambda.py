from web3 import Web3
from eth_account import Account
import asyncio
import os
from dotenv import load_dotenv
from typing import NamedTuple, List
from datetime import datetime, timedelta
import aiohttp
import json
import logging

# Load environment variables
load_dotenv()

# Configure basic logging in case Powertools import fails
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Try to use AWS Lambda Powertools for better logging if available
try:
    from aws_lambda_powertools import Logger
    logger = Logger(service="ArkAuctionExecutionManager")
except ImportError:
    logger.debug("AWS Lambda Powertools not available, using standard logging")

class ChainConfig(NamedTuple):
    name: str
    rpc_env_var: str
    contract_address: str
    subgraph_endpoint: str
    interval: int  # seconds between attempts

# Chain configurations
CHAINS = {
    "base": ChainConfig(
        name="Base",
        rpc_env_var="BASE_RPC_URL",
        contract_address="0x47548c3ca7365a1dfb27337B917332FAA999781d",
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions-base",
        interval=5*60  # 5 minutes
    ),
    "mainnet": ChainConfig(
        name="Mainnet",
        rpc_env_var="MAINNET_RPC_URL",
        contract_address=Web3.to_checksum_address("0x47548c3ca7365a1dfb27337B917332FAA999781d"),
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions",
        interval=5*60  # 5 minutes
    ),
    "sonic": ChainConfig(
        name="Sonic",
        rpc_env_var="SONIC_RPC_URL",
        contract_address=Web3.to_checksum_address("0x47548c3ca7365a1dfb27337B917332FAA999781d"),
        subgraph_endpoint="https://subgraph.staging.oasisapp.dev/summer-auctions-sonic",
        interval=5*60  # 5 minutes
    )
}

# ABI for the buyTokens function
ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "ark", "type": "address"},
            {"internalType": "address", "name": "rewardToken", "type": "address"}
        ],
        "name": "buyTokens",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def setup_web3(chain_config: ChainConfig):
    # Connect to the network
    w3 = Web3(Web3.HTTPProvider(os.getenv(chain_config.rpc_env_var)))
    
    # Set up account
    account = Account.from_key(os.getenv('KEEPER_PRIVATE_KEY'))
    logger.info(f"using keeper: {account.address}")
    # Create contract instance
    contract = w3.eth.contract(
        address=chain_config.contract_address, 
        abi=ABI
    )
    
    return w3, account, contract

def simulate_and_execute(w3, account, contract, ark_address, reward_token, chain_name):
    try:
        logger.info(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {chain_name} - Simulating transaction")
        logger.info(f"ARK: {ark_address}")
        
        # Build transaction for simulation
        transaction = contract.functions.buyTokens(
            Web3.to_checksum_address(ark_address),
            Web3.to_checksum_address(reward_token)
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 5000000
        })

        # Estimate gas
        try:
            estimated_gas = w3.eth.estimate_gas({
                'from': account.address,
                'to': contract.address,
                'data': transaction['data']
            })
            logger.info(f"{chain_name} - Estimated gas: {estimated_gas}")
            
            # Update transaction with estimated gas
            transaction['gas'] = int(estimated_gas * 1.2)  # Add 20% buffer
            
        except Exception as e:
            logger.error(f"{chain_name} - Transaction would fail! Simulation error: {str(e)}")
            return False

        logger.info(f"{chain_name} - Simulation successful, executing transaction...")
        
        signed_txn = w3.eth.account.sign_transaction(transaction, account.key)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
        logger.info(f"{chain_name} - Transaction sent! Hash: {tx_hash.hex()}")
        
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        success = receipt['status'] == 1
        logger.info(f"{chain_name} - Transaction confirmed! Status: {'Success' if success else 'Failed'}")
        logger.info(f"{chain_name} - Gas used: {receipt['gasUsed']}")
        
        return success

    except Exception as e:
        logger.error(f"{chain_name} - Error in transaction execution: {str(e)}")
        return False

AUCTIONS_QUERY = """
query GetAuctions {
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
    }
}
"""

async def fetch_active_auctions(session, endpoint, chain_name):
    try:
        logger.info(f"Querying subgraph at: {endpoint}")
        async with session.post(
            endpoint,
            json={"query": AUCTIONS_QUERY},
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status != 200:
                logger.error(f"Error: Subgraph returned status {response.status}")
                return []
            
            data = await response.json()
           
            auctions = data.get("data", {}).get("auctions", [])
            logger.info(f"Found {len(auctions)} active auctions on {chain_name}")
            return auctions
    except Exception as e:
        logger.error(f"Error fetching auctions: {str(e)}")
        return []

async def process_chain(chain_config: ChainConfig):
    logger.info(f"\nStarting {chain_config.name} chain processor...")
    w3, account, contract = setup_web3(chain_config)
    
    async with aiohttp.ClientSession() as session:

        try:
            current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"\n[{current_time}] Processing {chain_config.name}")
            logger.info(f"{chain_config.name} - Balance: {w3.from_wei(w3.eth.get_balance(account.address), 'ether')} ETH")
            
            # Fetch active auctions
            try:
                active_auctions = await fetch_active_auctions(session, chain_config.subgraph_endpoint, chain_config.name)
            except Exception as e:
                logger.error(f"{chain_config.name} - Error fetching auctions: {str(e)}")
                active_auctions = []
            
            # Process each active auction
            for auction in active_auctions:
                try:
                    logger.info(f"Processing auction {auction['id']}")
                    if not auction['isFinalized']:
                        ark_address = Web3.to_checksum_address(auction['ark']['address'])
                        reward_token = Web3.to_checksum_address(auction['rewardToken']['id'])
                        
                        logger.info(f"Attempting to buy tokens for ARK: {ark_address}")
                        logger.info(f"Reward token: {reward_token}")
                        
                        success = simulate_and_execute(
                            w3,
                            account,
                            contract,
                            ark_address,
                            reward_token,
                            chain_config.name
                        )
                        
                        if success:
                            logger.info(f"Successfully processed auction {auction['id']}")
                            await asyncio.sleep(30)
                        else:
                            logger.error(f"Failed to process auction {auction['id']}")
                except Exception as e:
                    logger.error(f"{chain_config.name} - Error processing auction {auction['id']}: {str(e)}")
                    continue
                    
            next_check = datetime.now() + timedelta(seconds=chain_config.interval)
            logger.info(f"\n{chain_config.name} - Sleeping for {chain_config.interval} seconds")
            logger.info(f"{chain_config.name} - Next check at: {next_check.strftime('%Y-%m-%d %H:%M:%S')}")
                
        except Exception as e:
            logger.error(f"{chain_config.name} - Critical error in main loop: {str(e)}")
            logger.info(f"{chain_config.name} - Attempting to restart in 60 seconds...")

async def main():
    # Create tasks for each chain
    tasks = [
        process_chain(chain_config)
        for chain_config in CHAINS.values()
    ]
    
    # Run all chain processors concurrently
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    # Run the async main function
    asyncio.run(main()) 