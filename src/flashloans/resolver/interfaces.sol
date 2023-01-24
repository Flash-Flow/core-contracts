// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface FlashloanAggregatorInterface {
    function getRoutes() external pure returns (uint16[] memory);

    function calculateFeeBPS(uint256 _route)  external view returns (uint256 BPS_);

    function tokenToCToken(address) external view returns (address);
}

interface IAaveProtocolDataProvider {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            bool,
            bool,
            bool
        );

    function getReserveTokensAddresses(address asset)
        external
        view
        returns (
            address,
            address,
            address
        );
}
