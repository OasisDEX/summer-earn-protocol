import { expect } from "chai";
import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";
import { MockContract } from "@defi-wonderland/smock";

import { RoundsOutputVault, ERC4626, MockERC20PresetMinterPauser, MockERC4626 } from "../../typechain";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { expectSolidityDeepCompare } from "../utils/chaiHelpers";
import { mockERC4626, mockERC20 } from "../../scripts/test/contractsMocks";
import {
    ifMocksEnabled,
    asMock,
    Deployments,
    ProviderTypes,
    DeploymentFlags,
    DeploymentNetwork,
} from "contracts-utils";

/**
    @notice VaultDeferredOperation unit tests    
    
    @author Roberto Cano <robercano>
 */
describe("RoundsOutputVault", function () {
    let adminAccount: SignerWithAddress;
    let operatorAccount: SignerWithAddress;
    let unpriviledgedAccount: SignerWithAddress;
    let roundsOutputVault: RoundsOutputVault;
    let assetToken: MockERC20PresetMinterPauser | MockContract<MockERC20PresetMinterPauser>;
    let targetVault: ERC4626 | MockContract<ERC4626>;

    before(function () {
        Deployments.initialize({
            type: {
                provider: network.name === "localhost" ? ProviderTypes.Hardhat : ProviderTypes.Internal,
                network: DeploymentNetwork.Develop,
                config: "test",
            },
            options: DeploymentFlags.None,
        });
    });

    beforeEach(async function () {
        adminAccount = (await ethers.getSigners())[0];
        operatorAccount = (await ethers.getSigners())[1];
        unpriviledgedAccount = (await ethers.getSigners())[2];

        assetToken = await mockERC20("AssetToken");

        const RoundsOutputVaultFactory = await ethers.getContractFactory("RoundsOutputVault");
        roundsOutputVault = (await RoundsOutputVaultFactory.deploy()) as RoundsOutputVault;

        targetVault = await mockERC4626("TestVault", "TSTV", assetToken.address, "InvestmentVault");

        await roundsOutputVault.initialize(
            adminAccount.address,
            operatorAccount.address,
            targetVault.address,
            "SomeURI",
        );
    });

    it("ROV0001 - Default Value", async function () {
        expect(await roundsOutputVault.getCurrentRound()).to.equal(0);
        expect(await roundsOutputVault.exchangeAsset()).to.equal(assetToken.address);
        expect(await roundsOutputVault.getExchangeRate(0)).to.equal(0);
    });

    it("ROV0002 - Deposit Round 0", async function () {
        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);
        const currentRound = await roundsOutputVault.getCurrentRound();

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares);
    });

    it("ROV0003 - Next Round", async function () {
        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);
        const currentRound = await roundsOutputVault.getCurrentRound();
        const decimals = await assetToken.decimals();
        const exchangeRate = assets.mul(BigNumber.from(10).pow(decimals)).div(shares);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        // TODO: Need to return some balance here because the shares were not actually transferred
        await (targetVault as unknown as MockERC4626).mockSetBalanceOf(shares);

        const tx = roundsOutputVault.connect(operatorAccount).nextRound();
        await expect(tx)
            .to.emit(roundsOutputVault, "SharesRedeemed")
            .withArgs(currentRound, operatorAccount.address, shares, assets);

        await expect(tx).to.emit(roundsOutputVault, "NextRound").withArgs(currentRound.add(1), exchangeRate);

        expect(await roundsOutputVault.getCurrentRound()).to.equal(currentRound.add(1));
    });

    it("ROV0004 - Deposit Round 1", async function () {
        await roundsOutputVault.connect(operatorAccount).nextRound();

        const currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(1);

        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares);
    });

    it("ROV0005 - Deposit/Redeem Same Round", async function () {
        await roundsOutputVault.connect(operatorAccount).nextRound();
        await roundsOutputVault.connect(operatorAccount).nextRound();

        const currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(2);

        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares);

        await expect(
            roundsOutputVault
                .connect(unpriviledgedAccount)
                .redeemExchangeAsset(currentRound, shares, unpriviledgedAccount.address, unpriviledgedAccount.address),
        ).to.be.revertedWith("Exchange asset only available for previous rounds");

        await roundsOutputVault
            .connect(unpriviledgedAccount)
            .redeem(currentRound, shares, unpriviledgedAccount.address, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transfer).to.have.been.calledOnceWith(unpriviledgedAccount.address, shares);
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(0);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(0);
    });

    it("ROV0006 - Deposit/Redeem Batch Same Round", async function () {
        await roundsOutputVault.connect(operatorAccount).nextRound();
        await roundsOutputVault.connect(operatorAccount).nextRound();

        const currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(2);

        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares);

        await expect(
            roundsOutputVault
                .connect(unpriviledgedAccount)
                .redeemExchangeAsset(currentRound, shares, unpriviledgedAccount.address, unpriviledgedAccount.address),
        ).to.be.revertedWith("Exchange asset only available for previous rounds");

        await roundsOutputVault
            .connect(unpriviledgedAccount)
            .redeemBatch(
                [currentRound, currentRound],
                [shares.div(2), shares.div(2)],
                unpriviledgedAccount.address,
                unpriviledgedAccount.address,
            );

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transfer).to.have.been.calledOnceWith(unpriviledgedAccount.address, shares);
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(0);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(0);
    });

    it("ROV0007 - Deposit/Redeem Previous Round", async function () {
        await roundsOutputVault.connect(operatorAccount).nextRound();

        const currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(1);

        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares, unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares);

        // Advance round
        await roundsOutputVault.connect(operatorAccount).nextRound();

        // TODO: minting because the fake vault cannot transfer assets back
        await assetToken.mint(roundsOutputVault.address, assets);

        await expect(
            roundsOutputVault
                .connect(unpriviledgedAccount)
                .redeem(currentRound, shares, unpriviledgedAccount.address, unpriviledgedAccount.address),
        ).to.be.revertedWith("Can only redeem current round");

        await roundsOutputVault
            .connect(unpriviledgedAccount)
            .redeemExchangeAsset(currentRound, shares, unpriviledgedAccount.address, unpriviledgedAccount.address);

        expect(await assetToken.balanceOf(unpriviledgedAccount.address)).to.equal(assets);

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(0);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(0);
    });

    it("ROV0008 - Deposit/Redeem Batch Previous Rounds", async function () {
        await roundsOutputVault.connect(operatorAccount).nextRound();

        let currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(1);

        const assets = ethers.utils.parseEther("0.1");
        const shares = await targetVault.convertToShares(assets);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares.div(2), unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledOnceWith(
                unpriviledgedAccount.address,
                roundsOutputVault.address,
                shares.div(2),
            );
        });

        await roundsOutputVault.connect(operatorAccount).nextRound();

        // TODO: minting because the fake vault cannot transfer assets back
        await assetToken.mint(roundsOutputVault.address, assets.div(2));

        currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(2);

        await roundsOutputVault.connect(unpriviledgedAccount).deposit(shares.div(2), unpriviledgedAccount.address);

        ifMocksEnabled(() => {
            expect(asMock(targetVault).transferFrom).to.have.been.calledTwice;

            expectSolidityDeepCompare(
                [unpriviledgedAccount.address, roundsOutputVault.address, shares.div(2)],
                asMock(targetVault).transferFrom.getCall(1).args,
            );
        });

        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(shares);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound.sub(1))).to.equal(
            shares.div(2),
        );
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(shares.div(2));

        // Advance round
        await roundsOutputVault.connect(operatorAccount).nextRound();

        // TODO: minting because the fake vault cannot transfer assets back
        await assetToken.mint(roundsOutputVault.address, assets.div(2));

        currentRound = await roundsOutputVault.getCurrentRound();
        expect(currentRound).to.equal(3);

        await expect(
            roundsOutputVault
                .connect(unpriviledgedAccount)
                .redeem(currentRound.sub(2), shares.div(2), unpriviledgedAccount.address, unpriviledgedAccount.address),
        ).to.be.revertedWith("Can only redeem current round");

        await roundsOutputVault
            .connect(unpriviledgedAccount)
            .redeemExchangeAssetBatch(
                [currentRound.sub(2), currentRound.sub(1)],
                [shares.div(2), shares.div(2)],
                unpriviledgedAccount.address,
                unpriviledgedAccount.address,
            );

        expect(await assetToken.balanceOf(unpriviledgedAccount.address)).to.equal(assets);
        expect(await roundsOutputVault.balanceOfAll(unpriviledgedAccount.address)).to.equal(0);
        expect(await roundsOutputVault.balanceOf(unpriviledgedAccount.address, currentRound)).to.equal(0);
    });
});
