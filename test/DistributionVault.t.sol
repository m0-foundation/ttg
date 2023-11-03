// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { DistributionVault } from "../src/DistributionVault.sol";
import { PureEpochs } from "../src/PureEpochs.sol";

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

    function test_distribution() external {
        // Sets account balances this epoch.
        _baseToken.setBalanceAt(_accounts[0], PureEpochs.currentEpoch(), 1_000_000);
        _baseToken.setBalanceAt(_accounts[4], PureEpochs.currentEpoch(), 5_000_000);
        _baseToken.setTotalSupplyAt(PureEpochs.currentEpoch(), 15_000_000);

        // Mint 1_000_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_000_000);
        _vault.distribute(address(_token1));
        _claimableEpochs.push(PureEpochs.currentEpoch());

        _goToNextEpoch();

        // Check that the first 1_000_000 distribution was successful.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 66_666);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 333_333);

        // Sets account balances this epoch.
        _baseToken.setBalanceAt(_accounts[0], PureEpochs.currentEpoch(), 1_000_000);
        _baseToken.setBalanceAt(_accounts[4], PureEpochs.currentEpoch(), 5_000_000);
        _baseToken.setTotalSupplyAt(PureEpochs.currentEpoch(), 15_000_000);

        // Mint 500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 1_500_000); // 1_000_000 + 500_000
        _vault.distribute(address(_token1));
        _claimableEpochs.push(PureEpochs.currentEpoch());

        _goToNextEpoch();

        // Check that the second 500_000 distribution was successful.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 99_999);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 499_999);

        // Sets account balances this epoch (Account 0 transfers half their balance to Account 4).
        _baseToken.setBalanceAt(_accounts[0], PureEpochs.currentEpoch(), 500_000); // 1_000_000 - 500_000
        _baseToken.setBalanceAt(_accounts[4], PureEpochs.currentEpoch(), 5_500_000); // 5_000_000 + 500_000
        _baseToken.setTotalSupplyAt(PureEpochs.currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 99_999);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 499_999);

        // Mint 1_500_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_000_000); // 1_500_000 + 1_500_000
        _vault.distribute(address(_token1));
        _claimableEpochs.push(PureEpochs.currentEpoch());

        _goToNextEpoch();

        // Check that the third 1_500_000 distribution was successful.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 149_999);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 1_049_999);

        // Sets account balances this epoch (Account 0 transfers their remaining balance to Account 4).
        _baseToken.setBalanceAt(_accounts[4], PureEpochs.currentEpoch(), 6_000_000); // 5_500_000 + 500_000
        _baseToken.setTotalSupplyAt(PureEpochs.currentEpoch(), 15_000_000);

        // Check that the claimable funds tokens have not changed.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 149_999);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 1_049_999);

        // Mint 100_000 funds tokens to the ZeroToken contract and distribute them.
        _token1.setBalance(address(_vault), 3_100_000); // 3_000_000 + 100_000
        _vault.distribute(address(_token1));
        _claimableEpochs.push(PureEpochs.currentEpoch());

        _goToNextEpoch();

        // Check that the fourth 100_000 distribution was successful.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 149_999);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 1_089_999);

        // Account 0 and Account 4 claim their funds tokens.
        vm.prank(_accounts[0]);
        _vault.claim(address(_token1), _claimableEpochs, _accounts[0]);

        vm.prank(_accounts[4]);
        _vault.claim(address(_token1), _claimableEpochs, _accounts[4]);

        // Check that the claimable funds tokens have zeroed.
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[0], _claimableEpochs), 0);
        assertEq(_vault.claimableOfAt(address(_token1), _accounts[4], _claimableEpochs), 0);
    }
}
