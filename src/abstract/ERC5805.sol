// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { StatefulERC712 } from "../../lib/common/src/StatefulERC712.sol";

import { IERC5805 } from "./interfaces/IERC5805.sol";

// TODO: Consider changing `address owner/account` and `uint256 expiry/deadline`, and thus the typehash literals.

abstract contract ERC5805 is IERC5805, StatefulERC712 {
    // DELEGATION_TYPEHASH =
    //     keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    bytes32 public constant DELEGATION_TYPEHASH = 0xe48329057bfd03d55e49b547132e39cffd9c1820ad7b9d4c5307691425d15adf;

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function delegate(address delegatee_) external {
        _delegate(msg.sender, delegatee_);
    }

    function delegateBySig(
        address delegatee_,
        uint256 nonce_,
        uint256 expiry_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        _delegateBySig(
            _getSignerAndRevertIfInvalidSignature(_getDelegationDigest(delegatee_, nonce_, expiry_), v_, r_, s_),
            delegatee_,
            nonce_,
            expiry_
        );
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _delegate(address delegator_, address newDelegatee_) internal virtual;

    function _delegateBySig(address account_, address delegatee_, uint256 nonce_, uint256 expiry_) internal {
        _revertIfExpired(expiry_);

        uint256 currentNonce_ = _nonces[account_];

        // Nonce must equal the current unused nonce, before it is incremented.
        if (nonce_ == currentNonce_) revert ReusedNonce(nonce_, currentNonce_);

        unchecked {
            _nonces[account_] = currentNonce_ + 1; // Nonce realistically cannot overflow.
        }

        _delegate(account_, delegatee_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getDelegationDigest(
        address delegatee_,
        uint256 nonce_,
        uint256 expiry_
    ) internal view returns (bytes32 digest_) {
        return _getDigest(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee_, nonce_, expiry_)));
    }
}
