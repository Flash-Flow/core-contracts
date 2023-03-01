// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/positions/router.sol";
import "../src/positions/interfaces.sol";

import "../src/connectors/protocols/aave/v2/main.sol";

import "../src/exchanges/main.sol";
import "../src/flashloans/resolver/main.sol";
import "../src/flashloans/aggregator/main.sol";

import { AccountProxy } from "../src/positions/accountProxy.sol";
import { Implementation } from "../src/positions/implementation.sol";
import { Implementations } from "../src/positions/implementations.sol";

import { Regestry } from "../src/positions/regestry.sol";
import { FlashReceiver } from "../src/positions/receiver.sol";

import { UniswapHelper } from "./uniswap-helper.t.sol";

contract HelperContract is UniswapHelper, Test {

    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}

contract LendingHelper is HelperContract {
    AaveResolver aaveResolver;

    uint256 RATE_TYPE = 1;

    constructor() {
        aaveResolver = new AaveResolver();
    }

    function getCollateralAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveResolver.getCollateralBalance(
            _token == ethC ? wethC : _token, _recipient
        );        
    }

    function getBorrowAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveResolver.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }
}

contract PositionAccount is LendingHelper {

    Exchanges exchanges;
    FlashResolver flashResolver;

    Regestry regestry;
    PositionRouter router;

    AccountProxy accountProxy;
    Implementation implementation;
    Implementations implementations;

    constructor() {
        exchanges = new Exchanges();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        router = new PositionRouter(
            address(flashloanAggregator),
            address(exchanges),
            3,
            msg.sender,
            address(0),
            address(aaveResolver),
            address(0)
        );
        console.log("router", address(router));

        implementation = new Implementation();
        implementations = new Implementations();

        implementations.setDefaultImplementation(address(implementation));

        accountProxy = new AccountProxy(address(implementations));
        regestry = new Regestry(address(accountProxy), address(router));
    }

    function testAccountLongPosition() public {

        vm.prank(msg.sender);
        address account = regestry.createAccount(msg.sender);

        SharedStructs.Position memory _position = SharedStructs.Position(
            account,
            address(daiC),
            ethC,
            1000 ether,
            2,
            0,
            0
        );

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);
        
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_position.debt).approve(account, _position.amountIn);
        
        openPosition(_position);
    
        uint256 index = router.positionsIndex(_position.account);
        console.log("index", index);
        bytes32 key = router.getKey(_position.account, index);
        console.logBytes32(key);

        (,,,,,uint256 collateralAmount, uint256 borrowAmount) = router.positions(key);
        console.log("collateralAmount", collateralAmount);
        console.log("borrowAmount", borrowAmount);

        closePosition(_position, index, collateralAmount, borrowAmount);
    }

    function openPosition(SharedStructs.Position memory _position) public {
        uint256 loanAmt = _position.amountIn * (_position.sizeDelta - 1);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 route
        ) = getFlashloanData(_position.debt, loanAmt);

        uint256 swapAmount = _position.amountIn * _position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getOpenCallbackData(
            _position.debt,
            _position.collateral,
            swapAmountWithoutFee,
            _position.account
        );

        bytes memory _open = abi.encodeWithSelector(
            implementation.openPosition.selector, _position, false, _tokens, _amts, route, _calldata, bytes("")
        );

        vm.prank(msg.sender);
        (bool success, bytes memory resp) = _position.account.call(_open);
        console.log("success", success);
    }

    function closePosition(
        SharedStructs.Position memory _position,
        uint256 _index,
        uint256 _collateralAmount,
        uint256 _borrowAmount
    ) public {
        bytes32 key = router.getKey(_position.account, _index);
        console.logBytes32(key);
        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 _route
        ) = getFlashloanData(_position.debt, _borrowAmount);

        bytes memory _calldata = getCloseCallbackData(
            _position.debt,
            _position.collateral,
            _collateralAmount,
            _borrowAmount,
            key
        );

        bytes memory _close = abi.encodeWithSelector(
            implementation.closePosition.selector, key, _tokens, _amts, _route, _calldata, bytes("")
        );

        vm.prank(msg.sender);
        (bool success, bytes memory resp) = _position.account.call(_close);
        console.log("success", success);
    }

    function getFlashloanData(
        address lT,
        uint256 lA
    ) public view returns(address[] memory, uint256[] memory, uint16) {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (,,uint16[] memory _bestRoutes,) = flashResolver.getData(_tokens, _amts);

        return (_tokens, _amts, _bestRoutes[0]);
    }

    function getCloseCallbackData(
        address debt,
        address collateral,
        uint256 swapAmt,
        uint256 borrowAmt,
        bytes32 key
    ) public view returns(bytes memory _calldata) {

        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encodePacked(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = abi.encode(borrowAmt, debt, 1, abi.encode(1));
        _datas[1] = abi.encode(swapAmt, collateral, 1, bytes(""));

        bytes memory _uniData = getMulticalSwapData(collateral, debt, address(router), swapAmt);
        _datas[2] = abi.encode(debt, collateral, swapAmt, 1, _uniData);

        _calldata = abi.encode(
            router.closePositionCallback.selector,
            _datas,
            _customDatas
        );
    }

    function getOpenCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount,
        address account
    ) public view returns(bytes memory _calldata) {
        bytes memory _uniData = getMulticalSwapData(debt, collateral, address(router), swapAmount);
        bytes[] memory _customDatas = new bytes[](1);

        uint256 index = router.positionsIndex(address(account));
        bytes32 key = router.getKey(address(account), index + 1);

        _customDatas[0] = abi.encode(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = abi.encode(collateral, debt, swapAmount, 1, _uniData);
        // deposit(dynamic amt,token,route)
        _datas[1] = abi.encode(collateral, 1, bytes(""));
        // borrow(dynamic amt,token,route,mode)
        _datas[2] = abi.encode(debt, 1, abi.encode(1));

        _calldata = abi.encode(
            router.openPositionCallback.selector,
            _datas,
            _customDatas
        );
    }
}