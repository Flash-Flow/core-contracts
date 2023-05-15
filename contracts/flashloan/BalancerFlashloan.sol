// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IBalancerFlashloan } from '../interfaces/IBalancerFlashloan.sol';

import { IVault } from '../interfaces/external/balancer/IVault.sol';
import { IFlashLoanRecipient } from '../interfaces/external/balancer/IFlashLoanRecipient.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

import 'forge-std/Test.sol';

contract BalancerFlashloan is IBalancerFlashloan, BaseFlashloan, Test {
    /* ============ Constants ============ */

    /**
     * @dev Balancer Lending
     */
    IVault internal constant balancerLending = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    string public constant override name = 'BalancerFlashloan';

    /**
     * @dev Fallback function for balancer flashloan.
     * _amounts list of amounts for the corresponding assets or amount of ether to borrow as collateral for flashloan.
     * _fees list of fees for the corresponding addresses for flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function receiveFlashLoan(
        address[] memory,
        uint256[] memory,
        uint256[] memory _fees,
        bytes memory _data
    ) external override verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), 'not balancer sender');

        (address asset, uint256 amount, address sender, bytes memory data) = abi.decode(
            _data,
            (address, uint256, address, bytes)
        );

        uint256 fee = _fees[0];
        uint256 initialBalance = getBalance(asset);

        safeTransfer(asset, amount, sender);
        IFlashReceiver(sender).executeOperation(asset, amount, fee, sender, name, data);

        require(initialBalance + fee <= getBalance(asset), 'amount paid less');

        safeTransfer(asset, amount + fee, address(balancerLending));
    }

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @param _token token addresses for flashloan.
     * @param _amount list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function flashLoan(address _token, uint256 _amount, bytes calldata _data) external override reentrancy {
        _flashLoan(_token, _amount, _data);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Returns fee for the passed route in BPS.
     * @notice Returns fee for the passed route in BPS. 1 BPS == 0.01%.
     */
    function calculateFeeBPS() public view override returns (uint256 bps) {
        bps = (balancerLending.getProtocolFeesCollector().getFlashLoanFeePercentage()) * 100;
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Middle function for route 3.
     * @param _token token addresses for flashloan.
     * @param _amount list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function _flashLoan(address _token, uint256 _amount, bytes memory _data) internal {
        bytes memory data = abi.encode(_token, _amount, msg.sender, _data);
        _dataHash = bytes32(keccak256(data));

        address[] memory tokens = new address[](1);
        tokens[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        balancerLending.flashLoan(IFlashLoanRecipient(address(this)), tokens, amounts, data);
    }

    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {
        if (IERC20(_token).balanceOf(address(balancerLending)) < _amount) {
            return false;
        }
        return true;
    }
}
