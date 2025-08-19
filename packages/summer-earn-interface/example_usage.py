#!/usr/bin/env python3
"""
Example usage of the Summer Earn Intent Solver
Demonstrates how to use the solver programmatically
"""

import time
from simple_solver import IntentSolver

def main():
    """Example usage of the IntentSolver"""
    print("🚀 Summer Earn Intent Solver - Example Usage")
    print("=" * 50)
    
    try:
        # Initialize the solver
        print("🔧 Initializing solver...")
        solver = IntentSolver()
        
        # Check initial status
        print("\n📊 Checking initial status...")
        bond_status = solver.check_bond_status()
        print(f"Bond amount: {solver.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
        print(f"Vouched: {bond_status['is_vouched']}")
        
        # Check balances
        print("\n💰 Checking balances...")
        summer_balance = solver.check_balance(solver.summer_token)
        usdc_balance = solver.check_balance(solver.usdc_token)
        print(f"SUMMER: {solver.w3.from_wei(summer_balance, 'ether')}")
        print(f"USDC: {solver.w3.from_wei(usdc_balance, 'ether')}")
        
        # Create bond if needed
        if not bond_status["is_vouched"]:
            print("\n🏦 Creating bond...")
            tx_hash = solver.create_bond()
            if tx_hash:
                print(f"Bond creation transaction: {tx_hash}")
                print("Waiting for confirmation...")
                time.sleep(30)  # Wait for transaction confirmation
                
                # Check bond status again
                bond_status = solver.check_bond_status()
                print(f"Updated bond amount: {solver.w3.from_wei(bond_status['bond_amount'], 'ether')} SUMMER")
                print(f"Vouched: {bond_status['is_vouched']}")
        
        # Example: Create and solve a sample intent
        if bond_status["is_vouched"]:
            print("\n🧪 Creating and solving sample intent...")
            
            # Create sample intent
            sample_intent = solver.create_sample_intent()
            print(f"Sample intent created for user: {sample_intent['user']}")
            print(f"Required notional: {solver.w3.from_wei(sample_intent['requiredNotional'], 'ether')} USDC")
            print(f"Target yield: {solver.w3.from_wei(sample_intent['targetYield'], 'ether')} USDC")
            print(f"Term: {sample_intent['term']} days")
            
            # Check commitment status
            print("\n📋 Checking commitment status...")
            try:
                commitment = solver.intent_handler_contract.functions.hasCommitted(sample_intent).call()
                print(f"Commitment: {commitment}")
            except Exception as e:
                print(f"Could not check commitment: {e}")
            
            # Solve the intent
            escrowed_yield = sample_intent["targetYield"]
            print(f"\n🔍 Solving intent with {solver.w3.from_wei(escrowed_yield, 'ether')} USDC escrowed...")
            
            # Note: This is commented out to prevent actual execution
            # Uncomment to actually solve the intent
            # tx_hash = solver.solve_intent(sample_intent, escrowed_yield)
            # if tx_hash:
            #     print(f"Intent solved! Transaction: {tx_hash}")
            # else:
            #     print("Failed to solve intent")
            
            print("⚠️  Intent solving commented out to prevent actual execution")
            print("   Uncomment the solve_intent call to actually solve intents")
        
        # Example: Monitor for intents
        print("\n👀 Starting intent monitoring (5 seconds)...")
        try:
            solver.monitor_intents(interval=5)
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped")
        
        print("\n✅ Example completed successfully!")
        
    except Exception as e:
        print(f"❌ Error in example: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
