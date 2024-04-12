// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DistributionVault } from "../../src/DistributionVault.sol";

contract DistributionVaultHarness is DistributionVault {
    constructor(address zeroToken_) DistributionVault(zeroToken_) {}

    function setLastBalance(address token_, uint256 amount_) external {
        _lastTokenBalances[token_] = amount_;
    }
}
