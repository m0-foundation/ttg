// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { console2 } from "../lib/forge-std/src/console2.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IPowerToken } from "../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";

import { DeployBase } from "../script/DeployBase.s.sol";

import { ERC20PermitHarness } from "./utils/ERC20PermitHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract IntegrationTests is TestUtils {
    address internal _deployer = makeAddr("deployer");

    address internal _registrar;

    address internal _cashToken1 = address(new ERC20PermitHarness("Cash Token 1", "CASH1", 6));
    address internal _cashToken2 = address(new ERC20PermitHarness("Cash Token 1", "CASH2", 6));

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    address[] internal _accounts = [makeAddr("account0"), makeAddr("account1"), makeAddr("account2")];

    address[] internal _initialPowerAccounts = [_accounts[0], _accounts[1], _accounts[2]];

    uint256[] internal _initialPowerBalances = [60, 30, 10];

    address[] internal _initialZeroAccounts = [_accounts[0], _accounts[1], _accounts[2]];

    uint256[] internal _initialZeroBalances = [60_000_000, 30_000_000, 10_000_000];

    DeployBase internal _deploy;

    function setUp() external {
        _deploy = new DeployBase();

        _registrar = _deploy.deploy(
            _deployer,
            0,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _allowedCashTokens
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

        address[] memory targets_ = new address[](1);
        targets_[0] = address(governor_);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        uint256 newProposalFee_ = governor_.proposalFee() * 2;

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(governor_.setProposalFee.selector, newProposalFee_);

        string memory description_ = "Set proposal fee to 100";

        uint256 proposalFee_ = governor_.proposalFee();
        ERC20PermitHarness cashToken_ = ERC20PermitHarness(governor_.cashToken());

        cashToken_.mint(_accounts[0], proposalFee_);

        vm.prank(_accounts[0]);
        cashToken_.approve(address(governor_), proposalFee_);

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, callDatas_, description_);

        assertEq(cashToken_.balanceOf(_accounts[0]), 0);
        assertEq(cashToken_.balanceOf(governor_.vault()), proposalFee_);

        _goToNextVoteEpoch();

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 600_000_000);

        _goToNextTransferEpoch();

        governor_.execute(targets_, values_, callDatas_, bytes32(0));

        // assertEq(governor_.proposalFee(), newProposalFee_);
    }

    function test_emergencyUpdateConfig() external {
        IRegistrar registrar_ = IRegistrar(_registrar);
        IDualGovernor governor_ = IDualGovernor(registrar_.governor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(governor_);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            governor_.emergencyUpdateConfig.selector,
            bytes32("TEST_KEY"),
            bytes32("TEST_VALUE")
        );

        string memory description_ = "Emergency update TEST_KEY config to TEST_VALUE";

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 600_000_000);

        governor_.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

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

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(governor_.resetToZeroHolders.selector);

        string memory description_ = "Reset";

        vm.prank(_accounts[0]);
        uint256 proposalId_ = governor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_accounts[0]);
        uint256 weight_ = governor_.castVote(proposalId_, 1);

        assertEq(weight_, 60_000_000);

        governor_.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));
    }
}
