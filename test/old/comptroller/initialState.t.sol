// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import { IRegistrar } from "../../src/registrar/IRegistrar.sol";

// import { Registrar } from "../../src/registrar/Registrar.sol";

// import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

// contract SPOG_InitialState is SPOGBaseTest {
//     uint256 _taxLowerBound = 0;
//     uint256 _taxUpperBound = 6e18;
//     uint256 internal _inflator = 10;
//     uint256 internal _time = 10; // in blocks
//     uint256 internal _voteQuorum = 4;
//     uint256 internal _valueQuorum = 4;
//     uint256 internal _valueFixedInflation = 5;
//     uint256 internal _tax = 5e18;
//     address internal _cash = makeAddr("TestCash");

//     function test_SPOGHasSetInitialValuesCorrectly() public {
//         assertEq(address(registrar.governor()), deployScript.governor(), "governor was not set up correctly");
//         assertEq(address(registrar.vault()), deployScript.vault(), "vault was not set up correctly");
//         assertEq(address(registrar.cash()), deployScript.cash(), "cash was not set up correctly");
//         assertEq(registrar.inflator(), deployScript.inflator(), "inflator was not set up correctly");
//         assertEq(registrar.fixedReward(), deployScript.fixedReward(), "fixedReward was not set up correctly");
//         assertEq(registrar.tax(), deployScript.tax(), "tax was not set up correctly");
//         assertEq(registrar.taxLowerBound(), deployScript.taxLowerBound(), "taxLowerBound was not set up correctly");
//         assertEq(registrar.taxUpperBound(), deployScript.taxUpperBound(), "taxUpperBound was not set up correctly");

//         assertEq(governor.votingPeriod(), 216_000, "vote period not set correctly");
//         assertEq(governor.voteQuorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
//         assertEq(governor.valueQuorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
//         assertEq(address(governor.vote()), deployScript.vote(), "vote token not set correctly");
//         assertEq(address(governor.value()), deployScript.value(), "value token not set correctly");
//     }

//     function test_Revert_WhenSettingIncorrectInitialValues() public {
//         address _vault = makeAddr("Vault");
//         address _value = makeAddr("Value");

//         // if (config.deployer == address(0)) revert ZeroDeployerAddress();
//         Registrar.Configuration memory configInvalidDeployer = Registrar.Configuration(
//             address(0),
//             _value,
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroDeployerAddress.selector);
//         new Registrar(configInvalidDeployer);

//         // if (config.value == address(0)) revert ZeroValueAddress();
//         Registrar.Configuration memory configInvalidValue = Registrar.Configuration(
//             address(deployer),
//             address(0),
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroValueAddress.selector);
//         new Registrar(configInvalidValue);

//         // if (config.vault == address(0)) revert ZeroVaultAddress();
//         Registrar.Configuration memory configInvalidVault = Registrar.Configuration(
//             address(deployer),
//             _value,
//             address(0),
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroVaultAddress.selector);
//         new Registrar(configInvalidVault);

//         // if (config.cash == address(0)) revert ZeroCashAddress();
//         Registrar.Configuration memory configInvalidCash = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             address(0),
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroCashAddress.selector);
//         new Registrar(configInvalidCash);

//         // if (config.tax == 0) revert ZeroTax();
//         Registrar.Configuration memory configInvalidTax = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             0,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroTax.selector);
//         new Registrar(configInvalidTax);

//         // if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
//         Registrar.Configuration memory configTaxOutOfRange = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             _taxUpperBound + 1,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );
//         vm.expectRevert(IRegistrar.TaxOutOfRange.selector);
//         new Registrar(configTaxOutOfRange);

//         // if (config.inflator == 0) revert ZeroInflator();
//         Registrar.Configuration memory configInvalidInflator = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             0,
//             _valueFixedInflation,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroInflator.selector);
//         new Registrar(configInvalidInflator);

//         // if (config.fixedReward == 0) revert ZeroFixedReward();
//         Registrar.Configuration memory configInvalidInflation = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             0,
//             _voteQuorum,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroFixedReward.selector);
//         new Registrar(configInvalidInflation);

//         // if (config.voteQuorum == 0) revert ZeroVoteQuorum();
//         Registrar.Configuration memory configInvalidVoteQuorum = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             0,
//             _valueQuorum
//         );

//         vm.expectRevert(IRegistrar.ZeroVoteQuorum.selector);
//         new Registrar(configInvalidVoteQuorum);

//         // if (config.valueQuorum == 0) revert ZeroValueQuorum();
//         Registrar.Configuration memory configInvalidValueQuorum = Registrar.Configuration(
//             address(deployer),
//             _value,
//             _vault,
//             _cash,
//             _tax,
//             _taxLowerBound,
//             _taxUpperBound,
//             _inflator,
//             _valueFixedInflation,
//             _voteQuorum,
//             0
//         );

//         vm.expectRevert(IRegistrar.ZeroValueQuorum.selector);
//         new Registrar(configInvalidValueQuorum);
//     }

//     function test_fallback_Registrar() public {
//         vm.expectRevert();
//         (bool success, ) = address(registrar).call(abi.encodeWithSignature("doesNotExist()"));
//         assertEq(success, true);

//         vm.expectRevert();
//         (success, ) = address(registrar).call{ value: 10_000 }("");
//         assertEq(success, true);
//     }
// }
