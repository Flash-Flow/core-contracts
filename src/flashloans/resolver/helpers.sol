// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Variables } from "./variables.sol";

contract Helper is Variables {
    function getAaveAvailability(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal view returns (bool) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            (, , , , , , , , bool isActive, ) = aaveProtocolDataProvider.getReserveConfigurationData(_tokens[i]);
            (address aTokenAddr, , ) = aaveProtocolDataProvider.getReserveTokensAddresses(_tokens[i]);
            if (isActive == false) {
                return false;
            }
            if (token_.balanceOf(aTokenAddr) < _amounts[i]) {
                return false;
            }
        }
        return true;
    }

    function getMakerAvailability(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal view returns (bool) {
        if (_tokens.length == 1 && _tokens[0] == daiToken) {
            uint256 loanAmt = makerLending.maxFlashLoan(daiToken);
            return _amounts[0] <= loanAmt;
        }
        return false;
    }

    function getBalancerAvailability(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal view returns (bool) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            if (token_.balanceOf(balancerLendingAddr) < _amounts[i]) {
                return false;
            }
        }
        return true;
    }

    function getRoutesWithAvailability(
        uint16[] memory _routes,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal view returns (uint16[] memory) {
        uint16[] memory routesWithAvailability_ = new uint16[](3);
        uint256 j = 0;
        for (uint256 i = 0; i < _routes.length; i++) {
            if (_routes[i] == 1) {
                if (getAaveAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else if (_routes[i] == 2) {
                if (getMakerAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else if (_routes[i] == 3) {
                if (getBalancerAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else {
                require(false, "invalid-route");
            }
        }
        return routesWithAvailability_;
    }

    function validateTokens(address[] memory _tokens) internal pure {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            require(_tokens[i] != _tokens[i + 1], "non-unique-tokens");
        }
    }
}
