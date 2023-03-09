// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { EthConverter } from "../src/utils/EthConverter.sol";

contract TestEthConverter is Test, EthConverter {
  address ethC = 0x0000000000000000000000000000000000000000;
  address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address wrongToken = 0x0000000000000000000000000000000000000002;

  uint256 public amount = 1 ether;

  receive() external payable {}

  function setUp() public {
    string memory url = vm.rpcUrl("mainnet");
    uint256 forkId = vm.createFork(url);
    vm.selectFork(forkId);
  }

  function testConvertEthToWeth() public {
    convertEthToWeth(ethC, amount);
    
    assertEq(amount, IERC20(wethC).balanceOf(address(this)));
  }

  function testConvertWethToEth() public {
    convertEthToWeth(ethC, amount);

    uint256 initialBalance = address(this).balance;
    convertWethToEth(wethC, amount);
    uint256 finalBalance = address(this).balance;
    
    assertEq(amount, finalBalance - initialBalance);
  }

  function testWrongTokenEthToWeth() public {
    convertEthToWeth(wrongToken, amount);
    
    assertGt(amount, IERC20(wethC).balanceOf(address(this)));
  }

  function testWrongTokenWethToEth() public {
    convertEthToWeth(ethC, amount);
    convertWethToEth(wrongToken, amount);
    
    assertEq(amount, IERC20(wethC).balanceOf(address(this)));
  }
}