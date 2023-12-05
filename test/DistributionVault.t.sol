// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { PureEpochs } from "../src/libs/PureEpochs.sol";

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

    address[] internal _accounts = [
        makeAddr("account1"),
        makeAddr("account2"),
        makeAddr("account3"),
        makeAddr("account4"),
        makeAddr("account5")
    ];

    uint256[] internal _claimableEpochs;

    function setUp() external {
        _token1 = new MockERC20();
        _token2 = new MockERC20();
        _token3 = new MockERC20();

        _baseToken = new MockEpochBasedVoteToken();
        _vault = new DistributionVault(address(_baseToken));
    }

    function test_constructor() external {
        assertEq(_vault.zeroToken(), address(_baseToken));
    }

    function test_constructor_invalidZeroTokenAddress() external {
        vm.expectRevert(IDistributionVault.InvalidZeroTokenAddress.selector);
        new DistributionVault(address(0));
    }

    function test_distribution() external {
        // Sets account balances this epoch.
        _baseToken.setPastBalanceOf(_accounts[0], PureEpochs.currentEpoch(), 1_000_000);
        _baseToken.setPastBalanceOf(_accounts[4], PureEpochs.currentEpoch(), 5_000_000);
        _baseToken.setPastTotalSupply(PureEpochs.currentEpoch(), 15_000_000);

        // Mint 1_000_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_000_000);
        _vault.distribute(address(_token1));

        uint256 startEpoch_ = PureEpochs.currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        _goToNextEpoch();

        // Check that the first 1_000_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 66_666);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 333_333);

        // Sets account balances this epoch.
        _baseToken.setPastBalanceOf(_accounts[0], PureEpochs.currentEpoch(), 1_000_000);
        _baseToken.setPastBalanceOf(_accounts[4], PureEpochs.currentEpoch(), 5_000_000);
        _baseToken.setPastTotalSupply(PureEpochs.currentEpoch(), 15_000_000);

        // Mint 500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_500_000); // 1_000_000 + 500_000
        _vault.distribute(address(_token1));

        endEpoch_ = PureEpochs.currentEpoch();

        _goToNextEpoch();

        // Check that the second 500_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 99_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 499_999);

        // Sets account balances this epoch (Account 0 transfers half their balance to Account 4).
        _baseToken.setPastBalanceOf(_accounts[0], PureEpochs.currentEpoch(), 500_000); // 1_000_000 - 500_000
        _baseToken.setPastBalanceOf(_accounts[4], PureEpochs.currentEpoch(), 5_500_000); // 5_000_000 + 500_000
        _baseToken.setPastTotalSupply(PureEpochs.currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 99_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 499_999);

        // Mint 1_500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_000_000); // 1_500_000 + 1_500_000
        _vault.distribute(address(_token1));

        endEpoch_ = PureEpochs.currentEpoch();

        _goToNextEpoch();

        // Check that the third 1_500_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 1_049_999);

        // Sets account balances this epoch (Account 0 transfers their remaining balance to Account 4).
        _baseToken.setPastBalanceOf(_accounts[4], PureEpochs.currentEpoch(), 6_000_000); // 5_500_000 + 500_000
        _baseToken.setPastTotalSupply(PureEpochs.currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 1_049_999);

        // Mint 100_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_100_000); // 3_000_000 + 100_000
        _vault.distribute(address(_token1));

        endEpoch_ = PureEpochs.currentEpoch();

        _goToNextEpoch();

        // Check that the fourth 100_000 distribution was successful.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 149_999);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 1_089_999);

        // Account 0 and Account 4 claim their funds tokens.
        vm.prank(_accounts[0]);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, _accounts[0]);

        vm.prank(_accounts[4]);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, _accounts[4]);

        // Check that the claimable funds tokens have zeroed.
        assertEq(_vault.getClaimable(address(_token1), _accounts[0], startEpoch_, endEpoch_), 0);
        assertEq(_vault.getClaimable(address(_token1), _accounts[4], startEpoch_, endEpoch_), 0);
    }
}
