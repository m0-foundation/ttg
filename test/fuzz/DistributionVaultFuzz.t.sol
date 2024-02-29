// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

import { DistributionVault } from "../../src/DistributionVault.sol";

import { MockERC20, MockEpochBasedVoteToken } from "./../utils/Mocks.sol";
import { TestUtils } from "./../utils/TestUtils.sol";

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

    function testFuzz_distribution(
        uint256 token1Balance,
        uint256 account1PastBalance,
        uint256 account2PastBalance,
        uint256 pastTotalSupply
    ) external {
        token1Balance = bound(token1Balance, 0, type(uint112).max);
        account1PastBalance = bound(account1PastBalance, 0, type(uint112).max); //@elcid closed environment.
        account2PastBalance = bound(account2PastBalance, 0, type(uint112).max);

        vm.assume(account1PastBalance + account2PastBalance < type(uint112).max);
        vm.assume(account1PastBalance + account2PastBalance > 0);

        pastTotalSupply = bound(pastTotalSupply, account1PastBalance + account2PastBalance, type(uint112).max);

        _baseToken.setPastBalanceOf(_accounts[0], PureEpochs.currentEpoch(), account1PastBalance); //@elcid sets ZERO balance
        _baseToken.setPastBalanceOf(_accounts[1], PureEpochs.currentEpoch(), account2PastBalance);
        _baseToken.setPastTotalSupply(PureEpochs.currentEpoch(), pastTotalSupply);

        _token1.setBalance(address(_vault), token1Balance); //@elcid sets token.balanceOf
        _vault.distribute(address(_token1));

        assertEq(_vault.distributionOfAt(address(_token1), PureEpochs.currentEpoch()), token1Balance);

        uint256 startEpoch_ = PureEpochs.currentEpoch();
        uint256 endEpoch_ = startEpoch_;

        _warpToNextEpoch();

        vm.prank(_accounts[0]);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, _accounts[0]);

        vm.prank(_accounts[1]);
        _vault.claim(address(_token1), startEpoch_, endEpoch_, _accounts[1]);
    }
}
