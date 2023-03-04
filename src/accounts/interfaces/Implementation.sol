// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SharedStructs } from "../../lib/SharedStructs.sol";

interface IPositionRouter {
    function openPosition(
        SharedStructs.Position memory position,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function decodeAndExecute(bytes memory _data) external returns (bytes memory response);
}