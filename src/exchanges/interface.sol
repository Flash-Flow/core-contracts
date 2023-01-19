// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../connectors/common/interfaces.sol";

interface OneInchInterace {
    function swap(
        TokenInterface fromToken,
        TokenInterface toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        uint256 guaranteedAmount,
        address payable referrer,
        address[] calldata callAddresses,
        bytes calldata callDataConcat,
        uint256[] calldata starts,
        uint256[] calldata gasLimitsAndValues
    )
    external
    payable
    returns (uint256 returnAmount);
}

struct OneInchData {
    TokenInterface sellToken;
    TokenInterface buyToken;
    uint _sellAmt;
    uint _buyAmt;
    uint unitAmt;
    bytes callData;
}

struct SwapData {
	TokenInterface sellToken;
	TokenInterface buyToken;
	uint256 _sellAmt;
	uint256 _buyAmt;
	uint256 unitAmt;
	bytes callData;
}