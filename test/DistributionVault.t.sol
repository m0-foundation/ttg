// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC712 } from "../lib/common/src/interfaces/IERC712.sol";

import { IDistributionVault } from "../src/interfaces/IDistributionVault.sol";
import { DistributionVault } from "../src/DistributionVault.sol";

import { MockERC20, MockEpochBasedVoteToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract DistributionVaultTests is TestUtils {
    DistributionVault internal _vault;
    MockERC20 internal _token1;
    MockERC20 internal _token2;
    MockERC20 internal _token3;
    MockEpochBasedVoteToken internal _baseToken;

    address[] internal _accounts = [makeAddr("account1"), makeAddr("account2")];

    uint256[] internal _claimableEpochs;

    function setUp() external {
        _token1 = new MockERC20();
        _token2 = new MockERC20();
        _token3 = new MockERC20();

        _baseToken = new MockEpochBasedVoteToken();
        _vault = new DistributionVault(address(_baseToken));
    }

    /* ============ constructor ============ */
    function test_constructor() external {
        assertEq(_vault.zeroToken(), address(_baseToken));
        assertEq(_vault.name(), "DistributionVault");
        assertEq(_vault.CLOCK_MODE(), "mode=epoch");
        assertEq(_vault.clock(), _currentEpoch());
    }

    function test_constructor_invalidZeroTokenAddress() external {
        vm.expectRevert(IDistributionVault.InvalidZeroTokenAddress.selector);
        new DistributionVault(address(0));
    }

    /* ============ distribution ============ */
    function test_distribution() external {
        // Sets account balances this epoch.
        _baseToken.setPastBalanceOf(_accounts[0], _currentEpoch(), 1_000_000);
        _baseToken.setPastBalanceOf(_accounts[1], _currentEpoch(), 5_000_000);
        _baseToken.setPastTotalSupply(_currentEpoch(), 15_000_000);

        // Mint 1_000_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_000_000);
        _vault.distribute(address(_token1));

        uint256 startEpoch_ = _currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        _warpToNextEpoch();

        // Check that the first 1_000_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 66_666);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 333_333);

        // Sets account balances this epoch.
        _baseToken.setPastBalanceOf(_accounts[0], _currentEpoch(), 1_000_000);
        _baseToken.setPastBalanceOf(_accounts[1], _currentEpoch(), 5_000_000);
        _baseToken.setPastTotalSupply(_currentEpoch(), 15_000_000);

        // Mint 500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_500_000); // 1_000_000 + 500_000
        _vault.distribute(address(_token1));

        endEpoch_ = _currentEpoch();

        _warpToNextEpoch();

        // Check that the second 500_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 99_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 499_999);

        // Sets account balances this epoch (Account 0 transfers half their balance to Account 1).
        _baseToken.setPastBalanceOf(_accounts[0], _currentEpoch(), 500_000); // 1_000_000 - 500_000
        _baseToken.setPastBalanceOf(_accounts[1], _currentEpoch(), 5_500_000); // 5_000_000 + 500_000
        _baseToken.setPastTotalSupply(_currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 99_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 499_999);

        // Mint 1_500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_000_000); // 1_500_000 + 1_500_000
        _vault.distribute(address(_token1));

        endEpoch_ = _currentEpoch();

        _warpToNextEpoch();

        // Check that the third 1_500_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 1_049_999);

        // Sets account balances this epoch (Account 0 transfers their remaining balance to Account 1).
        _baseToken.setPastBalanceOf(_accounts[1], _currentEpoch(), 6_000_000); // 5_500_000 + 500_000
        _baseToken.setPastTotalSupply(_currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 1_049_999);

        // Mint 100_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_100_000); // 3_000_000 + 100_000
        _vault.distribute(address(_token1));

        endEpoch_ = _currentEpoch();

        _warpToNextEpoch();

        // Check that the fourth 100_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 1_089_999);

        // Account 0 claim their funds tokens.
        vm.prank(_accounts[0]);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, _accounts[0]);

        uint256 midEpoch_ = (startEpoch_ + endEpoch_) / 2;

        // Some token are claimed for Account 1 by bytes signature.
        bytes32 digest_ = _vault.getClaimDigest(
            address(_token1),
            startEpoch_,
            midEpoch_,
            _accounts[1],
            _vault.nonces(_accounts[1]),
            block.timestamp + 1 days
        );

        bytes memory claimSignature_ = _getSignature(digest_, _makeKey("account2"));

        _vault.claimBySig(
            _accounts[1], // for
            address(_token1),
            startEpoch_,
            midEpoch_,
            _accounts[1], // destination
            block.timestamp + 1 days,
            claimSignature_
        );

        // Rest of token are claimed for Account 1 by vrs signature.
        digest_ = _vault.getClaimDigest(
            address(_token1),
            midEpoch_,
            endEpoch_,
            _accounts[1],
            _vault.nonces(_accounts[1]),
            block.timestamp + 1 days
        );

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_makeKey("account2"), digest_);

        _vault.claimBySig(
            _accounts[1], // for
            address(_token1),
            midEpoch_,
            endEpoch_,
            _accounts[1], // destination
            block.timestamp + 1 days,
            v_,
            r_,
            s_
        );

        // Check that the claimable funds tokens have zeroed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 0);
        assertEq(_vault.getClaimable(address(_token1), _accounts[1], startEpoch_, endEpoch_), 0);
    }

    /* ============ getClaimable ============ */
    function test_getClaimable_notPastTimepoint() external {
        uint256 startEpoch_ = _currentEpoch() - 1;
        uint256 endEpoch_ = _currentEpoch() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(IDistributionVault.NotPastTimepoint.selector, endEpoch_, _currentEpoch())
        );
        _vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_);
    }

    function test_getClaimable_startEpochSameAsEndEpoch() external {
        uint256 startEpoch_ = _currentEpoch() - 1;
        uint256 endEpoch_ = startEpoch_;
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 0);
    }

    function test_getClaimable_startEpochAfterEndEpoch() external {
        uint256 startEpoch_ = _currentEpoch() - 1;
        uint256 endEpoch_ = _currentEpoch() - 2;
        vm.expectRevert(
            abi.encodeWithSelector(IDistributionVault.StartEpochAfterEndEpoch.selector, startEpoch_, endEpoch_)
        );
        _vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_);
    }

    /* ============ claim ============ */
    function test_claim_invalidDestination() external {
        uint256 startEpoch_ = _currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        vm.expectRevert(IDistributionVault.InvalidDestinationAddress.selector);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, address(0));
    }

    /* ============ claimBySig ============ */
    function test_claimBySig_invalidDestination() external {
        uint256 startEpoch_ = _currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        bytes32 digest_ = _vault.getClaimDigest(
            address(_token1),
            startEpoch_,
            endEpoch_,
            address(0),
            _vault.nonces(_accounts[0]),
            block.timestamp + 1 days
        );

        vm.expectRevert(IDistributionVault.InvalidDestinationAddress.selector);
        _vault.claimBySig(
            _accounts[0],
            address(_token1),
            startEpoch_,
            endEpoch_,
            address(0),
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account1"))
        );
    }

    function test_claimBySig_replayAttack() external {
        uint256 startEpoch_ = _currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        _warpToNextEpoch();

        bytes32 digest_ = _vault.getClaimDigest(
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            _vault.nonces(_accounts[0]),
            block.timestamp + 1 days
        );

        _vault.claimBySig(
            _accounts[0], // for
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0], // destination
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account1"))
        );

        // Can reuse digest since account is not part of the digest.
        // Effectively sending their claimable tokens to account 1.
        // It only works because both accounts have the same nonce.
        _vault.claimBySig(
            _accounts[1], // different account
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account2"))
        );

        vm.expectRevert(IERC712.SignerMismatch.selector);

        // Reverts here since the nonce is now different from the one used in the digest.
        _vault.claimBySig(
            _accounts[1],
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account2"))
        );

        _warpToNextEpoch();

        digest_ = _vault.getClaimDigest(
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            _vault.nonces(_accounts[0]),
            block.timestamp + 1 days
        );

        _vault.claimBySig(
            _accounts[0],
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account1"))
        );

        vm.expectRevert(IERC712.SignerMismatch.selector);

        // Reverts here since the destination is different from the one used in the digest.
        _vault.claimBySig(
            _accounts[1], // different account
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[1], // different destination
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account2"))
        );

        _warpToNextEpoch();

        digest_ = _vault.getClaimDigest(
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            _vault.nonces(_accounts[0]),
            block.timestamp + 1 days
        );

        _vault.claimBySig(
            _accounts[0],
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[0],
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account1"))
        );

        vm.expectRevert(IERC712.SignerMismatch.selector);

        // Reverts here since the account signing is different from the passed account.
        _vault.claimBySig(
            _accounts[0], // same account
            address(_token1),
            startEpoch_,
            endEpoch_,
            _accounts[1],
            block.timestamp + 1 days,
            _getSignature(digest_, _makeKey("account2")) // different signer
        );
    }
}
