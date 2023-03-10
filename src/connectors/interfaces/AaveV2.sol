// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IAave {
    function deposit(address _asset, uint256 _amount, address _onBehalfOf, uint16 _referralCode) external;

    function withdraw(address _asset, uint256 _amount, address _to) external;

    function borrow(
        address _asset,
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _onBehalfOf
    ) external;

    function repay(address _asset, uint256 _amount, uint256 _rateMode, address _onBehalfOf) external;

    function setUserUseReserveAsCollateral(address _asset, bool _useAsCollateral) external;

    function swapBorrowRateMode(address _asset, uint256 _rateMode) external;
}

interface IAaveLendingPoolProvider {
    function getLendingPool() external view returns (address);
}

interface IAaveDataProvider {
    function getReserveTokensAddresses(
        address _asset
    ) external view returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);

    function getUserReserveData(
        address _asset,
        address _user
    )
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );
}
