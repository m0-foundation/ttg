// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { StatefulERC712 } from "../../lib/common/src/StatefulERC712.sol";

import { IERC5805 } from "./interfaces/IERC5805.sol";

abstract contract ERC5805 is IERC5805, StatefulERC712 {
    // NOTE: Keeping this constant, despite `delegateBySig` parameter name differences, to ensure max EIP-5805 compatibility.
    // keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)")
    bytes32 public constant DELEGATION_TYPEHASH = 0xe48329057bfd03d55e49b547132e39cffd9c1820ad7b9d4c5307691425d15adf;

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IERC5805
    function delegate(address delegatee_) external {
        _delegate(msg.sender, delegatee_);
    }

    /// @inheritdoc IERC5805
    function delegateBySig(
        address delegatee_,
        uint256 nonce_,
        uint256 expiry_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        bytes32 digest_ = _getDelegationDigest(delegatee_, nonce_, expiry_);
        address signer_ = _getSignerAndRevertIfInvalidSignature(digest_, v_, r_, s_);

        _revertIfExpired(expiry_);
        _checkAndIncrementNonce(signer_, nonce_);
        _delegate(signer_, delegatee_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @dev   Reverts if a given nonce is reused for `account`, then increments the nonce in storage.
     * @param account The address of the account the nonce is being verifier for.
     * @param nonce_  The nonce being used by the account.
     */
    function _checkAndIncrementNonce(address account, uint256 nonce_) internal {
        uint256 currentNonce_ = nonces[account];

        if (nonce_ != currentNonce_) revert ReusedNonce(nonce_, currentNonce_);

        unchecked {
            nonces[account] = currentNonce_ + 1; // Nonce realistically cannot overflow.
        }
    }

    /**
     * @dev   Delegate voting power from `delegator_` to `newDelegatee_`.
     * @param delegator_    The address of the account delegating voting power.
     * @param newDelegatee_ The address of the account receiving voting power.
     */
    function _delegate(address delegator_, address newDelegatee_) internal virtual;

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    // TODO: Expose
    function _getDelegationDigest(
        address delegatee_,
        uint256 nonce_,
        uint256 expiry_
    ) internal view returns (bytes32 digest_) {
        return _getDigest(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee_, nonce_, expiry_)));
    }
}
