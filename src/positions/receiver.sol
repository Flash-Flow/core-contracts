// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces.sol";

contract FlashReceiver is Ownable {
    using SafeERC20 for IERC20;

    IFlashLoan internal immutable flashloanAggregator;

    modifier onlyAggregator() {
        require(msg.sender == address(flashloanAggregator), "Access denied");
        _;
    }

    function flashloan(
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) public {
        flashloanAggregator.flashLoan(_tokens, _amts, route, _data, _customData);
    }

    // Function which
    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata params
    ) external onlyAggregator returns (bool) {
        bytes memory encodeParams = encodingParams(params, amounts[0] + premiums[0]);
        (bool success, bytes memory results) = address(this).call(encodeParams);
        if (!success) {
            revert(_getRevertMsg(results));
        }

        return true;
    }

    function encodingParams(bytes memory params, uint256 amount) internal pure returns (bytes memory encode) {
        (
            bytes4 selector,
            address[] memory _targets,
            bytes[] memory _datas,
            bytes[] memory _customDatas,
            address _origin
        ) = abi.decode(params, (bytes4, address[], bytes[], bytes[], address));

        encode = abi.encodeWithSelector(selector, _targets, _datas, _customDatas, _origin, amount);
    }

    constructor(address flashloanAggregator_) {
        flashloanAggregator = IFlashLoan(flashloanAggregator_);
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) {
            return "Transaction reverted silently";
        }

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}