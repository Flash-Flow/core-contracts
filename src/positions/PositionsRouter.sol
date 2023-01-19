// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces.sol";

contract PositionsRouter {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
    }

    IExecutor private immutable executor;
    IExchanges private immutable exchanges;
    IFlashloanReciever private immutable flashloanReciever;

    mapping (bytes32 => Position) public positions;
    mapping (address => uint256) public positionsIndex;

    modifier onlyCallback() {
        require(msg.sender == address(this), "Access denied");
        _;
    }

    constructor(IExecutor _executor,IFlashloanReciever _flashloanReciever,IExchanges _exchanges) {
        executor = _executor;
        flashloanReciever = _flashloanReciever;
        exchanges = _exchanges;
    }

    function openPosition(
        Position memory position,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        require(position.account == msg.sender, "Only owner");

        flashloanReciever.flashloan(_tokens, _amts, route, _data, _customData);

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;
        positionsIndex[account] = index;

        bytes32 key = getKey(position.account, index);

        positions[key] = position;
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        Position memory position = positions[key];

        require(msg.sender == position.account, "Can close own position or position available for liquidation");

        flashloanReciever.flashloan(_tokens, _amts, route, _data, _customData);

        delete positions[key];
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function openPositionCallback(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin,
        uint256 /* repayAmount */
    ) external payable onlyCallback {
        exchange(_datas[0]);
        executor.execute(_targetNames, _datas, _origin);
    }

    function closePositionCallback(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin,
        uint256 /* repayAmount */
    ) external payable onlyCallback {
        exchange(_datas[0]);
        executor.execute(_targetNames, _datas, _origin);
    }

    function exchange(bytes calldata _exchangeData) internal returns (uint256 value) {
        (
            address buyAddr,
            address sellAddr,
            uint256 sellAmt,
            uint256 unitAmt,
            uint256 _route,
            bytes memory callData
        ) = abi.decode(_exchangeData, (address, address, uint256, uint256, uint256, bytes));

        value = exchanges.exchange(buyAddr, sellAddr, sellAmt, unitAmt, _route, callData);
    }
}