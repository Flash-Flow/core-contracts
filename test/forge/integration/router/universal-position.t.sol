// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { PercentageMath } from 'contracts/lib/PercentageMath.sol';

import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { IBaseSwap } from 'contracts/interfaces/IBaseSwap.sol';
import { IConnector } from 'contracts/interfaces/IConnector.sol';
import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';

import { Deployer } from '../../utils/deployer.sol';
import { UniswapHelper } from '../../utils/uniswap.sol';
import { HelperContract } from '../../utils/helper.sol';

contract TestAaveV3Connector {
    uint256 public constant RATE_TYPE = 2;

    function _getDepositCallData(address _collateral) public view returns (bytes memory depositData) {
        depositData = abi.encodeWithSelector(aaveV3Connector.deposit.selector, _collateral);
    }

    function _getBorrowCallData(address _debt) public view returns (bytes memory borrowData) {
        borrowData = abi.encodeWithSelector(aaveV3Connector.borrow.selector, _debt, RATE_TYPE);
    }

    function _getPaybackCallData(
        address _debt,
        uint256 _borrowAmount
    ) public view returns (bytes memory paybackData, bytes memory withdrawData) {
        paybackData = abi.encodeWithSelector(aaveV3Connector.payback.selector, _debt, _borrowAmount, RATE_TYPE);
    }

    function _getWithdrawCallData(
        address _collateral,
        uint256 _collateralAmount
    ) public view returns (bytes memory paybackData, bytes memory withdrawData) {
        withdrawData = abi.encodeWithSelector(aaveV3Connector.withdraw.selector, _collateral, _collateralAmount);
    }
}

contract UniswapConnector is UniswapHelper {
    function _getSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory data) {
        bytes memory swapdata = getUniSwapCallData(_fromToken, _toToken, _recipient, _amount);
        data = abi.encodeWithSelector(IBaseSwap.swap.selector, _toToken, _fromToken, _amount, swapdata);
    }
}

