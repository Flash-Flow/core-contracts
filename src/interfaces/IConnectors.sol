// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IConnectors {
    function addConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function removeConnectors(string[] calldata _names) external;

    function isConnectors(string[] calldata _names) external view returns (bool isOk, address[] memory _connectors);

    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}
