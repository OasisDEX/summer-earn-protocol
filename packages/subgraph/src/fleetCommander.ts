import { Deposit as DepositEvent, Withdraw as WithdrawEvent } from "../generated/templates/FleetCommanderTemplate/FleetCommander";
import { getOrCreateAccount, getOrCreateToken, getOrCreateVault } from "./common/initializers";
import { Address, BigDecimal, BigInt, ethereum } from "@graphprotocol/graph-ts";
import { formatAmount } from "./common/utils";
import { Account, Deposit, Token, Vault, Withdraw } from "../generated/schema";
import { TokenPrice, getTokenPriceInUSD } from "./common/priceHelpers";
import { FleetCommander as FleetCommanderContract } from "../generated/templates/FleetCommanderTemplate/FleetCommander";
import * as utils from "./common/utils";
import * as constants from "./common/constants";

export function handleDeposit(event: DepositEvent): void {
    const vault = getOrCreateVault(event.address, event.block)
    const account = getOrCreateAccount(event.params.sender.toHexString());

    const depositToken = getOrCreateToken(Address.fromString(vault.inputToken))
    const priceInUSD = getTokenPriceInUSD(Address.fromString(vault.inputToken), event.block.number);
    const normalizedAmount = formatAmount(event.params.assets, BigInt.fromI32(depositToken.decimals));
    const normalizedAmountUSD = normalizedAmount.times(priceInUSD.price);

    createDepositEventEntity(event, normalizedAmountUSD, account, vault, depositToken);

    updateVault(event, vault, depositToken, priceInUSD);

    vault.save();
}

export function handleWithdraw(event: WithdrawEvent): void {
    const vault = getOrCreateVault(event.address, event.block);
    const account = getOrCreateAccount(event.params.owner.toHexString());

    const priceInUSD = getTokenPriceInUSD(Address.fromString(vault.inputToken), event.block.number);
    const depositToken = getOrCreateToken(Address.fromString(vault.inputToken))
    const normalizedAmount = formatAmount(event.params.assets, BigInt.fromI32(depositToken.decimals));
    const normalizedAmountUSD = normalizedAmount.times(priceInUSD.price);

    createWithdrawEventEntity(event, normalizedAmountUSD, account, vault, depositToken);

    updateVault(event, vault, depositToken, priceInUSD);

    vault.save();
}

function createDepositEventEntity(event: DepositEvent, normalizedAmountUSD: BigDecimal, account: Account, vault: Vault, depositToken: Token): void {
    const deposit = new Deposit(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`);
    deposit.amount = event.params.assets;
    deposit.amountUSD = normalizedAmountUSD;
    deposit.from = account.id;
    deposit.to = vault.id;
    deposit.blockNumber = event.block.number;
    deposit.timestamp = event.block.timestamp;
    deposit.vault = vault.id;
    deposit.asset = depositToken.id;
    deposit.protocol = vault.protocol;
    deposit.logIndex = event.logIndex.toI32();
    deposit.hash = event.transaction.hash.toHexString();
    deposit.save();
}

function createWithdrawEventEntity(event: WithdrawEvent, normalizedAmountUSD: BigDecimal, account: Account, vault: Vault, depositToken: Token): void {
    const withdraw = new Withdraw(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`);
    withdraw.amount = event.params.assets;
    withdraw.amountUSD = normalizedAmountUSD;
    withdraw.from = account.id;
    withdraw.to = vault.id;
    withdraw.blockNumber = event.block.number;
    withdraw.timestamp = event.block.timestamp;
    withdraw.vault = vault.id;
    withdraw.asset = depositToken.id;
    withdraw.protocol = vault.protocol;
    withdraw.logIndex = event.logIndex.toI32();
    withdraw.hash = event.transaction.hash.toHexString();
    withdraw.save();
}

function updateVault(event: ethereum.Event, vault: Vault, depositToken: Token, priceInUSD: TokenPrice): void {
    const vaultContract = FleetCommanderContract.bind(event.address);
    const totalAssets = utils.readValue<BigInt>(
        vaultContract.try_totalAssets(),
        constants.BIGINT_ZERO
    );
    vault.inputTokenBalance = totalAssets;
    const totalSupply = utils.readValue<BigInt>(
        vaultContract.try_totalSupply(),
        constants.BIGINT_ZERO
    );
    vault.outputTokenSupply = totalSupply;

    const pricePerShare = totalAssets.toBigDecimal().div(totalSupply.toBigDecimal());
    vault.totalValueLockedUSD = formatAmount(totalAssets, BigInt.fromI32(depositToken.decimals)).times(priceInUSD.price);
    vault.outputTokenPriceUSD = pricePerShare.times(priceInUSD.price);

    vault.pricePerShare = pricePerShare;
}
