// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IComptroller } from "../../src/comptroller/IComptroller.sol";

import { Comptroller } from "../../src/comptroller/Comptroller.sol";

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
        assertEq(address(comptroller.governor()), deployScript.governor(), "governor was not set up correctly");
        assertEq(address(comptroller.vault()), deployScript.vault(), "vault was not set up correctly");
        assertEq(address(comptroller.cash()), deployScript.cash(), "cash was not set up correctly");
        assertEq(comptroller.inflator(), deployScript.inflator(), "inflator was not set up correctly");
        assertEq(comptroller.fixedReward(), deployScript.fixedReward(), "fixedReward was not set up correctly");
        assertEq(comptroller.tax(), deployScript.tax(), "tax was not set up correctly");
        assertEq(comptroller.taxLowerBound(), deployScript.taxLowerBound(), "taxLowerBound was not set up correctly");
        assertEq(comptroller.taxUpperBound(), deployScript.taxUpperBound(), "taxUpperBound was not set up correctly");

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
        Comptroller.Configuration memory configInvalidDeployer = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroDeployerAddress.selector);
        new Comptroller(configInvalidDeployer);

        // if (config.value == address(0)) revert ZeroValueAddress();
        Comptroller.Configuration memory configInvalidValue = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroValueAddress.selector);
        new Comptroller(configInvalidValue);

        // if (config.vault == address(0)) revert ZeroVaultAddress();
        Comptroller.Configuration memory configInvalidVault = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroVaultAddress.selector);
        new Comptroller(configInvalidVault);

        // if (config.cash == address(0)) revert ZeroCashAddress();
        Comptroller.Configuration memory configInvalidCash = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroCashAddress.selector);
        new Comptroller(configInvalidCash);

        // if (config.tax == 0) revert ZeroTax();
        Comptroller.Configuration memory configInvalidTax = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroTax.selector);
        new Comptroller(configInvalidTax);

        // if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        Comptroller.Configuration memory configTaxOutOfRange = Comptroller.Configuration(
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
        vm.expectRevert(IComptroller.TaxOutOfRange.selector);
        new Comptroller(configTaxOutOfRange);

        // if (config.inflator == 0) revert ZeroInflator();
        Comptroller.Configuration memory configInvalidInflator = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroInflator.selector);
        new Comptroller(configInvalidInflator);

        // if (config.fixedReward == 0) revert ZeroFixedReward();
        Comptroller.Configuration memory configInvalidInflation = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroFixedReward.selector);
        new Comptroller(configInvalidInflation);

        // if (config.voteQuorum == 0) revert ZeroVoteQuorum();
        Comptroller.Configuration memory configInvalidVoteQuorum = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroVoteQuorum.selector);
        new Comptroller(configInvalidVoteQuorum);

        // if (config.valueQuorum == 0) revert ZeroValueQuorum();
        Comptroller.Configuration memory configInvalidValueQuorum = Comptroller.Configuration(
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

        vm.expectRevert(IComptroller.ZeroValueQuorum.selector);
        new Comptroller(configInvalidValueQuorum);
    }

    function test_fallback_Comptroller() public {
        vm.expectRevert();
        (bool success, ) = address(comptroller).call(abi.encodeWithSignature("doesNotExist()"));
        assertEq(success, true);

        vm.expectRevert();
        (success, ) = address(comptroller).call{ value: 10_000 }("");
        assertEq(success, true);
    }
}
