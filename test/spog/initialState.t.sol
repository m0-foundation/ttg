// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";

contract SPOG_InitialState is SPOG_Base {
    function test_SPOGHasSetInitialValuesCorrectly() public {
        (uint256 tax, uint256 inflator, IERC20 cash) = spog.spogData();

        assertEq(address(cash), address(deployScript.cash()), "cash not set correctly");
        assertEq(inflator, deployScript.inflator(), "inflator not set correctly");
        assertEq(voteGovernor.votingPeriod(), deployScript.time(), "time not set correctly");
        assertEq(voteGovernor.quorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(valueGovernor.quorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(tax, deployScript.tax(), "tax not set correctly");
        assertEq(address(voteGovernor.votingToken()), address(deployScript.vote()), "vote token not set correctly");
        assertEq(address(valueGovernor.votingToken()), address(deployScript.value()), "value token not set correctly");
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assertEq(taxRangeMin, deployScript.taxRange(0), "taxRangeMin not set correctly");
        assertEq(taxRangeMax, deployScript.taxRange(1), "taxRangeMax not set correctly");
    }

    // test revert setting zero address
    function test_Revert_WhenSettingIncorrectInitialValues() public {
        uint256[2] memory taxRange = [uint256(1), 6e18];
        uint256 inflator;
        uint256 time = 10; // in blocks
        uint256 voteQuorum = 4;
        uint256 valueQuorum = 4;
        uint256 valueFixedInflationAmount = 5;
        uint256 tax = 5e18;
        address cash = makeAddr("Cash");
        address vault = makeAddr("Vault");
        address valueGovernor = makeAddr("ValueGovernor");
        address voteGovernor = makeAddr("VoteGovernor");

        bytes memory initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        // revert inflator is zero
        vm.expectRevert("SPOGStorage: init cash and inflator cannot be zero");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        inflator = 5;
        cash = address(0);
        initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        // revert time is zero
        vm.expectRevert("SPOGStorage: init cash and inflator cannot be zero");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        cash = makeAddr("Cash");
        tax = 7e18;
        initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);

        // revert tax is greater than taxRangeMax
        vm.expectRevert("SPOGStorage: init tax is out of range");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        tax = 0;
        initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);
        // revert tax is lower than taxRangeMin
        vm.expectRevert("SPOGStorage: init tax is out of range");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        tax = 5e18;
        time = 0;
        initSPOGData = abi.encode(address(cash), taxRange, inflator, tax);
        // revert time is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        time = 10;
        voteQuorum = 0;

        // revert voteQuorum is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        voteQuorum = 4;
        valueQuorum = 0;

        // revert valueQuorum is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        valueQuorum = 4;
        valueFixedInflationAmount = 0;

        // revert valueFixedInflationAmount is zero
        vm.expectRevert("SPOGStorage: zero values");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(valueGovernor));

        valueFixedInflationAmount = 5;

        // revert voteGovernor is zero address
        vm.expectRevert("SPOGStorage: zero address");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(address(0)), ISPOGGovernor(valueGovernor));

        // revert valueGovernor is zero address
        vm.expectRevert("SPOGStorage: zero address");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(address(0)));

        // revert voteGoverner and valueGovernor are the same
        vm.expectRevert("SPOGStorage: vote and value governor cannot be the same");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(voteGovernor), ISPOGGovernor(voteGovernor));

        // revert vault is zero address
        vault = address(0);
        ValueToken valueToken = new ValueToken("TEST_SPOGValue", "value");
        VoteToken voteToken = new VoteToken("TEST_SPOGVote", "vote", address(valueToken));

        SPOGGovernor _valueGovernor = new SPOGGovernor(valueToken, valueQuorum, time, "ValueGovernor");
        SPOGGovernor _voteGovernor = new SPOGGovernor(voteToken, voteQuorum, time, "VoteGovernor");

        vm.expectRevert("SPOG: Vault address cannot be 0");
        new SPOG(initSPOGData, vault, time, voteQuorum, valueQuorum, valueFixedInflationAmount, ISPOGGovernor(address(_voteGovernor)), ISPOGGovernor(address(_valueGovernor)));
    }

    function test_tokenInflationCalculation_IsZeroByDefault() public {
        uint256 epochInflation = spog.tokenInflationCalculation();
        assertTrue(epochInflation == 0, "tokenInflationCalculation should be zero by default");
    }
}
