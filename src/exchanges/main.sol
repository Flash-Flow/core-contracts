// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { TokenInterface } from "../connectors/common/interfaces.sol";
import "../lib/UniversalERC20.sol";

import { Helpers } from "./helpers.sol";
import { SwapData, OneInchData } from "./interface.sol";

contract Exchanges is Helpers {
    using UniversalERC20 for IERC20;

    event LogExchange(
        address indexed account,
        uint256 indexed route,
        address buyAddr,
		address sellAddr,
		uint256 sellAmt
    );

    function exchange(
        address buyAddr,
		address sellAddr,
		uint256 sellAmt,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt) {
        if (_route == 1) {
            _buyAmt = routeUni(buyAddr, sellAddr, sellAmt, callData);
        } else if (_route == 2) {
            _buyAmt = routeOneInch(buyAddr, sellAddr, sellAmt, callData);
        } else {
            revert("route-does-not-exist");
        }

        IERC20(buyAddr).universalTransfer(msg.sender, _buyAmt);

        emit LogExchange(msg.sender, _route, buyAddr, sellAddr, sellAmt);
    }

    function routeUni(
        address buyAddr,
        address sellAddr,
        uint sellAmt,
        bytes calldata callData
    ) internal returns (uint256 _buyAmt) {
        SwapData memory swapData = SwapData({
			buyToken: TokenInterface(buyAddr),
			sellToken: TokenInterface(sellAddr),
			callData: callData,
			_sellAmt: sellAmt,
			_buyAmt: 0
		});

        _buyAmt = uniSwap(swapData);
    }

    function routeOneInch(
        address buyAddr,
        address sellAddr,
        uint sellAmt,
        bytes calldata callData
    ) internal returns (uint256) {
        OneInchData memory oneInchData = OneInchData({
            buyToken: TokenInterface(buyAddr),
            sellToken: TokenInterface(sellAddr),
            callData: callData,
            _sellAmt: sellAmt,
            _buyAmt: 0
        });

        return oneInchSwap(oneInchData);
    }

    receive() external payable {}
}