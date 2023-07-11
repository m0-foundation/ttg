// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "src/interfaces/ISPOG.sol";

import { SPOG } from "src/core/SPOG.sol";

import { SPOGBaseTest } from "test/shared/SPOGBaseTest.t.sol";

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
        assertEq(address(spog.governor()), deployScript.governor(), "governor not set correctly");
        assertEq(address(spog.vault()), deployScript.vault(), "vault not set correctly");
        assertEq(address(spog.cash()), deployScript.cash(), "cash not set correctly");
        assertEq(spog.inflator(), deployScript.inflator(), "inflator not set correctly");
        assertEq(
            spog.valueFixedInflation(), deployScript.valueFixedInflation(), "valueFixedInflation not set correctly"
        );
        assertEq(spog.tax(), deployScript.tax(), "tax not set correctly");
        assertEq(spog.taxLowerBound(), deployScript.taxLowerBound(), "taxLowerBound not set correctly");
        assertEq(spog.taxUpperBound(), deployScript.taxUpperBound(), "taxUpperBound not set correctly");

        assertEq(governor.votingPeriod(), deployScript.time(), "time not set correctly");
        assertEq(governor.voteQuorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(governor.valueQuorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(address(governor.vote()), deployScript.vote(), "vote token not set correctly");
        assertEq(address(governor.value()), deployScript.value(), "value token not set correctly");
    }

    function test_Revert_WhenSettingIncorrectInitialValues() public {
        address _vault = makeAddr("Vault");
        address _governor = makeAddr("SPOGGovernor");

        // if (config.governor == address(0)) revert ZeroGovernorAddress();
        SPOG.Configuration memory configInvalidGovernor = SPOG.Configuration(
            payable(address(0)), _vault, _cash, _tax, _taxLowerBound, _taxUpperBound, _inflator, _valueFixedInflation
        );
        vm.expectRevert(ISPOG.ZeroGovernorAddress.selector);
        new SPOG(configInvalidGovernor);

        // if (config.vault == address(0)) revert ZeroVaultAddress();
        SPOG.Configuration memory configInvalidVault = SPOG.Configuration(
            payable(_governor), address(0), _cash, _tax, _taxLowerBound, _taxUpperBound, _inflator, _valueFixedInflation
        );
        vm.expectRevert(ISPOG.ZeroVaultAddress.selector);
        new SPOG(configInvalidVault);

        // if (config.cash == address(0)) revert ZeroCashAddress();
        SPOG.Configuration memory configInvalidCash = SPOG.Configuration(
            payable(_governor),
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
            payable(_governor), _vault, _cash, 0, _taxLowerBound, _taxUpperBound, _inflator, _valueFixedInflation
        );
        vm.expectRevert(ISPOG.ZeroTax.selector);
        new SPOG(configInvalidTax);

        // if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        SPOG.Configuration memory configTaxOutOfRange = SPOG.Configuration(
            payable(_governor),
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
            payable(_governor), _vault, _cash, _tax, _taxLowerBound, _taxUpperBound, 0, _valueFixedInflation
        );
        vm.expectRevert(ISPOG.ZeroInflator.selector);
        new SPOG(configInvalidInflator);

        // if (config.valueFixedInflation == 0) revert ZeroValueInflation();
        SPOG.Configuration memory configInvalidInflation =
            SPOG.Configuration(payable(_governor), _vault, _cash, _tax, _taxLowerBound, _taxUpperBound, _inflator, 0);
        vm.expectRevert(ISPOG.ZeroValueInflation.selector);
        new SPOG(configInvalidInflation);
    }

    function test_fallback_SPOG() public {
        vm.expectRevert();
        (bool success,) = address(spog).call(abi.encodeWithSignature("doesNotExist()"));
        assertEq(success, true);

        vm.expectRevert();
        (success,) = address(spog).call{value: 10000}("");
        assertEq(success, true);
    }
}
