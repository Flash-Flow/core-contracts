// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/positions/Router.sol";
import "../src/positions/interfaces.sol";

import "../src/connectors/protocols/aave/v2/main.sol";

import "../src/exchanges/main.sol";
import "../src/flashloans/resolver/main.sol";
import "../src/flashloans/aggregator/main.sol";

import { UniswapHelper } from "./uniswap-helper.t.sol";

contract HelperContract is UniswapHelper, Test {

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

contract PositionAave is LendingHelper {

    Exchanges exchanges;
    PositionRouter router;
    FlashResolver flashResolver;

    PositionRouter.Position position;

    constructor() {
        setUp();
    }

    function setUp() public {
        exchanges = new Exchanges();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        uint256 fee = 3;
        address treasury = msg.sender;

        router = new PositionRouter(
            address(flashloanAggregator),
            address(exchanges),
            fee, 
            treasury,
            address(0),
            address(aaveResolver),
            address(0)
        );
    }

    function testOpenAndClosePosition() public {
        position = PositionRouter.Position(
            msg.sender,
            address(daiC),
            ethC,
            1000 ether,
            2
        );

        topUpTokenBalance(daiC, daiWhale, position.amountIn);
        
        // approve tokens
        vm.prank(msg.sender);
        ERC20(position.debt).approve(address(router), position.amountIn);
        
        openPosition();
        // closePosition();
    }

    function openPosition() public {
        uint256 loanAmt = position.amountIn * (position.sizeDelta - 1);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 route
        ) = getFlashloanData(position.debt, loanAmt);

        uint256 swapAmount = position.amountIn * position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getOpenCallbackData(
            position.debt,
            position.collateral,
            swapAmountWithoutFee
        );

        vm.prank(msg.sender);
        router.openPosition(position, false, _tokens, _amts, route, _calldata, bytes(""));
    }

      function closePosition() public {
        uint256 index = router.positionsIndex(msg.sender);
        bytes32 key = router.getKey(msg.sender, index);

        uint256 collateralAmount = getCollateralAmt(position.collateral, address(router));
        uint256 borrowAmount = getBorrowAmt(position.debt, address(router));

        uint256 borrowBumpAmt = borrowAmount * 1005 / 1000;

        (
            address[] memory __tokens,
            uint256[] memory __amts,
            uint16 _route
        ) = getFlashloanData(position.debt, borrowBumpAmt);

        bytes memory __calldata = getCloseCallbackData(
            position.debt,
            position.collateral,
            collateralAmount,
            borrowBumpAmt,
            key
        );

        vm.prank(msg.sender);
        router.closePosition(key, __tokens, __amts, _route, __calldata, bytes(""));
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
        _datas[0] = abi.encode(debt, borrowAmt, 1, abi.encode(1));
        _datas[1] = abi.encode(collateral, swapAmt, 1);

        bytes memory _uniData = getMulticalSwapData(collateral, debt, address(exchanges), swapAmt);
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
        uint256 swapAmount
    ) public view returns(bytes memory _calldata) {
        bytes memory _uniData = getMulticalSwapData(debt, collateral, address(exchanges), swapAmount);
        bytes[] memory _customDatas = new bytes[](1);

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