contract UniversalPosition is UniswapConnector, HelperContract, Deployer {
    function openPosition(
        address _debt,
        address _collateral,
        uint256 _amountIn,
        uint256 _leverage,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector
    ) public {
        DataTypes.Position memory position = DataTypes.Position(
            msg.sender,
            _debt,
            _collateral,
            _amountIn,
            _leverage,
            0,
            0
        );
        approveTokenToRouter(_position.debt, _position.amountIn);

        (string memory targetName, bytes memory data) = _getOpenPositionCallData(
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            position
        );

        vm.prank(msg.sender);
        router.openPosition(_position, targetName, data);
    }

    function swapAndOpen(
        address _debt,
        address _collateral,
        uint256 _swapToken,
        uint256 _swapAmount,
        uint256 _leverage,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector
    ) public {
        bytes memory swapCallData = _getSwapCallData(_swapToken, _debt, address(router), _swapAmount);
        IRouter.SwapParams memory params = IRouter.SwapParams(
            _swapToken,
            _debt,
            _swapAmount,
            'UniswapAuto',
            swapCallData
        );

        approveTokenToRouter(_position.debt, _swapAmount);

        uint256 amountIn = quoteExactInput(_swapToken, _debt, _swapAmount, address(0));

        DataTypes.Position memory position = DataTypes.Position(
            msg.sender,
            _debt,
            _collateral,
            amountIn,
            _leverage,
            0,
            0
        );

        (string memory targetName, bytes memory data) = _getOpenPositionCallData(
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            position
        );

        vm.prank(msg.sender);
        router.swapAndOpen(position, targetName, data, params);
    }

    function closePosition(
        uint256 _indexPosition,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public {
        bytes32 key = router.getKey(_position.account, _indexPosition);
        (, , , , , uint256 collateralAmount, uint256 borrowAmount) = router.positions(key);

        (string memory targetName, bytes memory data) = _getClosePositionCallData(
            key,
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            _position
        );

        vm.prank(msg.sender);
        router.closePosition(key, _position.debt, borrowAmount, targetName, data);
    }

    function _getOpenPositionCallData(
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public view returns (string memory, bytes memory) {
        uint256 loanAmt = getLoanAmount(_position.amountIn, _position.leverage);

        string memory _targetName = getFlashloanData(_flashloanConnector, _position.debt, loanAmt);
        bytes memory _calldata = _getOpenPositionCallbackCallData(_swapConnector, _lendingConnector, _position);

        return (_targetName, _calldata);
    }

    function _getClosePositionCallData(
        bytes32 _key,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public view returns (string memory, bytes memory) {
        string memory targetName = getFlashloanData(_flashloanConnector, _position.debt, _borrowAmount);
        bytes memory _calldata = _getClosePositionCallbackCallData(_swapConnector, _lendingConnector, _position, _key);

        return (targetName, _calldata);
    }

    function _getOpenPositionCallbackCallData(
        address _swapConnector,
        address _lendingConnector,
        DataTypes.Position memory _position
    ) public view returns (bytes[] memory callData) {
        string[] memory targetNames = _getOpenConnectorNames(_swapConnector, _lendingConnector);
        bytes[] memory datas = _getOpenConnectorDatas(_position);
        bytes[] memory customDatas = _getOpenCustomCallData(_position.account);

        callData = abi.encode(accountImpl.openPositionCallback.selector, targetNames, datas, customDatas);
    }

    function _getClosePositionCallbackCallData(
        address _swapConnector,
        address _lendingConnector,
        DataTypes.Position memory _position,
        bytes32 _positionKey
    ) public view returns (bytes[] memory callData) {
        string[] memory targetNames = _getCloseConnectorNames(_swapConnector, _lendingConnector);
        bytes[] memory datas = _getCloseConnectorDatas(_position, _positionKey);
        bytes[] memory customDatas = _getCloseCustomCallData(_positionKey);

        callData = abi.encode(accountImpl.closePositionCallback.selector, targetNames, datas, customDatas);
    }

    function _getOpenCustomCallData(address _account) public view returns (bytes[] memory) {
        bytes[] memory _customDatas = new bytes[](1);
        _customDatas.push(abi.encode(_getPositionKey(_account)));

        return _customDatas;
    }

    function _getCloseCustomCallData(bytes32 _positionKey) public view returns (bytes[] memory) {
        bytes[] memory _customDatas = new bytes[](1);
        _customDatas.push(abi.encode(_positionKey));

        return _customDatas;
    }

    function _getOpenConnectorNames(
        address _swapConnector,
        address _lendingConnector
    ) public view returns (string[] memory names) {
        names = new string[](3);
        names[0] = IConnector(_swapConnector).NAME();
        names[1] = IConnector(_lendingConnector).NAME();
        names[2] = IConnector(_lendingConnector).NAME();
    }

    function _getCloseConnectorNames(
        address _swapConnector,
        address _lendingConnector
    ) public view returns (string[] memory names) {
        names = new string[](3);
        names[0] = IConnector(_lendingConnector).NAME();
        names[1] = IConnector(_lendingConnector).NAME();
        names[2] = IConnector(_swapConnector).NAME();
    }

    function _getOpenConnectorDatas(DataTypes.Position memory _position) public view returns (bytes[] memory datas) {
        (address recipient, uint256 amount) = _getRecipientAndAmount(_position);

        datas = new bytes[](3);
        datas[0] = _getSwapCallData(_position.debt, _position.collateral, recipient, amount);
        datas[1] = _getDepositCallData(_position.collateral);
        datas[2] = _getBorrowCallData(_position.debt);
    }

    function _getCloseConnectorDatas(
        DataTypes.Position memory _position,
        bytes32 _positionKey
    ) public view returns (bytes[] memory datas) {
        (address recipient, uint256 amount) = _getRecipientAndAmount(_position);
        (, , , , , uint256 collateralAmount, uint256 borrowAmount) = router.positions(_positionKey);

        datas = new bytes[](3);
        datas[0] = _getPaybackCallData(_position.debt, borrowAmount);
        datas[1] = _getWithdrawCallData(_position.collateral, collateralAmount);
        datas[2] = _getSwapCallData(_position.collateral, _position.debt, recipient, amount);
    }

    function _getUserAccountAddress(address _user) public view returns (address account) {
        account = router.accounts(_user);

        if (account == address(0)) {
            account = router.predictDeterministicAddress(_user);
        }
    }

    function _getPositionKey(address _user) public view returns (bytes32 key) {
        uint256 index = router.positionsIndex(_user);
        key = router.getKey(_user, index + 1);
    }

    function _getRecipientAndAmount(DataTypes.Position memory _position) public view returns (address, uint256) {
        address recipient = _getUserAccountAddress(_position.account);
        uint256 loanAmt = getLoanAmount(_position.amountIn, _position.leverage);

        uint256 swapAmount = loanAmt + _position.amountIn;
        uint256 fee = router.getFeeAmount(swapAmount);
        uint256 swapAmountWithoutFee = swapAmount - fee;

        return (recipient, swapAmountWithoutFee);
    }

    function approveTokenToRouter(address _token, uint256 _amount) public {
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_token).approve(address(router), _amount);
    }

    function getLoanAmount(uint256 _amount, uint256 _leverage) public view returns (uint256 amount) {
        // leverage - 1 = position size without user amount
        amount = (_amount * (_leverage - PercentageMath.PERCENTAGE_FACTOR)) / PercentageMath.PERCENTAGE_FACTOR;
    }

    function getFlashloanData(
        address _connector,
        address lT,
        uint256 lA
    ) public view returns (string memory targetName) {
        if (IBaseFlashloan(_connector).getAvailability(lT, lA)) {
            targetName = IBaseFlashloan(_connector).NAME();
        }
    }
}
