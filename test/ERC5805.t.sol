// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IStatefulERC712 } from "../lib/common/src/interfaces/IStatefulERC712.sol";

import { TestUtils } from "./utils/TestUtils.sol";
import { ERC5805Harness } from "./utils/ERC5805Harness.sol";

contract ERC5805Tests is TestUtils {
    ERC5805Harness internal _erc5805;

    address internal _alice;
    uint256 internal _aliceKey;

    function setUp() external {
        (_alice, _aliceKey) = makeAddrAndKey("alice");

        _erc5805 = new ERC5805Harness("ERC5805");
    }

    /* ============ DELEGATION_TYPEHASH ============ */
    function test_delegateTypehash() external {
        assertEq(
            _erc5805.DELEGATION_TYPEHASH(),
            keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)")
        );
    }

    /* ============ delegate ============ */
    function test_delegateBySig_incrementNonce() external {
        address delegatee_ = address(this);
        uint256 expiry_ = block.timestamp + 1;
        uint256 nonce_ = 0;

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _erc5805.getDelegationDigest(delegatee_, nonce_, expiry_)
        );

        assertEq(_erc5805.nonces(_alice), 0);

        _erc5805.delegateBySig(delegatee_, nonce_, expiry_, v_, r_, s_);

        assertEq(_erc5805.nonces(_alice), 1);
    }

    function test_delegateBySig_invalidNonce() external {
        address delegatee_ = address(this);
        uint256 expiry_ = block.timestamp + 1;
        uint256 nonce_ = 1;

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _erc5805.getDelegationDigest(delegatee_, nonce_, expiry_)
        );

        vm.expectRevert(abi.encodeWithSelector(IStatefulERC712.InvalidAccountNonce.selector, nonce_, 0));
        _erc5805.delegateBySig(delegatee_, nonce_, expiry_, v_, r_, s_);
    }
}
