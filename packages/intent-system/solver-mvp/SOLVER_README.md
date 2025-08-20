# 🎯 Summer Earn Intent Solver

A simple Python solver that can interact with the Summer Earn Protocol's intent system on Base network.

## 🚀 Features

- **Bond Management**: Create and manage solver bonds
- **Intent Solving**: Solve intents by providing escrowed yield
- **Intent Settlement**: Settle completed intents
- **Balance Monitoring**: Check token balances and bond status
- **Continuous Monitoring**: Monitor for new intents to solve

## 📋 Prerequisites

- Python 3.8+
- Base network RPC access
- Private key with some BASE for gas fees
- SUMMER tokens for bonding (minimum 1000 tokens)

## 🛠️ Installation

1. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Set up environment variables**:
   Create a `.env` file in the same directory:
   ```bash
   PRIVATE_KEY=your_private_key_here_without_0x_prefix
   ```

   **⚠️ Security Warning**: Never commit your private key to version control!

## 🔧 Configuration

The solver is configured to work with the deployed contracts on Base staging:

- **IntentHandler**: `0x5C98Bf93FdEaE98cCC0Af9371CA6189De4143c24`
- **IntentBondFactory**: `0x65c76bd69CAC8ff6Ddf4eF37d5bD61a7611d33f2`
- **MockOracle**: `0xc5F12D38701D0C370775B8346f1B2dF3B0B85CE1`
- **SUMMER Token**: `0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32`
- **USDC Token**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

## 🚀 Usage

### Basic Usage

Run the solver:
```bash
python simple_solver.py
```

### Interactive Menu

The solver provides an interactive menu with the following options:

1. **Check bond status** - View current bond amount and vouched status
2. **Check balances** - Check SUMMER and USDC token balances
3. **Solve sample intent** - Solve a test intent (for development)
4. **Monitor for intents** - Continuously monitor for new intents
5. **Exit** - Close the solver

### Programmatic Usage

```python
from simple_solver import IntentSolver

# Initialize solver
solver = IntentSolver()

# Check bond status
bond_status = solver.check_bond_status()
print(f"Bond amount: {bond_status['bond_amount']}")

# Create bond if needed
if not bond_status["is_vouched"]:
    tx_hash = solver.create_bond()
    print(f"Bond created: {tx_hash}")

# Solve an intent
intent_data = {
    "user": "0x...",  # Ark address
    "requiredNotional": 10000000000000000000000,  # 10,000 USDC (18 decimals)
    "term": 30,  # 30 days
    "targetYield": 500000000000000000000,  # 500 USDC
    "token": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",  # USDC
    "oracle": "0xc5F12D38701D0C370775B8346f1B2dF3B0B85CE1",  # Mock Oracle
    "expiry": 1234567890,  # Unix timestamp
}

escrowed_yield = 500000000000000000000  # 500 USDC
tx_hash = solver.solve_intent(intent_data, escrowed_yield)
```

## 🔍 How It Works

### 1. Bond Creation
- Solver creates a bond by calling `IntentBondFactory.createBond()`
- Bond must contain at least 1000 SUMMER tokens to be "vouched"
- Only vouched solvers can solve intents

### 2. Intent Solving
- Solver calls `IntentHandler.solveIntent(intent, escrowedYield)`
- Must provide the target yield amount upfront
- Intent moves to "Solved" state
- 10-minute buffer period for keeper to commit assets

### 3. Intent Settlement
- After term completion, solver calls `IntentHandler.settleIntent(intent)`
- Yield is transferred to Ark's buffer via FleetCommander
- Solver keeps their bond intact

### 4. Commitment Checking
- Use `IntentHandler.hasCommitted(intent)` to check if Ark has committed
- Returns required notional, ark assets, and commitment status
- 10-minute buffer provides grace period for keepers

## ⚠️ Important Notes

### Gas Requirements
- **Bond Creation**: ~200,000 gas
- **Intent Solving**: ~300,000 gas  
- **Intent Settlement**: ~200,000 gas
- Ensure sufficient BASE for gas fees

### Token Requirements
- **SUMMER**: Minimum 1000 tokens for bonding
- **USDC**: Sufficient amount for escrowing yield
- **BASE**: For gas fees

### Security Considerations
- Keep private key secure and never share
- Use dedicated wallet for solver operations
- Monitor transactions and gas usage
- Test on testnet before mainnet

## 🧪 Testing

The solver includes a sample intent function for testing:

```python
# Create and solve a test intent
sample_intent = solver.create_sample_intent()
escrowed_yield = sample_intent["targetYield"]
tx_hash = solver.solve_intent(sample_intent, escrowed_yield)
```

## 🔧 Troubleshooting

### Common Issues

1. **"PRIVATE_KEY environment variable not set"**
   - Create `.env` file with your private key

2. **"Insufficient funds for gas"**
   - Add more BASE to your wallet for gas fees

3. **"Solver is not vouched"**
   - Create a bond with at least 1000 SUMMER tokens

4. **"ABI file not found"**
   - Solver will use minimal ABI, but full functionality may be limited

### Network Issues

- Ensure Base network RPC is accessible
- Check if contracts are deployed and accessible
- Verify contract addresses are correct

## 📚 API Reference

### IntentSolver Class

#### Methods

- `check_bond_status()` → Dict: Get current bond status
- `create_bond()` → Optional[str]: Create new solver bond
- `solve_intent(intent_data, escrowed_yield)` → Optional[str]: Solve an intent
- `settle_intent(intent_data)` → Optional[str]: Settle a solved intent
- `check_balance(token_address)` → int: Check token balance
- `monitor_intents(interval)` → None: Monitor for new intents

#### Properties

- `address`: Solver's wallet address
- `w3`: Web3 instance
- `intent_handler_contract`: IntentHandler contract instance
- `intent_bond_factory_contract`: IntentBondFactory contract instance

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is part of the Summer Earn Protocol and follows the same licensing terms.

## 🆘 Support

For issues or questions:
- Check the troubleshooting section
- Review contract documentation
- Open an issue in the repository
- Join the Summer Earn community

---

**Happy Solving! 🎯✨**
