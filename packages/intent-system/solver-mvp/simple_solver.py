#!/usr/bin/env python3
"""
Simple Intent Solver for Summer Earn Protocol
Interacts with IntentHandler contract to solve intents
"""

import json
import time
from typing import Dict, Any, Optional
from web3 import Web3
from eth_account import Account
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class IntentSolver:
    def __init__(self):
        # Base network configuration
        self.rpc_url = "https://mainnet.base.org"  # Base mainnet RPC
        self.chain_id = 8453
        
        # Contract addresses (Base staging)
        self.intent_handler = "0x5C98Bf93FdEaE98cCC0Af9371CA6189De4143c24"
        self.intent_bond_factory = "0x65c76bd69CAC8ff6Ddf4eF37d5bD61a7611d33f2"
        self.mock_oracle = "0xc5F12D38701D0C370775B8346f1B2dF3B0B85CE1"
        
        # Token addresses
        self.summer_token = "0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32"
        self.usdc_token = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        
        # Load private key from environment
        self.private_key = os.getenv("PRIVATE_KEY")
        if not self.private_key:
            raise ValueError("PRIVATE_KEY environment variable not set")
        
        self.account = Account.from_key(self.private_key)
        self.address = self.account.address
        
        # Load contract ABIs
        self.intent_handler_abi = self.load_abi("IntentHandler")
        self.intent_bond_factory_abi = self.load_abi("IntentBondFactory")
        
        # Initialize contract instances
        self.intent_handler_contract = self.w3.eth.contract(
            address=self.intent_handler, 
            abi=self.intent_handler_abi
        )
        self.intent_bond_factory_contract = self.w3.eth.contract(
            address=self.intent_bond_factory, 
            abi=self.intent_bond_factory_abi
        )
        
        print(f"🔧 Intent Solver initialized for address: {self.address}")
        print(f"🌐 Connected to Base network (Chain ID: {self.chain_id})")
        print(f"📋 Intent Handler: {self.intent_handler}")
        print(f"🏭 Bond Factory: {self.intent_bond_factory}")
        print(f"🔮 Mock Oracle: {self.mock_oracle}")
    
    def load_abi(self, contract_name: str) -> list:
        """Load ABI from the abis directory"""
        abi_path = f"src/abis/{contract_name}.ts"
        try:
            with open(abi_path, 'r') as f:
                content = f.read()
                # Extract the ABI array from the TypeScript file
                start = content.find('[')
                end = content.rfind(']') + 1
                abi_str = content[start:end]
                # Convert to Python list
                return json.loads(abi_str)
        except FileNotFoundError:
            print(f"⚠️  ABI file not found: {abi_path}")
            print("Using minimal ABI for basic functionality")
            return self.get_minimal_abi(contract_name)
    
    def get_minimal_abi(self, contract_name: str) -> list:
        """Return minimal ABI for basic contract interaction"""
        if contract_name == "IntentHandler":
            return [
                {
                    "inputs": [
                        {
                            "components": [
                                {"name": "user", "type": "address"},
                                {"name": "requiredNotional", "type": "uint256"},
                                {"name": "term", "type": "uint256"},
                                {"name": "targetYield", "type": "uint256"},
                                {"name": "token", "type": "address"},
                                {"name": "oracle", "type": "address"},
                                {"name": "expiry", "type": "uint256"}
                            ],
                            "internalType": "IIntentHandler.Intent",
                            "name": "intent",
                            "type": "tuple"
                        },
                        {"name": "escrowedYield", "type": "uint256"}
                    ],
                    "name": "solveIntent",
                    "outputs": [],
                    "stateMutability": "nonpayable",
                    "type": "function"
                },
                {
                    "inputs": [
                        {
                            "components": [
                                {"name": "user", "type": "address"},
                                {"name": "requiredNotional", "type": "uint256"},
                                {"name": "term", "type": "uint256"},
                                {"name": "targetYield", "type": "uint256"},
                                {"name": "token", "type": "address"},
                                {"name": "oracle", "type": "address"},
                                {"name": "expiry", "type": "uint256"}
                            ],
                            "internalType": "IIntentHandler.Intent",
                            "name": "intent",
                            "type": "tuple"
                        }
                    ],
                    "name": "settleIntent",
                    "outputs": [],
                    "stateMutability": "nonpayable",
                    "type": "function"
                },
                {
                    "inputs": [
                        {
                            "components": [
                                {"name": "user", "type": "address"},
                                {"name": "requiredNotional", "type": "uint256"},
                                {"name": "term", "type": "uint256"},
                                {"name": "targetYield", "type": "uint256"},
                                {"name": "token", "type": "address"},
                                {"name": "oracle", "type": "uint256"},
                                {"name": "expiry", "type": "uint256"}
                            ],
                            "internalType": "IIntentHandler.Intent",
                            "name": "intent",
                            "type": "tuple"
                        }
                    ],
                    "name": "hasCommitted",
                    "outputs": [
                        {"name": "requiredNotional", "type": "uint256"},
                        {"name": "arkAssets", "type": "uint256"},
                        {"name": "isCommited", "type": "bool"}
                    ],
                    "stateMutability": "view",
                    "type": "function"
                }
            ]
        elif contract_name == "IntentBondFactory":
            return [
                {
                    "inputs": [{"name": "solver", "type": "address"}],
                    "name": "createBond",
                    "outputs": [],
                    "stateMutability": "nonpayable",
                    "type": "function"
                },
                {
                    "inputs": [
                        {"name": "solver", "type": "address"},
                        {"name": "requiredAmount", "type": "uint256"}
                    ],
                    "name": "isSolverVouched",
                    "outputs": [{"name": "", "type": "bool"}],
                    "stateMutability": "view",
                    "type": "function"
                },
                {
                    "inputs": [{"name": "solver", "type": "address"}],
                    "name": "getSolverBondAmount",
                    "outputs": [{"name": "", "type": "uint256"}],
                    "stateMutability": "view",
                    "type": "function"
                }
            ]
        return []
    
    def check_balance(self, token_address: str) -> int:
        """Check token balance for the solver"""
        # Simple ERC20 balance check
        balance_abi = [
            {
                "inputs": [{"name": "account", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "", "type": "uint256"}],
                "stateMutability": "view",
                "type": "function"
            }
        ]
        
        token_contract = self.w3.eth.contract(address=token_address, abi=balance_abi)
        balance = token_contract.functions.balanceOf(self.address).call()
        return balance
    
    def check_bond_status(self) -> Dict[str, Any]:
        """Check solver's bond status"""
        try:
            bond_amount = self.intent_bond_factory_contract.functions.getSolverBondAmount(
                self.address
            ).call()
            
            # Check if solver is vouched (has sufficient bond)
            required_amount = self.w3.to_wei(1000, 'ether')  # 1000 SUMMER tokens
            is_vouched = self.intent_bond_factory_contract.functions.isSolverVouched(
                self.address, required_amount
            ).call()
            
            return {
                "bond_amount": bond_amount,
                "is_vouched": is_vouched,
                "required_amount": required_amount
            }
        except Exception as e:
            print(f"❌ Error checking bond status: {e}")
            return {"bond_amount": 0, "is_vouched": False, "required_amount": 0}
    
    def create_bond(self) -> Optional[str]:
        """Create a bond for the solver"""
        try:
            # Check if bond already exists
            bond_status = self.check_bond_status()
            if bond_status["bond_amount"] > 0:
                print(f"✅ Bond already exists: {self.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
                return None
            
            print("🏦 Creating solver bond...")
            
            # Build transaction
            transaction = self.intent_bond_factory_contract.functions.createBond(
                self.address
            ).build_transaction({
                'from': self.address,
                'gas': 200000,
                'gasPrice': self.w3.eth.gas_price,
                'nonce': self.w3.eth.get_transaction_count(self.address),
            })
            
            # Sign and send transaction
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.private_key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            print(f"✅ Bond creation transaction sent: {tx_hash.hex()}")
            return tx_hash.hex()
            
        except Exception as e:
            print(f"❌ Error creating bond: {e}")
            return None
    
    def solve_intent(self, intent_data: Dict[str, Any], escrowed_yield: int) -> Optional[str]:
        """Solve an intent by providing escrowed yield"""
        try:
            print(f"🔍 Solving intent for user: {intent_data['user']}")
            print(f"💰 Required notional: {self.w3.from_wei(intent_data['requiredNotional'], 'ether')} USDC")
            print(f"📅 Term: {intent_data['term']} days")
            print(f"🎯 Target yield: {self.w3.from_wei(intent_data['targetYield'], 'ether')} USDC")
            print(f"💎 Escrowed yield: {self.w3.from_wei(escrowed_yield, 'ether')} USDC")
            
            # Check if solver is vouched
            bond_status = self.check_bond_status()
            if not bond_status["is_vouched"]:
                print("❌ Solver is not vouched. Create a bond first.")
                return None
            
            # Check commitment status
            commitment = self.intent_handler_contract.functions.hasCommitted(intent_data).call()
            print(f"📋 Commitment status: {commitment}")
            
            # Build transaction
            transaction = self.intent_handler_contract.functions.solveIntent(
                intent_data, escrowed_yield
            ).build_transaction({
                'from': self.address,
                'gas': 300000,
                'gasPrice': self.w3.eth.gas_price,
                'nonce': self.w3.eth.get_transaction_count(self.address),
            })
            
            # Sign and send transaction
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.private_key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            print(f"✅ Intent solving transaction sent: {tx_hash.hex()}")
            return tx_hash.hex()
            
        except Exception as e:
            print(f"❌ Error solving intent: {e}")
            return None
    
    def settle_intent(self, intent_data: Dict[str, Any]) -> Optional[str]:
        """Settle a solved intent"""
        try:
            print(f"🏁 Settling intent for user: {intent_data['user']}")
            
            # Build transaction
            transaction = self.intent_handler_contract.functions.settleIntent(
                intent_data
            ).build_transaction({
                'from': self.address,
                'gas': 200000,
                'gasPrice': self.w3.eth.gas_price,
                'nonce': self.w3.eth.get_transaction_count(self.address),
            })
            
            # Sign and send transaction
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.private_key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            print(f"✅ Intent settlement transaction sent: {tx_hash.hex()}")
            return tx_hash.hex()
            
        except Exception as e:
            print(f"❌ Error settling intent: {e}")
            return None
    
    def monitor_intents(self, interval: int = 60):
        """Monitor for new intents to solve"""
        print(f"👀 Monitoring for intents every {interval} seconds...")
        print("Press Ctrl+C to stop monitoring")
        
        try:
            while True:
                print(f"\n⏰ {time.strftime('%Y-%m-%d %H:%M:%S')} - Checking for intents...")
                
                # Check bond status
                bond_status = self.check_bond_status()
                print(f"🏦 Bond status: {self.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
                print(f"✅ Vouched: {bond_status['is_vouched']}")
                
                # Check balances
                summer_balance = self.check_balance(self.summer_token)
                usdc_balance = self.check_balance(self.usdc_token)
                print(f"🪙 SUMMER balance: {self.w3.from_wei(summer_balance, 'ether')}")
                print(f"💵 USDC balance: {self.w3.from_wei(usdc_balance, 'ether')}")
                
                # Wait before next check
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped by user")
    
    def create_sample_intent(self) -> Dict[str, Any]:
        """Create a sample intent for testing"""
        current_time = int(time.time())
        
        return {
            "user": "0x1234567890123456789012345678901234567890",  # Sample ark address
            "requiredNotional": self.w3.to_wei(10000, 'ether'),  # 10,000 USDC
            "term": 30,  # 30 days
            "targetYield": self.w3.to_wei(500, 'ether'),  # 500 USDC target yield
            "token": self.usdc_token,
            "oracle": self.mock_oracle,
            "expiry": current_time + (30 * 24 * 60 * 60),  # 30 days from now
        }


def main():
    """Main function to run the solver"""
    print("🚀 Starting Summer Earn Intent Solver...")
    
    try:
        solver = IntentSolver()
        
        # Check initial status
        print("\n📊 Initial Status:")
        bond_status = solver.check_bond_status()
        print(f"Bond amount: {solver.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
        print(f"Vouched: {bond_status['is_vouched']}")
        
        # Create bond if needed
        if not bond_status["is_vouched"]:
            print("\n🏦 Creating bond...")
            tx_hash = solver.create_bond()
            if tx_hash:
                print(f"Bond creation transaction: {tx_hash}")
                print("Wait for confirmation before proceeding...")
                time.sleep(30)  # Wait for transaction confirmation
        
        # Interactive menu
        while True:
            print("\n" + "="*50)
            print("🎯 INTENT SOLVER MENU")
            print("="*50)
            print("1. Check bond status")
            print("2. Check balances")
            print("3. Solve sample intent")
            print("4. Monitor for intents")
            print("5. Exit")
            
            choice = input("\nSelect option (1-5): ").strip()
            
            if choice == "1":
                bond_status = solver.check_bond_status()
                print(f"Bond amount: {solver.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
                print(f"Vouched: {bond_status['is_vouched']}")
                
            elif choice == "2":
                summer_balance = solver.check_balance(solver.summer_token)
                usdc_balance = solver.check_balance(solver.usdc_token)
                print(f"SUMMER: {solver.w3.from_wei(summer_balance, 'ether')}")
                print(f"USDC: {solver.w3.from_wei(usdc_balance, 'ether')}")
                
            elif choice == "3":
                print("🧪 Solving sample intent...")
                sample_intent = solver.create_sample_intent()
                escrowed_yield = sample_intent["targetYield"]  # Escrow the target yield
                tx_hash = solver.solve_intent(sample_intent, escrowed_yield)
                if tx_hash:
                    print(f"Sample intent solved: {tx_hash}")
                
            elif choice == "4":
                solver.monitor_intents()
                
            elif choice == "5":
                print("👋 Goodbye!")
                break
                
            else:
                print("❌ Invalid option. Please try again.")
    
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
