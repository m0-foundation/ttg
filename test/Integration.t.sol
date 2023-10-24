// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { console2 } from "../lib/forge-std/src/console2.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IPowerToken } from "../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";

import { DeployBase } from "../script/DeployBase.s.sol";

import { MockERC20Permit } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract IntegrationTests is TestUtils {
    address internal _deployer = makeAddr("deployer");

    address internal _registrar;

    address[] internal _accounts = [makeAddr("account0"), makeAddr("account1"), makeAddr("account2")];

    address[] internal _initialPowerAccounts = [_accounts[0], _accounts[1], _accounts[2]];

    uint256[] internal _initialPowerBalances = [60, 30, 10];

    address[] internal _initialZeroAccounts = [_accounts[0], _accounts[1], _accounts[2]];

    uint256[] internal _initialZeroBalances = [60_000_000, 30_000_000, 10_000_000];

    DeployBase internal _deploy;
    MockERC20Permit internal _cashToken;

    function setUp() external {
        _deploy = new DeployBase();
        _cashToken = new MockERC20Permit("CASH", "Cash Token", 6);

        _registrar = _deploy.deploy(
            _deployer,
            0,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            address(_cashToken)
        );
    }

    function test_initialState() external {
        IPowerToken powerToken_ = IPowerToken(IDualGovernor(IRegistrar(_registrar).governor()).powerToken());

        uint256 initialPowerTotalSupply_;

        for (uint256 index_; index_ < _initialPowerBalances.length; ++index_) {
            initialPowerTotalSupply_ += _initialPowerBalances[index_];
        }

        for (uint256 index_; index_ < _initialPowerAccounts.length; ++index_) {
            assertEq(
                powerToken_.balanceOf(_initialPowerAccounts[index_]),
                (_initialPowerBalances[index_] * powerToken_.INITIAL_SUPPLY()) / initialPowerTotalSupply_
            );
        }
    }

    function test_setProposalFee() external {
        IDualGovernor governor_ = IDualGovernor(IRegistrar(_registrar).governor());
        IPowerToken powerToken_ = IPowerToken(governor_.powerToken());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(governor_);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory calldatas_ = new bytes[](1);
        calldatas_[0] = abi.encodeWithSelector(governor_.setProposalFee.selector, governor_.minProposalFee());

        string memory description_ = "Set proposal fee to 100";

        uint256 proposalFee_ = governor_.proposalFee();

        _cashToken.mint(_accounts[0], proposalFee_);

        vm.prank(_accounts[0]);
        _cashToken.approve(address(governor_), proposalFee_);

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, calldatas_, description_);

        assertEq(_cashToken.balanceOf(_accounts[0]), 0);
        assertEq(_cashToken.balanceOf(address(governor_)), proposalFee_);

        _goToNextVoteEpoch();

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 600_000_000);

        _goToNextTransferEpoch();

        governor_.execute(targets_, values_, calldatas_, keccak256(bytes(description_)));

        assertEq(governor_.proposalFee(), governor_.minProposalFee());
    }

    function test_emergencyUpdateConfig() external {
        IRegistrar registrar_ = IRegistrar(_registrar);
        IDualGovernor governor_ = IDualGovernor(registrar_.governor());
        IPowerToken powerToken_ = IPowerToken(governor_.powerToken());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(governor_);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory calldatas_ = new bytes[](1);
        calldatas_[0] = abi.encodeWithSelector(
            governor_.emergencyUpdateConfig.selector,
            bytes32("TEST_KEY"),
            bytes32("TEST_VALUE")
        );

        string memory description_ = "Emergency update TEST_KEY config to TEST_VALUE";

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, calldatas_, description_);

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 600_000_000);

        governor_.execute(targets_, values_, calldatas_, keccak256(bytes(description_)));

        assertEq(registrar_.get("TEST_KEY"), "TEST_VALUE");
    }

    function test_reset() external {
        IRegistrar registrar_ = IRegistrar(_registrar);
        IDualGovernor governor_ = IDualGovernor(registrar_.governor());
        IPowerToken powerToken_ = IPowerToken(governor_.powerToken());

        _jumpToEpoch(governor_.clock() + 1);

        address[] memory targets_ = new address[](1);
        targets_[0] = address(governor_);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory calldatas_ = new bytes[](1);
        calldatas_[0] = abi.encodeWithSelector(governor_.reset.selector);

        string memory description_ = "Reset";

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, calldatas_, description_);

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 60_000_000);

        governor_.execute(targets_, values_, calldatas_, keccak256(bytes(description_)));
    }
}
