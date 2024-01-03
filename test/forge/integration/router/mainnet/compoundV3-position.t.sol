// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'src/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'src/lib/DataTypes.sol';
import { IRouter } from 'src/interfaces/IRouter.sol';
import { UniversalERC20 } from 'src/lib/UniversalERC20.sol';

import { UniversalPosition } from '../universal-position.sol';
import { DeployMainnetContracts } from '../../../utils/deployer/mainnet/mainnet.sol';

contract PositionCompoundV3Mainnet is UniversalPosition, DeployMainnetContracts {
    address public user = makeAddr('user');

    uint256 public leverage = 21000; // 2.1x

    function test_OpenPosition_ClosePosition() public {
        (DataTypes.Position memory position, uint256 index) = openPosition(
            user,
            getToken('usdc'),
            getToken('weth'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan)
        );

        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan),
            position
        );
    }

    function test_OpenAndClose_TwoPosition() public {
        (DataTypes.Position memory position1, uint256 index1) = openPosition(
            user,
            getToken('usdc'),
            getToken('weth'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan)
        );

        (DataTypes.Position memory position2, uint256 index2) = openPosition(
            user,
            getToken('usdc'),
            getToken('weth'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan)
        );

        closePosition(
            user,
            index1,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan),
            position1
        );
        closePosition(
            user,
            index2,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan),
            position2
        );
    }

    function test_SwapAndOpen_ClosePosition() public {
        vm.prank(user);
        (DataTypes.Position memory position, uint256 index) = swapAndOpen(
            user,
            getToken('usdc'),
            getToken('weth'),
            getToken('dai'),
            2000 ether,
            leverage,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan)
        );

        vm.prank(user);
        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(compoundV3Connector),
            address(balancerFlashloan),
            position
        );
    }

    // compound v3 connector integration

    address public USDC_MARKET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

    function _getDepositCallData(address _collateral) public view override returns (bytes memory) {
        return abi.encodeWithSelector(compoundV3Connector.deposit.selector, USDC_MARKET, _collateral);
    }

    function _getBorrowCallData(address _debt) public view override returns (bytes memory) {
        return abi.encodeWithSelector(compoundV3Connector.borrow.selector, USDC_MARKET, _debt);
    }

    function _getPaybackCallData(address _debt, uint256 _borrowAmount) public view override returns (bytes memory) {
        return abi.encodeWithSelector(compoundV3Connector.payback.selector, USDC_MARKET, _debt, _borrowAmount);
    }

    function _getWithdrawCallData(
        address _collateral,
        uint256 _collateralAmount
    ) public view override returns (bytes memory) {
        return
            abi.encodeWithSelector(compoundV3Connector.withdraw.selector, USDC_MARKET, _collateral, _collateralAmount);
    }

    // override
    function getSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view override returns (bytes memory data) {
        return _getSwapCallData(_fromToken, _toToken, _recipient, _amount);
    }

    function getQuoteExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _hopToken
    ) public override returns (uint256 amountOut) {
        return quoteExactInput(_tokenIn, _tokenOut, _amountIn, _hopToken);
    }
}
