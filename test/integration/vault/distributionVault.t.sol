// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ERC20ExtendedHarness } from "../../utils/ERC20ExtendedHarness.sol";

import { IntegrationBaseSetup } from "../IntegrationBaseSetup.t.sol";

contract DistributionVault_IntegrationTest is IntegrationBaseSetup {
    // NOTE: there are 3 accounts with ZERO tokens:
    // - dave: 60%
    // - eve: 30%
    // - frank: 10%

    ERC20ExtendedHarness internal _token1 = new ERC20ExtendedHarness("Vault Token 1", "TOKEN1", 18);
    ERC20ExtendedHarness internal _token2 = new ERC20ExtendedHarness("Vault Token 2", "TOKEN2", 6);

    function test_distributeAndClaim_ZeroPowerWeightsStayTheSame() external {
        assertEq(_token1.balanceOf(address(_vault)), 0);
        assertEq(_token2.balanceOf(address(_vault)), 0);

        _token1.mint(address(_vault), 1_000e18);
        _token2.mint(address(_vault), 1_000e6);

        assertEq(_token1.balanceOf(address(_vault)), 1_000e18);
        assertEq(_token2.balanceOf(address(_vault)), 1_000e6);

        _warpToNextEpoch();

        _token1.mint(address(_vault), 2_000e18);
        _token2.mint(address(_vault), 2_000e6);

        assertEq(_token1.balanceOf(address(_vault)), 3_000e18);
        assertEq(_token2.balanceOf(address(_vault)), 3_000e6);

        _warpToNextEpoch();

        _token1.mint(address(_vault), 3_000e18);
        _token2.mint(address(_vault), 3_000e6);

        assertEq(_token1.balanceOf(address(_vault)), 6_000e18);
        assertEq(_token2.balanceOf(address(_vault)), 6_000e6);

        _vault.distribute(address(_token1));
        _vault.distribute(address(_token2));

        _warpToNextEpoch();

        vm.prank(_dave);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _dave);
        vm.prank(_dave);
        _vault.claim(address(_token2), _currentEpoch() - 1, _currentEpoch() - 1, _dave);
        assertEq(_token1.balanceOf(_dave), (6_000e18 * 60) / 100); // dave owns 60% of ZERO tokens
        assertEq(_token2.balanceOf(_dave), (6_000e6 * 60) / 100);

        vm.prank(_eve);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _eve);
        vm.prank(_eve);
        _vault.claim(address(_token2), _currentEpoch() - 1, _currentEpoch() - 1, _eve);
        assertEq(_token1.balanceOf(_eve), (6_000e18 * 30) / 100); // eve owns 30% of ZERO tokens
        assertEq(_token2.balanceOf(_eve), (6_000e6 * 30) / 100);

        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _frank);
        vm.prank(_frank);
        _vault.claim(address(_token2), _currentEpoch() - 1, _currentEpoch() - 1, _frank);
        assertEq(_token1.balanceOf(_frank), (6_000e18 * 10) / 100); // frank owns remaining 10% of ZERO tokens
        assertEq(_token2.balanceOf(_frank), (6_000e6 * 10) / 100);

        assertEq(_token1.balanceOf(_dave) + _token1.balanceOf(_eve) + _token1.balanceOf(_frank), 6_000e18);
        assertEq(_token2.balanceOf(_dave) + _token2.balanceOf(_eve) + _token2.balanceOf(_frank), 6_000e6);
    }

    function test_distributeInMultipleEpochsAndClaimOnce_ZeroPowerWeightsChange() external {
        assertEq(_token1.balanceOf(address(_vault)), 0);

        _token1.mint(address(_vault), 1_000e18);
        assertEq(_token1.balanceOf(address(_vault)), 1_000e18);

        vm.prank(_dave);
        _zeroToken.transfer(_eve, 10_000_000e6);

        _warpToNextEpoch();

        _token1.mint(address(_vault), 2_000e18);
        assertEq(_token1.balanceOf(address(_vault)), 3_000e18);

        vm.prank(_dave);
        _zeroToken.transfer(_frank, 10_000_000e6);

        _warpToNextEpoch();

        vm.prank(_dave);
        _zeroToken.transfer(_frank, 10_000_000e6);

        _token1.mint(address(_vault), 3_000e18);
        assertEq(_token1.balanceOf(address(_vault)), 6_000e18);

        _vault.distribute(address(_token1));

        vm.prank(_dave);
        _zeroToken.transfer(_frank, 10_000_000e6); // account for this transfer in further claims

        _token1.mint(address(_vault), 1_000e18);
        assertEq(_token1.balanceOf(address(_vault)), 7_000e18); // `distribute` has to be called to account for this mint

        _warpToNextEpoch();

        vm.prank(_dave);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _dave);

        vm.prank(_eve);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _eve);

        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 1, _currentEpoch() - 1, _frank);

        assertEq(_token1.balanceOf(_dave), (6_000e18 * 20) / 100); // dave owed 30% of ZERO tokens
        assertEq(_token1.balanceOf(_eve), (6_000e18 * 40) / 100); // eve owed 30% of ZERO tokens
        assertEq(_token1.balanceOf(_frank), (6_000e18 * 40) / 100); // frank owed 40% of ZERO tokens
    }

    function test_distributeInMultipleEpochsAndGetClaimable_ZeroPowerWeightsChange() external {
        uint256 firstDistributionAmount_ = 1_000e18;

        _token1.mint(address(_vault), firstDistributionAmount_);
        assertEq(_token1.balanceOf(address(_vault)), firstDistributionAmount_);

        vm.prank(_dave);
        _zeroToken.transfer(_eve, 10_000_000e6);

        _vault.distribute(address(_token1));

        vm.prank(_dave);
        _zeroToken.transfer(_frank, 10_000_000e6);

        _warpToNextEpoch();

        assertEq(
            _vault.getClaimable(address(_token1), _dave, _currentEpoch() - 1, _currentEpoch() - 1),
            (firstDistributionAmount_ * 40) / 100
        ); // dave owed 40% of ZERO tokens
        assertEq(
            _vault.getClaimable(address(_token1), _eve, _currentEpoch() - 1, _currentEpoch() - 1),
            (firstDistributionAmount_ * 40) / 100
        ); // eve owed 40% of ZERO tokens
        assertEq(
            _vault.getClaimable(address(_token1), _frank, _currentEpoch() - 1, _currentEpoch() - 1),
            (firstDistributionAmount_ * 20) / 100
        ); // frank owed 20% of ZERO tokens

        _vault.distribute(address(_token1)); // no new tokens to distribute

        _warpToNextEpoch();

        assertEq(_vault.getClaimable(address(_token1), _dave, _currentEpoch() - 1, _currentEpoch() - 1), 0); // no funds to claim for previous epoch
        assertEq(
            _vault.getClaimable(address(_token1), _dave, _currentEpoch() - 2, _currentEpoch() - 1),
            (firstDistributionAmount_ * 40) / 100
        ); // dave owed 40% of ZERO tokens

        assertEq(_vault.getClaimable(address(_token1), _eve, _currentEpoch() - 1, _currentEpoch() - 1), 0); // no funds to claim for previous epoch
        assertEq(
            _vault.getClaimable(address(_token1), _eve, _currentEpoch() - 2, _currentEpoch() - 1),
            (firstDistributionAmount_ * 40) / 100
        ); // eve owed 40% of ZERO tokens

        assertEq(_vault.getClaimable(address(_token1), _frank, _currentEpoch() - 1, _currentEpoch() - 1), 0); // no funds to claim for previous epoch
        assertEq(
            _vault.getClaimable(address(_token1), _frank, _currentEpoch() - 2, _currentEpoch() - 1),
            (firstDistributionAmount_ * 20) / 100
        ); // frank owed 20% of ZERO tokens

        uint256 secondDistributionAmount_ = 1_000e18;
        _token1.mint(address(_vault), secondDistributionAmount_);

        _vault.distribute(address(_token1));

        vm.prank(_dave);
        _zeroToken.transfer(_frank, 40_000_000e6);

        _warpToNextEpoch();

        assertEq(_vault.getClaimable(address(_token1), _dave, _currentEpoch() - 1, _currentEpoch() - 1), 0); // no balance at the end of epoch
        assertEq(
            _vault.getClaimable(address(_token1), _eve, _currentEpoch() - 1, _currentEpoch() - 1),
            (secondDistributionAmount_ * 40) / 100
        ); // eve owed 40% of ZERO tokens at the end of epoch

        assertEq(
            _vault.getClaimable(address(_token1), _frank, _currentEpoch() - 1, _currentEpoch() - 1),
            (secondDistributionAmount_ * 60) / 100
        ); // frank owed 60% of ZERO tokens at the end of epoch

        vm.prank(_dave);
        _vault.claim(address(_token1), _currentEpoch() - 3, _currentEpoch() - 1, _dave);
        assertEq(_token1.balanceOf(_dave), (firstDistributionAmount_ * 40) / 100);

        vm.prank(_eve);
        _vault.claim(address(_token1), _currentEpoch() - 3, _currentEpoch() - 1, _eve);
        assertEq(
            _token1.balanceOf(_eve),
            (firstDistributionAmount_ * 40) / 100 + (secondDistributionAmount_ * 40) / 100
        );

        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 3, _currentEpoch() - 1, _frank);
        assertEq(
            _token1.balanceOf(_frank),
            (firstDistributionAmount_ * 20) / 100 + (secondDistributionAmount_ * 60) / 100
        );
    }

    function test_distributeInMultipleEpochsAndClaimMultipleTimes() external {
        uint256 distributionAmount_ = 1_000e18;

        _token1.mint(address(_vault), distributionAmount_);
        _vault.distribute(address(_token1));

        _warpToNextEpoch();

        _vault.distribute(address(_token1)); // no new tokens to distribute
        _token1.mint(address(_vault), distributionAmount_); // new tokens to distribute

        _warpToNextEpoch();

        _vault.distribute(address(_token1));

        _warpToNextEpoch();

        _token1.mint(address(_vault), distributionAmount_);
        _vault.distribute(address(_token1));

        _warpToNextEpoch();

        // _dave claims his distributions
        vm.prank(_dave);
        _vault.claim(address(_token1), _currentEpoch() - 4, _currentEpoch() - 3, _dave);
        assertEq(_token1.balanceOf(_dave), (distributionAmount_ * 60) / 100);

        vm.prank(_dave);
        _vault.claim(address(_token1), _currentEpoch() - 2, _currentEpoch() - 1, _dave);
        assertEq(_token1.balanceOf(_dave), (3 * distributionAmount_ * 60) / 100);

        // _eve claims her distributions
        vm.prank(_eve);
        _vault.claim(address(_token1), _currentEpoch() - 4, _currentEpoch() - 3, _eve);
        assertEq(_token1.balanceOf(_eve), (distributionAmount_ * 30) / 100);

        vm.prank(_eve);
        _vault.claim(address(_token1), _currentEpoch() - 3, _currentEpoch() - 1, _eve);
        assertEq(_token1.balanceOf(_eve), (3 * distributionAmount_ * 30) / 100);

        // _frank claims his distributions
        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 4, _currentEpoch() - 1, _frank);
        assertEq(_token1.balanceOf(_frank), (3 * distributionAmount_ * 10) / 100);

        // _frank attempts to claim his distributions again
        assertEq(_vault.getClaimable(address(_token1), _frank, _currentEpoch() - 4, _currentEpoch() - 3), 0);

        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 4, _currentEpoch() - 3, _frank);
        assertEq(_token1.balanceOf(_frank), (3 * distributionAmount_ * 10) / 100); // balance stays the same

        // _frank attempts to claim his distributions again
        assertEq(_vault.getClaimable(address(_token1), _frank, _currentEpoch() - 2, _currentEpoch() - 1), 0);

        vm.prank(_frank);
        _vault.claim(address(_token1), _currentEpoch() - 2, _currentEpoch() - 1, _frank);
        assertEq(_token1.balanceOf(_frank), (3 * distributionAmount_ * 10) / 100); // balance stays the same
    }
}
