// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC5805 } from "./interfaces/IERC5805.sol";
import { IERC6372 } from "./interfaces/IERC6372.sol";

import { ERC712 } from "./ERC712.sol";

// TODO: Consider changing `address owner/account` and `uint256 expiry/deadline`, and thus the typehash literals.

abstract contract ERC5805 is IERC5805, ERC712 {
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
        bytes32 digest_ = _getDelegationDigest(delegatee_, nonce_, expiry_);
        address signer_ = _getSigner(digest_, expiry_, v_, r_, s_);
        uint256 currentNonce_ = _nonces[signer_];

        // Nonce must equal the current unused nonce, before it is incremented.
        if (nonce_ == currentNonce_) revert ReusedNonce(nonce_, currentNonce_);

        // Nonce realistically cannot overflow.
        unchecked {
            _nonces[signer_] = currentNonce_ + 1;
        }

        _delegate(signer_, delegatee_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _delegate(address delegator_, address newDelegatee_) internal virtual;

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
