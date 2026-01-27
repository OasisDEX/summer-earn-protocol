// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGainAdapter {
    // errors
    error AssetAlreadyWhitelisted();
    error AssetOracleNotSupported();
    error EthReservedIsZero();
    error EthReservedLimitReached();
    error InsufficientAssetBalance();
    error InsufficientETHBalance();
    error InsufficientRsETHBalance();
    error InvalidAmount();
    error InvalidAssetValueInETH();
    error InvalidMsgValue();
    error InvalidMinRSETHAmountExpected();
    error InvalidPriceOracle();
    error NotEnoughETHReserved();
    error OnlyWhitelistedAsset();
    error OnlyWhitelistedVault();
    error UnsupportedAssetForOracle();
    error UnsupportedAssetForSwap();
    error VaultAlreadyWhitelisted();

    // events
    event AdapterETHDeposit(
        address indexed depositor,
        uint256 amount,
        address indexed vault,
        string referralId
    );
    event AdapterAssetDeposit(
        address indexed asset,
        address indexed depositor,
        uint256 amount,
        uint256 assetValueInETH,
        address indexed vault,
        string referralId
    );
    event AdapterWithdrawal(
        address indexed withdrawer,
        address indexed vault,
        uint256 amount,
        string referralId
    );
    event RsETHSentToVault(address indexed vault, uint256 amount);
    event OperatorAssetSwapped(
        address indexed asset,
        uint256 amount,
        uint256 assetValueInETH
    );
    event WhitelistedAssetAdded(address indexed asset);
    event WhitelistedAssetRemoved(address indexed asset);
    event WhitelistedVaultAdded(address indexed vault);
    event WhitelistedVaultRemoved(address indexed vault);
    event SupportedOracleUpdated(address indexed asset, address indexed oracle);
    event SupportedOracleRemoved(address indexed asset);
    event EthReservedLimitUpdated(address indexed vault, uint256 newLimit);

    // functions
    function depositETH(
        address vault,
        string calldata referralId
    ) external payable;
    function depositETHAsset(
        address asset,
        uint256 amount,
        address vault,
        string calldata referralId
    ) external;
    function withdraw(
        address vault,
        uint256 amount,
        string calldata referralId
    ) external;
    function sendRsETHToVault(address vault, uint256 amount) external;
    function mintRsETH(address asset, uint256 depositAmount) external payable;
    function swapAssetForETH(address asset, uint256 amount) external payable;
    function addWhitelistedAsset(address asset) external;
    function removeWhitelistedAsset(address asset) external;
    function addWhitelistedVault(address vault) external;
    function removeWhitelistedVault(address vault) external;
    function updateSupportedPriceOracle(
        address asset,
        address priceOracle
    ) external;
    function removeSupportedPriceOracle(address asset) external;
    function updateEthReservedLimit(address vault, uint256 newLimit) external;
    function getAssetPrice(address asset) external view returns (uint256);
    function getRsETHPrice() external view returns (uint256);
    function getAssetValueInETH(
        address asset,
        uint256 amount
    ) external view returns (uint256);
    function getETHValueFromRsETHAmount(
        uint256 amount
    ) external view returns (uint256);
    function getRsETHValueFromETHAmount(
        uint256 amount
    ) external view returns (uint256);
    function getIsWhitelistedAsset(address asset) external view returns (bool);
    function getIsWhitelistedVault(address vault) external view returns (bool);
    function getAssetPriceOracle(address asset) external view returns (address);
    function getEthReservedAmount(
        address vault
    ) external view returns (uint256);
    function getEthReservedLimit(address vault) external view returns (uint256);
}
