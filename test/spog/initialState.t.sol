// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import {SPOGGovernor, SPOGGovernorBase} from "src/core/governance/SPOGGovernor.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

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
        assertEq(voteGovernor.votingPeriod(), deployScript.time(), "time not set correctly");
        assertEq(voteGovernor.quorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(valueGovernor.quorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(_tax, deployScript.tax(), "tax not set correctly");
        assertEq(address(voteGovernor.votingToken()), address(deployScript.vote()), "vote token not set correctly");
        assertEq(address(valueGovernor.votingToken()), address(deployScript.value()), "value token not set correctly");
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assertEq(taxRangeMin, deployScript.taxRange(0), "taxRangeMin not set correctly");
        assertEq(taxRangeMax, deployScript.taxRange(1), "taxRangeMax not set correctly");
    }

    // test revert setting zero address
    function test_Revert_WhenSettingIncorrectInitialValues() public {
        IVoteVault voteVault = IVoteVault(makeAddr("VoteVault"));
        IValueVault valueVault = IValueVault(makeAddr("ValueVault"));
        ISPOGGovernor valueGovernor = ISPOGGovernor(makeAddr("ValueGovernor"));
        ISPOGGovernor voteGovernor = ISPOGGovernor(makeAddr("VoteGovernor"));

        // revert inflator is zero
        inflator = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        vm.expectRevert("SPOGStorage: init cash and inflator cannot be zero");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        inflator = 5;
        testCash = IERC20(address(0));
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);

        // revert time is zero
        vm.expectRevert("SPOGStorage: init cash and inflator cannot be zero");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        testCash = IERC20(makeAddr("Cash"));
        tax = 7e18;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);

        // revert tax is greater than taxRangeMax
        vm.expectRevert("SPOGStorage: init tax is out of range");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        tax = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        // revert tax is lower than taxRangeMin
        vm.expectRevert("SPOGStorage: init tax is out of range");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        tax = 5e18;
        time = 0;
        initSPOGData = abi.encode(address(testCash), taxRange, inflator, tax);
        // revert time is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        time = 10;
        voteQuorum = 0;

        // revert voteQuorum is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        voteQuorum = 4;
        valueQuorum = 0;

        // revert valueQuorum is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        valueQuorum = 4;
        valueFixedInflationAmount = 0;

        // revert valueFixedInflationAmount is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(valueGovernor))));

        valueFixedInflationAmount = 5;

        // revert voteGovernor is zero address
        vm.expectRevert("SPOGStorage: zero address");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(0))), SPOGGovernorBase(payable(address(valueGovernor))));

        // revert valueGovernor is zero address
        vm.expectRevert("SPOGStorage: zero address");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(0))));

        // revert voteGoverner and valueGovernor are the same
        vm.expectRevert("SPOGStorage: vote and value governor cannot be the same");
        new SPOG(initSPOGData, voteVault, valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(voteGovernor))), SPOGGovernorBase(payable(address(voteGovernor))));
    }

    function test_Revert_WhenSettingIncorrectVaultsInitValues() public {
        // revert vault vote token is zero address
        ValueToken valueToken = new ValueToken("TEST_SPOGValue", "value");
        VoteToken voteToken = new VoteToken("TEST_SPOGVote", "vote", address(valueToken));

        SPOGGovernor _valueGovernor = new SPOGGovernor(valueToken, valueQuorum, time, "ValueGovernor");
        SPOGGovernor _voteGovernor = new SPOGGovernor(voteToken, voteQuorum, time, "VoteGovernor");

        address invalidVoteVault = address(0);
        vm.expectRevert("SPOG: Vault address cannot be 0");
        new SPOG(initSPOGData, IVoteVault(invalidVoteVault), valueVault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(_voteGovernor))), SPOGGovernorBase(payable(address(_valueGovernor))));

        // revert vault value token is zero address
        address invalidValueVault = address(0);
        vm.expectRevert("SPOG: Vault address cannot be 0");
        new SPOG(initSPOGData, voteVault, IValueVault(invalidValueVault), time, voteQuorum, valueQuorum, valueFixedInflationAmount, SPOGGovernorBase(payable(address(_voteGovernor))), SPOGGovernorBase(payable(address(_valueGovernor))));
    }

    function test_fallback() public {
        vm.expectRevert("SPOG: non-existent function");
        (bool success,) = address(spog).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, true);
    }
}
