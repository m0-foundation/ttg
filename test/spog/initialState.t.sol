// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import {SPOGGovernor} from "src/core/governor/SPOGGovernor.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

contract SPOG_InitialState is SPOG_Base {
    uint256[2] internal taxRange = [uint256(1), 6e18];
    uint256 internal inflator = 5;
    uint256 internal time = 10; // in blocks
    uint256 internal voteQuorum = 4;
    uint256 internal valueQuorum = 4;
    uint256 internal valueFixedInflationAmount = 5;
    uint256 internal tax = 5e18;
    IERC20 internal testCash = IERC20(makeAddr("TestCash"));

    bytes internal initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);

    function test_SPOGHasSetInitialValuesCorrectly() public {
        (uint256 _tax, uint256 _inflator, IERC20 _cash) = spog.spogData();

        assertEq(address(_cash), address(deployScript.cash()), "cash not set correctly");
        assertEq(_inflator, deployScript.inflator(), "inflator not set correctly");
        assertEq(governor.votingPeriod(), deployScript.time(), "time not set correctly");
        assertEq(governor.voteQuorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(governor.valueQuorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(_tax, deployScript.tax(), "tax not set correctly");
        assertEq(address(governor.vote()), address(deployScript.vote()), "vote token not set correctly");
        assertEq(address(governor.value()), address(deployScript.value()), "value token not set correctly");
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assertEq(taxRangeMin, deployScript.taxRange(0), "taxRangeMin not set correctly");
        assertEq(taxRangeMax, deployScript.taxRange(1), "taxRangeMax not set correctly");
    }

    // test revert setting zero address
    function test_Revert_WhenSettingIncorrectInitialValues() public {
        IVoteVault voteVault = IVoteVault(makeAddr("VoteVault"));
        IValueVault valueVault = IValueVault(makeAddr("ValueVault"));
        ISPOGGovernor governor = ISPOGGovernor(makeAddr("SPOGGovernor"));

        // revert inflator is zero
        inflator = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        vm.expectRevert(ISPOG.InitCashAndInflatorCannotBeZero.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        inflator = 5;
        testCash = IERC20(address(0));
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);

        // revert time is zero
        vm.expectRevert(ISPOG.InitCashAndInflatorCannotBeZero.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        testCash = IERC20(makeAddr("Cash"));
        tax = 7e18;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);

        // revert tax is greater than taxRangeMax
        vm.expectRevert(ISPOG.InitTaxOutOfRange.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        tax = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        // revert tax is lower than taxRangeMin
        vm.expectRevert(ISPOG.InitTaxOutOfRange.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        tax = 5e18;
        time = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        // revert time is zero
        vm.expectRevert(ISPOG.ZeroValues.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        time = 10;
        voteQuorum = 0;

        // revert voteQuorum is zero
        vm.expectRevert(ISPOG.ZeroValues.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        voteQuorum = 4;
        valueQuorum = 0;

        // revert valueQuorum is zero
        vm.expectRevert(ISPOG.ZeroValues.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        valueQuorum = 4;
        valueFixedInflationAmount = 0;

        // revert valueFixedInflationAmount is zero
        vm.expectRevert(ISPOG.ZeroValues.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(governor))));

        valueFixedInflationAmount = 5;

        // revert governor is zero address
        vm.expectRevert(ISPOG.ZeroAddress.selector);
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(0))));
    }

    function test_Revert_WhenSettingIncorrectVaultsInitValues() public {
        // revert vault vote token is zero address
        ValueToken valueToken = new ValueToken("TEST_SPOGValue", "value");
        VoteToken voteToken = new VoteToken("TEST_SPOGVote", "vote", address(valueToken));

        SPOGGovernor _governor = new SPOGGovernor(voteToken, valueToken, voteQuorum, valueQuorum, time, "SPOGGovernor");

        address invalidVoteVault = address(0);
        vm.expectRevert(ISPOG.VaultAddressCannotBeZero.selector);
        new SPOG(initSPOGData, IVoteVault(invalidVoteVault), valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(_governor))));

        // revert vault value token is zero address
        address invalidValueVault = address(0);
        vm.expectRevert(ISPOG.VaultAddressCannotBeZero.selector);
        new SPOG(initSPOGData, voteVault, IValueVault(invalidValueVault), time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernor(payable(address(_governor))));
    }

    function test_fallback() public {
        vm.expectRevert("SPOG: non-existent function");
        (bool success,) = address(spog).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, true);
    }
}
