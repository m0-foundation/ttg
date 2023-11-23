// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { PowerToken } from "../../src/PowerToken.sol";

contract PowerTokenHarness is PowerToken {
    constructor(
        address governor_,
        address cashToken_,
        address vault_,
        address bootstrapToken_
    ) PowerToken(governor_, cashToken_, vault_, bootstrapToken_) {}

    function setNextCashTokenStartingEpoch(uint256 nextCashTokenStartingEpoch_) external {
        _nextCashTokenStartingEpoch = nextCashTokenStartingEpoch_;
    }

    function setInternalCashToken(address cashToken_) external {
        _cashToken = cashToken_;
    }

    function setInternalNextCashToken(address nextCashToken_) external {
        _nextCashToken = nextCashToken_;
    }

    function nextCashTokenStartingEpoch() external view returns (uint256 epoch_) {
        return _nextCashTokenStartingEpoch;
    }

    function internalCashToken() external view returns (address cashToken_) {
        return _cashToken;
    }

    function internalNextCashToken() external view returns (address nextCashToken_) {
        return _nextCashToken;
    }
}
