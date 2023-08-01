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

        assertEq(governor.votingPeriod(), 216_000, "vote period not set correctly");
        assertEq(governor.voteQuorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(governor.valueQuorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(address(governor.vote()), deployScript.vote(), "vote token not set correctly");
        assertEq(address(governor.value()), deployScript.value(), "value token not set correctly");
    }

    function test_Revert_WhenSettingIncorrectInitialValues() public {
        address _vault = makeAddr("Vault");
        address _value = makeAddr("Value");

        // if (config.deployer == address(0)) revert ZeroDeployerAddress();
        SPOG.Configuration memory configInvalidDeployer = SPOG.Configuration(
            address(0),
            _value,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroDeployerAddress.selector);
        new SPOG(configInvalidDeployer);

        // if (config.value == address(0)) revert ZeroValueAddress();
        SPOG.Configuration memory configInvalidValue = SPOG.Configuration(
            address(deployer),
            address(0),
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroValueAddress.selector);
        new SPOG(configInvalidValue);

        // if (config.vault == address(0)) revert ZeroVaultAddress();
        SPOG.Configuration memory configInvalidVault = SPOG.Configuration(
            address(deployer),
            _value,
            address(0),
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroVaultAddress.selector);
        new SPOG(configInvalidVault);

        // if (config.cash == address(0)) revert ZeroCashAddress();
        SPOG.Configuration memory configInvalidCash = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            address(0),
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroCashAddress.selector);
        new SPOG(configInvalidCash);

        // if (config.tax == 0) revert ZeroTax();
        SPOG.Configuration memory configInvalidTax = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            0,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroTax.selector);
        new SPOG(configInvalidTax);

        // if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        SPOG.Configuration memory configTaxOutOfRange = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            _taxUpperBound + 1,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );
        vm.expectRevert(ISPOG.TaxOutOfRange.selector);
        new SPOG(configTaxOutOfRange);

        // if (config.inflator == 0) revert ZeroInflator();
        SPOG.Configuration memory configInvalidInflator = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            0,
            _valueFixedInflation,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroInflator.selector);
        new SPOG(configInvalidInflator);

        // if (config.fixedReward == 0) revert ZeroFixedReward();
        SPOG.Configuration memory configInvalidInflation = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            0,
            _voteQuorum,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroFixedReward.selector);
        new SPOG(configInvalidInflation);

        // if (config.voteQuorum == 0) revert ZeroVoteQuorum();
        SPOG.Configuration memory configInvalidVoteQuorum = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            0,
            _valueQuorum
        );

        vm.expectRevert(ISPOG.ZeroVoteQuorum.selector);
        new SPOG(configInvalidVoteQuorum);

        // if (config.valueQuorum == 0) revert ZeroValueQuorum();
        SPOG.Configuration memory configInvalidValueQuorum = SPOG.Configuration(
            address(deployer),
            _value,
            _vault,
            _cash,
            _tax,
            _taxLowerBound,
            _taxUpperBound,
            _inflator,
            _valueFixedInflation,
            _voteQuorum,
            0
        );

        vm.expectRevert(ISPOG.ZeroValueQuorum.selector);
        new SPOG(configInvalidValueQuorum);
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
