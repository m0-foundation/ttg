// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "../../src/interfaces/ISPOG.sol";

import { SPOG } from "../../src/core/SPOG.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_InitialState is SPOGBaseTest {
    uint256 _taxLowerBound = 0;
    uint256 _taxUpperBound = 6e18;
    uint256 internal _inflator = 10;
    uint256 internal _time = 10; // in blocks
    uint256 internal _voteQuorum = 4;
    uint256 internal _valueQuorum = 4;
    uint256 internal _valueFixedInflation = 5;
    uint256 internal _tax = 5e18;
    address internal _cash = makeAddr("TestCash");

    function test_SPOGHasSetInitialValuesCorrectly() public {
        assertEq(address(spog.governor()), deployScript.governor(), "governor was not set up correctly");
        assertEq(address(spog.vault()), deployScript.vault(), "vault was not set up correctly");
        assertEq(address(spog.cash()), deployScript.cash(), "cash was not set up correctly");
        assertEq(spog.inflator(), deployScript.inflator(), "inflator was not set up correctly");
        assertEq(spog.fixedReward(), deployScript.fixedReward(), "fixedReward was not set up correctly");
        assertEq(spog.tax(), deployScript.tax(), "tax was not set up correctly");
        assertEq(spog.taxLowerBound(), deployScript.taxLowerBound(), "taxLowerBound was not set up correctly");
        assertEq(spog.taxUpperBound(), deployScript.taxUpperBound(), "taxUpperBound was not set up correctly");

        assertEq(governor.votingPeriod(), deployScript.time(), "time was not set up correctly");
        assertEq(governor.voteQuorumNumerator(), deployScript.voteQuorum(), "voteQuorum was not set up correctly");
        assertEq(governor.valueQuorumNumerator(), deployScript.valueQuorum(), "valueQuorum was not set up correctly");
        assertEq(governor.vote(), deployScript.vote(), "vote token was not set up correctly");
        assertEq(governor.value(), deployScript.value(), "value token was not set up correctly");
    }

    function test_Revert_WhenSettingIncorrectInitialValues() public {
        address _vault = makeAddr("Vault");
        address _governor = makeAddr("SPOGGovernor");

        // if (config.governor == address(0)) revert ZeroGovernorAddress();
        SPOG.Configuration memory configInvalidGovernor = SPOG.Configuration(
            address(0),
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation
        );

        vm.expectRevert(ISPOG.ZeroGovernorAddress.selector);
        new SPOG(configInvalidGovernor);

        // if (config.vault == address(0)) revert ZeroVaultAddress();
        SPOG.Configuration memory configInvalidVault = SPOG.Configuration(
            _governor,
            address(0),
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation
        );

        vm.expectRevert(ISPOG.ZeroVaultAddress.selector);
        new SPOG(configInvalidVault);

        // if (config.cash == address(0)) revert ZeroCashAddress();
        SPOG.Configuration memory configInvalidCash = SPOG.Configuration(
            _governor,
            _vault,
            address(0),
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation
        );

        vm.expectRevert(ISPOG.ZeroCashAddress.selector);
        new SPOG(configInvalidCash);

        // if (config.tax == 0) revert ZeroTax();
        SPOG.Configuration memory configInvalidTax = SPOG.Configuration(
            _governor,
            _vault,
            _cash,
            0,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation
        );

        vm.expectRevert(ISPOG.ZeroTax.selector);
        new SPOG(configInvalidTax);

        // if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        SPOG.Configuration memory configTaxOutOfRange = SPOG.Configuration(
            _governor,
            _vault,
            _cash,
            _taxUpperBound + 1,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation
        );
        vm.expectRevert(ISPOG.TaxOutOfRange.selector);
        new SPOG(configTaxOutOfRange);

        // if (config.inflator == 0) revert ZeroInflator();
        SPOG.Configuration memory configInvalidInflator = SPOG.Configuration(
            _governor,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            0,
            _valueFixedInflation
        );

        vm.expectRevert(ISPOG.ZeroInflator.selector);
        new SPOG(configInvalidInflator);

        // if (config.fixedReward == 0) revert ZeroFixedReward();
        SPOG.Configuration memory configInvalidInflation = SPOG.Configuration(
            _governor,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            0
        );

        vm.expectRevert(ISPOG.ZeroFixedReward.selector);
        new SPOG(configInvalidInflation);
    }

    function test_fallback_SPOG() public {
        vm.expectRevert();
        (bool success, ) = address(spog).call(abi.encodeWithSignature("doesNotExist()"));
        assertEq(success, true);

        vm.expectRevert();
        (success, ) = address(spog).call{ value: 10_000 }("");
        assertEq(success, true);
    }
}
