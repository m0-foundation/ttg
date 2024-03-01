// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ERC5805, StatefulERC712 } from "../../src/abstract/ERC5805.sol";

contract ERC5805Harness is ERC5805 {
    constructor(string memory name_) ERC5805() StatefulERC712(name_) {}

    function getDelegationDigest(address delegatee_, uint256 nonce_, uint256 expiry_) external view returns (bytes32) {
        return _getDelegationDigest(delegatee_, nonce_, expiry_);
    }

    function CLOCK_MODE() external pure returns (string memory) {
        return "mode=epoch";
    }

    function clock() public pure returns (uint48) {
        return uint48(0);
    }

    function delegates(address account) external view returns (address) {}

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {}

    function getVotes(address account) external view returns (uint256) {}

    function _delegate(address delegator_, address newDelegatee_) internal virtual override {}
}
